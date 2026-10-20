import AppKit
import SwiftUI

// Borderless always-on-top panel that does not steal focus from other apps
final class FloatingPanel: NSPanel {
    init<Content: View>(@ViewBuilder content: () -> Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 60),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        setFrameAutosaveName("MyFocusPanel")

        let hosting = NSHostingView(rootView: content())
        hosting.sizingOptions = [.preferredContentSize]
        contentView = hosting
    }

    // Allow text fields inside the panel to receive keyboard input
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func placeTopRightIfNew() {
        // Autosaved frame wins; otherwise start in the top-right corner
        guard !setFrameUsingName("MyFocusPanel"), let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        setFrameOrigin(NSPoint(x: vf.maxX - frame.width - 16, y: vf.maxY - frame.height - 16))
    }
}
