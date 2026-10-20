import SwiftUI
import Combine

// Requests from outside SwiftUI (global shortcuts, menu); views react to the counters changing
@MainActor
final class PanelCommands: ObservableObject {
    @Published var newFocusTick = 0
    @Published var noteTick = 0
}

struct PanelView: View {
    @ObservedObject var store: FocusStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var commands: PanelCommands

    @State private var adding = false
    @State private var newTitle = ""
    @State private var editingNoteID: UUID?
    @FocusState private var inputFocused: Bool

    private var nudging: Bool { store.nudgeDue }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if nudging { nudgeBar }
            if !store.focuses.isEmpty {
                Divider()
                VStack(spacing: 2) {
                    ForEach(store.focuses) { f in
                        FocusRow(store: store, settings: settings, focus: f, editingNoteID: $editingNoteID)
                    }
                }
            }
            if adding { addField }
            if store.focuses.isEmpty && !adding {
                Text(L.t("Click + and type what you are working on."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        HStack(spacing: 8) {
            // Left part doubles as the drag handle for moving the window
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)
                if let a = store.active {
                    Circle()
                        .fill(a.color)
                        .frame(width: 8, height: 8)
                    Text(L.t("Working"))
                        .font(.headline)
                    Text("· \(formatDuration(store.seconds(for: a)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    Image(systemName: "pause.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(L.t("Paused"))
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .overlay(DragHandle())
            .help(L.t("Drag to move the window"))

            Button { store.pause() } label: {
                Image(systemName: "pause.circle.fill")
                    .font(.title3)
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
            Button { store.pause() } label: {
                Image(systemName: "pause.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel(L.t("Pause"))
            .help(L.t("Pause"))
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
}

struct FocusRow: View {
    @ObservedObject var store: FocusStore
    @ObservedObject var settings: AppSettings
    let focus: Focus
    @Binding var editingNoteID: UUID?
    @State private var note = ""
    @State private var hovering = false
    @FocusState private var noteFocused: Bool

    private var isActive: Bool { store.state.activeID == focus.id }
    private var editingNote: Bool { editingNoteID == focus.id }

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
                    .focused($noteFocused)
                    .onSubmit {
                        store.update(focus.id, note: note)
                        editingNoteID = nil
                    }
                    .onExitCommand { editingNoteID = nil }
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
        .onChange(of: editingNote) {
            if editingNote {
                note = focus.note
                noteFocused = true
            }
        }
        .contextMenu {
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

    private func startEditingNote() {
        note = focus.note
        editingNoteID = focus.id
    }
}
