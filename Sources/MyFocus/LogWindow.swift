import SwiftUI
import AppKit

// Today's switch log as selectable text, with a copy button
struct LogView: View {
    @ObservedObject var store: FocusStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L.t("Today: %d switches", store.todaysLog.count))
                    .font(.headline)
                Spacer()
                Button(L.t("Copy")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(store.todaysLogText, forType: .string)
                }
                .disabled(store.todaysLog.isEmpty)
                .help(L.t("Copy today's log to the clipboard"))
            }
            ScrollView {
                Text(store.todaysLogText.isEmpty ? L.t("No switches yet today.") : store.todaysLogText)
                    .font(.body.monospacedDigit())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
        }
        .padding(16)
        .frame(minWidth: 360, minHeight: 280)
    }
}

@MainActor
final class LogWindowController {
    private var window: NSWindow?
    private let store: FocusStore

    init(store: FocusStore) {
        self.store = store
    }

    func show() {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: LogView(store: store))
            w.setFrameAutosaveName("MyFocusLog")
            w.center()
            window = w
        }
        window?.title = L.t("My Focus – Log")
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
