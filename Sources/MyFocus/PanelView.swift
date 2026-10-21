import SwiftUI
import Combine

// Requests from outside SwiftUI (global shortcuts, menu); views react to the counters changing
@MainActor
final class PanelCommands: ObservableObject {
    @Published var newFocusTick = 0
    @Published var noteTick = 0
    // Mirrors the panel's key-window state
    @Published var panelIsKey = false
    // Set by the app delegate: shows the app menu at a right-click on the drag handle
    var contextMenu: ((NSView, NSEvent) -> Void)?
}

// All sizes in the panel are multiplied by the user's scale factor
extension Font {
    static func ui(_ size: CGFloat, _ scale: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size * scale, weight: weight)
    }
}

struct PanelView: View {
    @ObservedObject var store: FocusStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var commands: PanelCommands
    @ObservedObject var calendar: CalendarWatcher

    @State private var adding = false
    @State private var newTitle = ""
    @State private var editingNoteID: UUID?
    // Expanded by a click; collapses again once the mouse has left the window
    @State private var expanded = false
    @State private var collapseTask: Task<Void, Never>?
    @FocusState private var inputFocused: Bool

    private var s: CGFloat { settings.uiScale }
    private var nudging: Bool { store.nudgeDue }

    // Collapsed: only the active (or last active) focus is listed
    private var collapsed: Bool {
        settings.collapseWhenIdle && !expanded && !commands.panelIsKey && !adding && editingNoteID == nil
    }

    private var shownID: UUID? { store.state.activeID ?? store.state.lastActiveID }

    private var visibleFocuses: [Focus] {
        guard collapsed else { return store.focuses }
        return store.focuses.filter { $0.id == shownID }
    }

