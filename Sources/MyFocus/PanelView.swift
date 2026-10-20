import SwiftUI

struct PanelView: View {
    @ObservedObject var store: FocusStore
    @State private var expanded = false
    @State private var newTitle = ""
    @State private var showLog = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if expanded {
                Divider()
                if showLog { logView } else { listView }
            }
        }
        .padding(12)
        .frame(width: 300, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
    }

    // MARK: - Header: current focus

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(store.active == nil ? Color.secondary : Color.green)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.active?.title ?? "Ni aktivnega fokusa")
                    .font(.headline)
                    .lineLimit(2)
                if let a = store.active {
                    Text(formatDuration(store.seconds(for: a)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !a.note.isEmpty {
                        Text(a.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
                if expanded { inputFocused = true }
            } label: {
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
            }
            .buttonStyle(.borderless)
            .help("Pokaži/skrij seznam fokusov")
        }
    }

    // MARK: - List of focuses

    private var listView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Nov fokus ...", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)
                    .onSubmit {
                        store.add(newTitle)
                        newTitle = ""
                    }
                Button("Pavza") { store.pause() }
                    .disabled(store.active == nil)
            }

            ForEach(store.focuses) { f in
                FocusRow(store: store, focus: f)
            }

            if store.focuses.isEmpty {
                Text("Vpiši, na čem delaš, in pritisni Enter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Današnji dnevnik") { showLog = true }
                    .buttonStyle(.link)
                    .font(.caption)
                Spacer()
                Text("⌃⌥F skrij/pokaži")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Today's switch log

    private var logView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Danes: \(store.todaysLog.count) preklopov").font(.subheadline.bold())
                Spacer()
                Button("Nazaj") { showLog = false }.buttonStyle(.link)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(store.todaysLog.reversed()) { e in
                        HStack(alignment: .firstTextBaseline) {
                            Text(e.at, format: .dateTime.hour().minute())
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Text(e.title).lineLimit(1)
                        }
                        .font(.caption)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
    }
}

struct FocusRow: View {
    @ObservedObject var store: FocusStore
    let focus: Focus
    @State private var editingNote = false
    @State private var note = ""

    private var isActive: Bool { store.state.activeID == focus.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: isActive ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isActive ? Color.green : Color.secondary)
                Text(focus.title)
                    .lineLimit(1)
                    .fontWeight(isActive ? .semibold : .regular)
                Spacer()
                Text(formatDuration(store.seconds(for: focus)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
            .onTapGesture { store.switchTo(focus.id) }
            .contextMenu {
                Button("Opomba: kje sem ostal ...") {
                    note = focus.note
                    editingNote = true
                }
                Button("Končano") { store.markDone(focus.id) }
                Divider()
                Button("Izbriši", role: .destructive) { store.delete(focus.id) }
            }

            if editingNote {
                TextField("Kje sem ostal?", text: $note)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onSubmit {
                        store.update(focus.id, note: note)
                        editingNote = false
                    }
            } else if !focus.note.isEmpty && !isActive {
                Text(focus.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.leading, 22)
            }
        }
        .padding(.vertical, 2)
    }
}
