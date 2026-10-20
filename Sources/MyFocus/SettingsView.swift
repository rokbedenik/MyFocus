import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section(L.t("Focuses")) {
                HStack {
                    Stepper(value: $settings.maxFocuses, in: AppSettings.maxFocusesRange) {
                        Text(L.t("Maximum focuses at once"))
                    }
                    TextField("", value: $settings.maxFocuses, format: .number)
                        .frame(width: 50)
                        .multilineTextAlignment(.trailing)
                }
                Text(L.t("Allowed %d–%d. If the limit is below the number of open focuses, existing ones stay but you cannot add new ones.",
                         AppSettings.maxFocusesRange.lowerBound, AppSettings.maxFocusesRange.upperBound))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L.t("Inactivity nudge")) {
                HStack {
                    Stepper(value: $settings.nudgeMinutes, in: AppSettings.nudgeMinutesRange, step: 5) {
                        Text(L.t("Ask \"still on this?\" after"))
                    }
                    TextField("", value: $settings.nudgeMinutes, format: .number)
                        .frame(width: 50)
                        .multilineTextAlignment(.trailing)
                    Text(L.t("minutes (0 = off)"))
                        .foregroundStyle(.secondary)
                }
            }

            Section(L.t("Window")) {
                HStack {
                    Stepper(value: $settings.dimAfterSeconds, in: AppSettings.dimAfterRange, step: 5) {
                        Text(L.t("Dim the window when idle after"))
                    }
                    TextField("", value: $settings.dimAfterSeconds, format: .number)
                        .frame(width: 50)
                        .multilineTextAlignment(.trailing)
                    Text(L.t("seconds (0 = never)"))
                        .foregroundStyle(.secondary)
                }
                Text(L.t("The window fades when the mouse is not over it and comes back on hover, on a switch, or when a nudge is due."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L.t("Shortcuts")) {
                shortcutRow(L.t("Show/hide window"), $settings.toggleShortcut)
                shortcutRow(L.t("New focus"), $settings.newFocusShortcut)
                shortcutRow(L.t("Note: where did I leave off"), $settings.noteShortcut)
                Text(L.t("Click a field and press the keys. Use ⌘, ⌃ or ⌥ with the key. Esc cancels, ⌫ turns the shortcut off."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L.t("Do Not Disturb")) {
                Toggle(L.t("Turn on Do Not Disturb while a focus is running"), isOn: $settings.dndEnabled)
                Text(L.t("Turned off on pause, screen lock, sleep and quit. macOS has no API for Focus modes, so this needs two shortcuts in the Shortcuts app, named exactly \"%@\" and \"%@\", each with a single \"Set Focus\" action (Do Not Disturb → On / Off).",
                         DoNotDisturb.onShortcut, DoNotDisturb.offShortcut))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(L.t("Open Shortcuts")) {
                    NSWorkspace.shared.open(URL(string: "shortcuts://")!)
                }
            }

            Section(L.t("Language")) {
                Picker(L.t("Language"), selection: $settings.language) {
                    ForEach(Language.allCases) { lang in
                        Text(lang.label).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func shortcutRow(_ title: String, _ binding: Binding<KeyShortcut?>) -> some View {
        HStack {
            Text(title)
            Spacer()
            ShortcutRecorder(shortcut: binding)
                .fixedSize()
        }
    }
}

// Standard titled window for settings; kept alive and reused
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func show() {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 680),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView(settings: settings))
            w.center()
            window = w
        }
        window?.title = L.t("My Focus – Settings")
        // Accessory app: bring ourselves forward so the window actually shows on top
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
