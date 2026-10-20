import SwiftUI

struct PanelView: View {
    @ObservedObject var store: FocusStore
    @ObservedObject var settings: AppSettings

    @State private var adding = false
    @State private var newTitle = ""
    @State private var showLog = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if showLog {
                Divider()
                logView
            } else {
                if !store.focuses.isEmpty {
                    Divider()
                    VStack(spacing: 2) {
                        ForEach(store.focuses) { f in
                            FocusRow(store: store, focus: f)
                        }
                    }
                }
                if adding { addField }
                if store.focuses.isEmpty && !adding {
                    Text("Klikni + in vpiši, na čem delaš.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                footer
            }
        }
        .padding(12)
        .frame(width: 300, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
    }

    // MARK: - Header: drag area + state + always-visible buttons

    private var header: some View {
        HStack(spacing: 8) {
            // Left part doubles as the drag handle for moving the window
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)
                Circle()
                    .fill(store.active?.color ?? Color.secondary)
                    .frame(width: 8, height: 8)
                Text(store.active == nil ? "Pavza" : "Delam")
                    .font(.headline)
                if let a = store.active {
                    Text("· \(formatDuration(store.seconds(for: a)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .overlay(DragHandle())
            .help("Povleci za premik okna")

            Text("\(store.focuses.count)/\(settings.maxFocuses)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Button {
                adding = true
                inputFocused = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .disabled(!store.canAdd)
            .help(store.canAdd ? "Dodaj fokus" : "Največ \(settings.maxFocuses) fokusov; enega zaključi ali izbriši")
        }
    }

    private var addField: some View {
        TextField("Nov fokus ...", text: $newTitle)
            .textFieldStyle(.roundedBorder)
            .focused($inputFocused)
            .onSubmit {
                store.add(newTitle)
                newTitle = ""
                adding = false
            }
            .onExitCommand {
                newTitle = ""
                adding = false
            }
    }

    private var footer: some View {
        HStack {
            Button("Dnevnik") { showLog = true }
                .buttonStyle(.link)
            Spacer()
            Button("Pavza") { store.pause() }
                .buttonStyle(.link)
                .disabled(store.active == nil)
            Text("⌃⌥F")
                .foregroundStyle(.tertiary)
        }
        .font(.caption)
    }

    // MARK: - Today's switch log

    // One multi-line Text (not a row per event) so a drag selection can span several lines
    private var logText: String {
        store.todaysLog.reversed()
            .map { "\($0.at.formatted(date: .omitted, time: .shortened))  \($0.title)" }
            .joined(separator: "\n")
    }

    private var logView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Danes: \(store.todaysLog.count) preklopov").font(.subheadline.bold())
                Spacer()
                Button("Kopiraj") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(logText, forType: .string)
                }
                .buttonStyle(.link)
                .disabled(store.todaysLog.isEmpty)
                .help("Kopiraj cel dnevnik na odložišče")
                Button("Nazaj") { showLog = false }.buttonStyle(.link)
            }
            ScrollView {
                Text(logText.isEmpty ? "Danes še ni preklopov." : logText)
                    .font(.caption)
                    .monospacedDigit()
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
    @State private var hovering = false

    private var isActive: Bool { store.state.activeID == focus.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: isActive ? "largecircle.fill.circle" : "circle.fill")
                    .foregroundStyle(focus.color)
                Text(focus.title)
                    .lineLimit(1)
                    .fontWeight(isActive ? .semibold : .regular)
                Spacer()
                if hovering {
                    // Quick actions; the same ones live in the context menu
                    Button { store.markDone(focus.id) } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Končano (umakne s seznama, čas ostane v dnevniku)")
                    Button { store.delete(focus.id) } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Izbriši")
                } else {
                    Text(formatDuration(store.seconds(for: focus)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if editingNote {
                TextField("Kje sem ostal?", text: $note)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onSubmit {
                        store.update(focus.id, note: note)
                        editingNote = false
                    }
                    .onExitCommand { editingNote = false }
            } else if !focus.note.isEmpty {
                Text(focus.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.leading, 22)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? focus.color.opacity(0.22) : (hovering ? Color.primary.opacity(0.05) : Color.clear))
        )
        .overlay(alignment: .leading) {
            // Color stripe on the left edge so the color is visible even when not active
            RoundedRectangle(cornerRadius: 2)
                .fill(focus.color)
                .frame(width: 3)
                .padding(.vertical, 4)
        }
        .contentShape(Rectangle())
        .onTapGesture { store.switchTo(focus.id) }
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Opomba: kje sem ostal ...") {
                note = focus.note
                editingNote = true
            }
            Menu("Barva") {
                ForEach(Array(FocusPalette.colors.enumerated()), id: \.offset) { i, c in
                    Button {
                        store.setColor(focus.id, i)
                    } label: {
                        Text((i == focus.colorIndex ? "✓ " : "") + c.name)
                    }
                }
            }
            Button("Končano") { store.markDone(focus.id) }
            Divider()
            Button("Izbriši", role: .destructive) { store.delete(focus.id) }
        }
    }
}
