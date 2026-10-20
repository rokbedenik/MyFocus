import AppKit
import SwiftUI

// Borderless always-on-top panel that does not steal focus from other apps.
// Its size follows the SwiftUI content: the hosting view installs min/max size
// constraints equal to the content's ideal size and AppKit resizes the window.
final class FloatingPanel: NSPanel {
    // Window origin is bottom-left, so AppKit grows the window upward; we keep the top edge fixed instead
    private var anchoredTop: CGFloat?
    private var observers: [NSObjectProtocol] = []

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

        let hosting = NSHostingView(rootView: content().fixedSize())
        hosting.sizingOptions = [.minSize, .maxSize]
        contentView = hosting

        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: NSWindow.didMoveNotification, object: self, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.rememberTop() }
        })
        observers.append(nc.addObserver(forName: NSWindow.didResizeNotification, object: self, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.keepTopAnchored() }
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // Allow text fields inside the panel to receive keyboard input
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func placeTopRightIfNew() {
        // Autosaved frame wins; otherwise start in the top-right corner
        if !setFrameUsingName("MyFocusPanel"), let screen = NSScreen.main {
            let vf = screen.visibleFrame
            setFrameOrigin(NSPoint(x: vf.maxX - frame.width - 16, y: vf.maxY - frame.height - 16))
        }
        rememberTop()
    }

    private func rememberTop() {
        anchoredTop = frame.maxY
    }

    private func keepTopAnchored() {
        guard let top = anchoredTop, abs(frame.maxY - top) > 0.5 else { return }
        var y = top - frame.height
        // Do not let the window slide below the visible screen area
        if let vf = (screen ?? NSScreen.main)?.visibleFrame, y < vf.minY {
            y = vf.minY
        }
        setFrameOrigin(NSPoint(x: frame.minX, y: y))
    }
}
