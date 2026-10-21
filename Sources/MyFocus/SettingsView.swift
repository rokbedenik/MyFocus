import SwiftUI
import AppKit

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, shortcuts, behavior, sync
    var id: String { rawValue }

    // L10n keys
    var title: String {
        switch self {
        case .general: return "General"
        case .shortcuts: return "Shortcuts"
        case .behavior: return "Behavior"
        case .sync: return "Sync"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .shortcuts: return "keyboard"
        case .behavior: return "bell.badge"
        case .sync: return "arrow.triangle.2.circlepath.icloud"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var calendar: CalendarWatcher

    @State private var page: SettingsPage? = .general

    var body: some View {
        HStack(spacing: 0) {
            List(SettingsPage.allCases, selection: $page) { p in
                Label(L.t(p.title), systemImage: p.icon)
                    .tag(p)
            }
            .listStyle(.sidebar)
            .frame(width: 170)

            Divider()

            Group {
                switch page ?? .general {
                case .general:
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

            Section(L.t("Appearance")) {
                HStack {
                    Text(L.t("Size"))
                    Slider(value: $settings.uiScale, in: AppSettings.uiScaleRange, step: 0.05)
                    Text("\(Int((settings.uiScale * 100).rounded())) %")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                    Button(L.t("Reset")) { settings.uiScale = 1.0 }
                        .disabled(settings.uiScale == 1.0)
                }
                Text(L.t("Scales the whole panel: text, icons, spacing and width."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

            case .shortcuts:
            Form {
            Section(L.t("Shortcuts")) {
                shortcutRow(L.t("Show/hide window"), $settings.toggleShortcut)
                shortcutRow(L.t("New focus"), $settings.newFocusShortcut)
                shortcutRow(L.t("Note: where did I leave off"), $settings.noteShortcut)
                Text(L.t("Click a field and press the keys. Use ⌘, ⌃ or ⌥ with the key. Esc cancels, ⌫ turns the shortcut off."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            }

            case .behavior:
            Form {
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
                Toggle(L.t("Show only the active focus while the mouse is away"), isOn: $settings.collapseWhenIdle)
                Text(L.t("Hovering the window shows all focuses; while paused the last active one stays visible."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Stepper(value: $settings.dimAfterSeconds, in: AppSettings.dimAfterRange, step: 5) {
                        Text(L.t("While paused, dim the window after"))
                    }
                    TextField("", value: $settings.dimAfterSeconds, format: .number)
                        .frame(width: 50)
                        .multilineTextAlignment(.trailing)
                    Text(L.t("seconds (0 = never)"))
                        .foregroundStyle(.secondary)
                }
                Text(L.t("Only while no focus is running. The window fades when the mouse is not over it and comes back on hover, when a focus starts, or when a nudge is due."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L.t("Calendar")) {
                Toggle(L.t("Suggest a focus when a calendar event starts"), isOn: $settings.calendarEnabled)
                Text(L.t("Checks your calendars once a minute. Declined and all-day events are ignored. The first time, macOS asks for calendar access."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if settings.calendarEnabled && calendar.accessDenied {
                    HStack {
                        Text(L.t("Calendar access was denied. Allow it in System Settings → Privacy & Security → Calendars."))
                            .font(.caption)
                            .foregroundStyle(.red)
                        Button(L.t("Open System Settings")) {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                        }
                    }
                }
            }

            Section(L.t("Do Not Disturb")) {
                Toggle(L.t("Turn on Do Not Disturb while a focus is running"), isOn: $settings.dndEnabled)
                Text(L.t("Turned off on pause, screen lock, sleep and quit. macOS has no API for Focus modes, so this needs two shortcuts in the Shortcuts app, named exactly \"%@\" and \"%@\", each with a single \"Set Focus\" action (Do Not Disturb → On / Off).",
                         DoNotDisturb.onShortcut, DoNotDisturb.offShortcut))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(L.t("Fastest: run scripts/make-dnd-shortcuts.sh from the repo and click \"Add Shortcut\" twice."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(L.t("Open Shortcuts")) {
                    NSWorkspace.shared.open(URL(string: "shortcuts://")!)
                }
            }
            }

            case .sync:
            Form {
            Section(L.t("Sync")) {
                Toggle(L.t("Keep data in a cloud folder (for a second Mac)"), isOn: $settings.syncEnabled)
                HStack {
                    Text(L.t("Folder"))
                    TextField("", text: $settings.syncFolder)
                        .disabled(!settings.syncEnabled)
                    Button(L.t("Choose …")) { chooseSyncFolder() }
                        .disabled(!settings.syncEnabled)
                }
                Text(L.t("state.json moves into that folder; use the same folder on the other Mac. The last Mac that writes wins, so do not run a focus on both at the same time. For iCloud Drive keep the folder downloaded (turn off \"Optimize Mac Storage\" or mark it \"Keep Downloaded\")."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            }
                }
            }
            .formStyle(.grouped)
            .frame(width: 480)
        }
        .frame(height: 560)
    }

    private func shortcutRow(_ title: String, _ binding: Binding<KeyShortcut?>) -> some View {
        HStack {
            Text(title)
            Spacer()
            ShortcutRecorder(shortcut: binding)
                .fixedSize()
        }
    }

    private func chooseSyncFolder() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.canCreateDirectories = true
        p.directoryURL = URL(fileURLWithPath: settings.syncFolder).deletingLastPathComponent()
        if p.runModal() == .OK, let url = p.url {
            settings.syncFolder = url.path
        }
    }
}

// Standard titled window for settings; kept alive and reused
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: AppSettings
    private let calendar: CalendarWatcher

    init(settings: AppSettings, calendar: CalendarWatcher) {
        self.settings = settings
        self.calendar = calendar
    }

    func show() {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 650, height: 560),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView(settings: settings, calendar: calendar))
            w.center()
            w.setFrameAutosaveName("MyFocusSettings")
            window = w
        }
        window?.title = L.t("My Focus – Settings")
        // Accessory app: bring ourselves forward so the window actually shows on top
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