    // Collapsed mode: the other focuses shrink to colored dots; click switches without expanding
    private var hiddenFocuses: [Focus] {
        guard collapsed else { return [] }
        return store.focuses.filter { $0.id != shownID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8 * s) {
            header
            if nudging { nudgeBar }
            if let sug = calendar.suggestion { suggestionBar(sug) }
            if !visibleFocuses.isEmpty || !hiddenFocuses.isEmpty {
                Divider()
                VStack(spacing: 2 * s) {
                    ForEach(visibleFocuses) { f in
                        FocusRow(store: store, settings: settings, focus: f, editingNoteID: $editingNoteID)
                            // Clicking the only visible row while collapsed shows the rest
                            .simultaneousGesture(TapGesture().onEnded { if collapsed { expanded = true } })
                    }
                    if !hiddenFocuses.isEmpty {
                        HStack(spacing: 6 * s) {
                            ForEach(hiddenFocuses) { f in
                                Button { store.switchTo(f.id) } label: {
                                    Circle()
                                        .strokeBorder(f.color, lineWidth: 1.5)
                                        .background(Circle().fill(f.color.opacity(0.25)))
                                        .frame(width: 9 * s, height: 9 * s)
                                }
                                .buttonStyle(.plain)
                                .focusEffectDisabled()
                                .help(f.title)
                                .accessibilityLabel(f.title)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 8 * s)
                        .padding(.vertical, 3 * s)
                    }
                }
            }
            if adding { addField }
            if store.focuses.isEmpty && !adding {
                Text(L.t("Click + and type what you are working on."))
                    .font(.ui(10, s))
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: collapsed)
        .onHover { inside in
            collapseTask?.cancel()
            guard !inside, expanded else { return }
            // Collapse shortly after the mouse leaves; hovering alone never expands
            collapseTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                if !Task.isCancelled { expanded = false }
            }
        }
        .padding(12 * s)
        .frame(width: 300 * s, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12 * s))
        .overlay(
            RoundedRectangle(cornerRadius: 12 * s)
                .strokeBorder(nudging ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.quaternary), lineWidth: nudging ? 2 : 1)
        )
        .animation(.easeInOut(duration: 0.3), value: nudging)
        .onChange(of: commands.newFocusTick) {
            guard store.canAdd else { return }
            editingNoteID = nil
            adding = true
            inputFocused = true
        }
        .onChange(of: commands.noteTick) {
            guard let id = store.state.activeID else { return }
            adding = false
            editingNoteID = id
        }
    }

    // MARK: - Header: drag area + state + always-visible buttons

    private var header: some View {
        HStack(spacing: 8 * s) {
            // Left part doubles as the drag handle for moving the window
            HStack(spacing: 8 * s) {
                Image(systemName: "line.3.horizontal")
                    .font(.ui(13, s))
                    .foregroundStyle(.tertiary)
                if let a = store.active {
                    Circle()
                        .fill(a.color)
                        .frame(width: 8 * s, height: 8 * s)
                    Text(L.t("Working"))
                        .font(.ui(13, s, weight: .semibold))
                    Text("· \(formatDuration(store.seconds(for: a)))")
                        .font(.ui(10, s))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    Image(systemName: "pause.fill")
                        .font(.ui(13, s))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(L.t("Paused"))
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .overlay(DragHandle(onContextMenu: commands.contextMenu))
            .help(L.t("Drag to move the window, right-click for the menu"))

            if settings.collapseWhenIdle && store.focuses.count > 1 {
                Button { expanded.toggle() } label: {
                    Image(systemName: collapsed ? "chevron.down.circle" : "chevron.up.circle")
                        .font(.ui(15, s))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(collapsed ? L.t("Show all focuses") : L.t("Show only the active focus"))
                .help(collapsed ? L.t("Show all focuses") : L.t("Show only the active focus"))
            }
            Button { store.pause() } label: {
                Image(systemName: "pause.circle.fill")
                    .font(.ui(15, s))
            }
            .buttonStyle(.borderless)
            .disabled(store.active == nil)
            .accessibilityLabel(L.t("Pause"))
            .help(L.t("Pause"))
            Button {
                editingNoteID = nil
                adding = true
                inputFocused = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.ui(15, s))
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
        HStack(spacing: 8 * s) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.ui(13, s))
                .foregroundStyle(.orange)
            Text(L.t("Still working on this?"))
                .font(.ui(10, s))
            Spacer()
            Button(L.t("Yes")) { store.acknowledgeNudge() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button { store.pause() } label: {
                Image(systemName: "pause.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel(L.t("Pause"))
            .help(L.t("Pause"))
        }
        .font(.ui(10, s))
        .padding(8 * s)
        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8 * s))
        .focusEffectDisabled()
    }

    // MARK: - Calendar suggestion

    private func suggestionBar(_ sug: CalendarWatcher.Suggestion) -> some View {
        let existing = store.focuses.first { $0.title == sug.title }
        let canSwitch = existing != nil || store.canAdd
        return HStack(spacing: 8 * s) {
            Image(systemName: "calendar")
                .font(.ui(13, s))
                .foregroundStyle(.blue)
            Text(L.t("Starting now: %@", sug.title))
                .font(.ui(10, s))
                .lineLimit(2)
            Spacer()
            Button(L.t("Switch")) {
                if let f = existing { store.switchTo(f.id) } else { store.add(sug.title) }
                calendar.dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!canSwitch)
            .help(canSwitch ? "" : L.t("At most %d focuses; finish or delete one", settings.maxFocuses))
            Button { calendar.dismiss() } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel(L.t("Dismiss"))
            .help(L.t("Dismiss"))
        }
        .font(.ui(10, s))
        .padding(8 * s)
        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8 * s))
        .focusEffectDisabled()
    }

    private var addField: some View {
        VStack(alignment: .leading, spacing: 6 * s) {
            // One-click templates above the free-text field
            if !store.templates.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6 * s) {
                        ForEach(store.templates) { t in
                            Button {
                                store.useTemplate(t.id)
                                newTitle = ""
                                adding = false
                            } label: {
                                HStack(spacing: 4 * s) {
                                    Circle().fill(t.color).frame(width: 7 * s, height: 7 * s)
                                    Text(t.title).font(.ui(10, s)).lineLimit(1)
                                }
                                .padding(.horizontal, 8 * s)
                                .padding(.vertical, 4 * s)
                                .background(t.color.opacity(0.18), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .focusEffectDisabled()
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            textField
        }
    }

    private var textField: some View {
        TextField(L.t("New focus ..."), text: $newTitle)
            .textFieldStyle(.roundedBorder)
            .font(.ui(13, s))
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
}

struct FocusRow: View {
    @ObservedObject var store: FocusStore
    @ObservedObject var settings: AppSettings
    let focus: Focus
    @Binding var editingNoteID: UUID?
    @State private var note = ""
    @State private var editingTitle = false
    @State private var title = ""
    @FocusState private var titleFocused: Bool
    @State private var hovering = false
    @FocusState private var noteFocused: Bool

    private var s: CGFloat { settings.uiScale }
    private var isActive: Bool { store.state.activeID == focus.id }
    private var editingNote: Bool { editingNoteID == focus.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 4 * s) {
            HStack(spacing: 6 * s) {
                // Filled dot only for the active focus; the others are a hollow ring in their color
                Image(systemName: isActive ? "circle.fill" : "circle")
                    .font(.ui(13, s))
                    .foregroundStyle(focus.color)
                if editingTitle {
                    TextField("", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .font(.ui(13, s))
                        .focused($titleFocused)
                        .onSubmit {
                            store.update(focus.id, title: title)
                            editingTitle = false
                        }
                        .onExitCommand { editingTitle = false }
                } else {
                    Text(focus.title)
                        .font(.ui(13, s, weight: isActive ? .semibold : .regular))
                        .lineLimit(1)
                        // Double-click renames; the row's single click (switch) still fires on the first click
                        .simultaneousGesture(TapGesture(count: 2).onEnded { startRenaming() })
                        .help(L.t("Double-click to rename"))
                }
                Spacer()
                Text(formatDuration(store.seconds(for: focus)))
                    .font(.ui(10, s))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                // Quick actions, always laid out so the row does not jump; visible on hover only.
                // The same actions live in the context menu.
                HStack(spacing: 4 * s) {
                    Button { startEditingNote() } label: {
                        Image(systemName: focus.note.isEmpty ? "text.bubble" : "text.bubble.fill")
                    }
                    .accessibilityLabel(L.t("Note: where did I leave off"))
                    .help(L.t("Note: where did I leave off"))
                    Button { store.markDone(focus.id) } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    .accessibilityLabel(L.t("Done"))
                    .help(L.t("Done (removes from the list, time stays in the log)"))
                }
                .font(.ui(13, s))
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .focusEffectDisabled()
                .opacity(hovering ? 1 : 0)
                .accessibilityHidden(!hovering)
            }

            if editingNote {
                TextField(L.t("Where did I leave off?"), text: $note)
                    .textFieldStyle(.roundedBorder)
                    .font(.ui(10, s))
                    .focused($noteFocused)
                    .onSubmit {
                        store.update(focus.id, note: note)
                        editingNoteID = nil
                    }
                    .onExitCommand { editingNoteID = nil }
            } else if !focus.note.isEmpty {
                Text(focus.note)
                    .font(.ui(10, s))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.leading, 22 * s)
            }
        }
        .padding(.horizontal, 8 * s)
        .padding(.vertical, 5 * s)
        .background(
            RoundedRectangle(cornerRadius: 8 * s)
                .fill(isActive ? focus.color.opacity(0.22) : (hovering ? Color.primary.opacity(0.05) : Color.clear))
        )
        .overlay(alignment: .leading) {
            // Color stripe on the left edge so the color is visible even when not active
            RoundedRectangle(cornerRadius: 2)
                .fill(focus.color)
                .frame(width: 3 * s)
                .padding(.vertical, 4 * s)
        }
        .contentShape(Rectangle())
        .onTapGesture { store.switchTo(focus.id) }
        .onHover { hovering = $0 }
        .onChange(of: editingNote) {
            if editingNote {
                note = focus.note
                noteFocused = true
            }
        }
        .contextMenu {
            Button(L.t("Rename …")) { startRenaming() }
            Button(L.t("Save as template")) { store.saveAsTemplate(focus.id) }
                .disabled(store.templates.contains { $0.title == focus.title })
            Button(L.t("Note: where did I leave off ...")) { startEditingNote() }
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

    private func startRenaming() {
        title = focus.title
        editingTitle = true
        // The field must exist before it can take focus
        DispatchQueue.main.async { titleFocused = true }
    }

    private func startEditingNote() {
        note = focus.note
        editingNoteID = focus.id
    }
}
