import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Fokusi") {
                HStack {
                    Stepper(value: $settings.maxFocuses, in: AppSettings.maxFocusesRange) {
                        Text("Največ fokusov hkrati")
                    }
                    TextField("", value: $settings.maxFocuses, format: .number)
                        .frame(width: 50)
                        .multilineTextAlignment(.trailing)
                }
                Text("Dovoljeno \(AppSettings.maxFocusesRange.lowerBound)–\(AppSettings.maxFocusesRange.upperBound). Če je omejitev manjša od števila odprtih fokusov, obstoječi ostanejo, novih pa ne moreš dodati.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
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
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 160),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            w.title = "My Focus – nastavitve"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView(settings: settings))
            w.center()
            window = w
        }
        // Accessory app: bring ourselves forward so the window actually shows on top
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
