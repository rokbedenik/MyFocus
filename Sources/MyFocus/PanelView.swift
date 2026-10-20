import SwiftUI

struct PanelView: View {
    @ObservedObject var store: FocusStore
    @ObservedObject var settings: AppSettings

    @State private var adding = false
    @State private var newTitle = ""
    @State private var showLog = false
    @FocusState private var inputFocused: Bool

    private var nudging: Bool { store.nudgeDue && !showLog }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if showLog {
                Divider()
                logView
            } else {
                if nudging { nudgeBar }
                if !store.focuses.isEmpty {
                    Divider()
                    VStack(spacing: 2) {
                        ForEach(store.focuses) { f in
                            FocusRow(store: store, settings: settings, focus: f)
                        }
                    }
                }
                if adding { addField }
                if store.focuses.isEmpty && !adding {
                    Text(L.t("Click + and type what you are working on."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                footer
            }
        }
        .padding(12)
        .frame(width: 300, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(nudging ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.quaternary), lineWidth: nudging ? 2 : 1)
        )
        .animation(.easeInOut(duration: 0.3), value: nudging)
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
                Text(store.active == nil ? L.t("Paused") : L.t("Working"))
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
            .help(L.t("Drag to move the window"))

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
            .accessibilityLabel(L.t("Add focus"))
            .help(store.canAdd ? L.t("Add focus") : L.t("At most %d focuses; finish or delete one", settings.maxFocuses))
        }
        // Keyboard focus ring belongs on text fields, not on icon buttons
        .focusEffectDisabled()
    }

    // MARK: - Inactivity nudge

    private var nudgeBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
            Text(L.t("Still working on this?"))
                .font(.caption)
            Spacer()
            Button(L.t("Yes")) { store.acknowledgeNudge() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button(L.t("Pause")) { store.pause() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(8)
        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
        .focusEffectDisabled()
    }

    private var addField: some View {
        TextField(L.t("New focus ..."), text: $newTitle)
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
            Button(L.t("Log")) { showLog = true }
                .buttonStyle(.link)
            Spacer()
            Button(L.t("Pause")) { store.pause() }
                .buttonStyle(.link)
                .disabled(store.active == nil)
            Text("⌃⌥F")
                .foregroundStyle(.tertiary)
        }
        .font(.caption)
        .focusEffectDisabled()
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
                Text(L.t("Today: %d switches", store.todaysLog.count)).font(.subheadline.bold())
                Spacer()
                Button(L.t("Copy")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(logText, forType: .string)
                }
                .buttonStyle(.link)
                .disabled(store.todaysLog.isEmpty)
                .help(L.t("Copy today's log to the clipboard"))
                Button(L.t("Back")) { showLog = false }.buttonStyle(.link)
            }
            .focusEffectDisabled()
            ScrollView {
                Text(logText.isEmpty ? L.t("No switches yet today.") : logText)
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
    @ObservedObject var settings: AppSettings
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
                Text(formatDuration(store.seconds(for: focus)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                // Quick actions, always laid out so the row does not jump; visible on hover only.
                // The same actions live in the context menu.
                HStack(spacing: 4) {
                    Button { store.markDone(focus.id) } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    .accessibilityLabel(L.t("Done"))
                    .help(L.t("Done (removes from the list, time stays in the log)"))
                    Button { store.delete(focus.id) } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel(L.t("Delete"))
                    .help(L.t("Delete"))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .focusEffectDisabled()
                .opacity(hovering ? 1 : 0)
                .accessibilityHidden(!hovering)
            }

            if editingNote {
                TextField(L.t("Where did I leave off?"), text: $note)
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
            Button(L.t("Note: where did I leave off ...")) {
                note = focus.note
                editingNote = true
            }
            Menu(L.t("Color")) {
                ForEach(Array(FocusPalette.colors.enumerated()), id: \.offset) { i, c in
                    Button {
                        store.setColor(focus.id, i)
                    } label: {
                        Text((i == focus.colorIndex ? "✓ " : "") + L.t(c.name))
                    }
                }
            }
            Button(L.t("Done")) { store.markDone(focus.id) }
            Divider()
            Button(L.t("Delete"), role: .destructive) { store.delete(focus.id) }
        }
    }
}
