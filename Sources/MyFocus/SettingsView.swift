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
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
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
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
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
