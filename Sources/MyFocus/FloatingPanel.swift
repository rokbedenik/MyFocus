import AppKit
import SwiftUI

// Borderless always-on-top panel that does not steal focus from other apps.
// Its size follows the SwiftUI content: the hosting view installs min/max size
// constraints equal to the content's ideal size and AppKit resizes the window.
final class FloatingPanel: NSPanel {
    // Position is persisted per display arrangement (frame autosave would also store the height,
    // which is content-driven). When the content height changes, the edge nearer to the screen edge
    // stays put: near the top the window grows downward, near the bottom it grows upward (AppKit default).
    private var anchorTop = false
    private var anchoredTop: CGFloat = 0
    private var observers: [NSObjectProtocol] = []
    private static let positionsKey = "panelPositions" // [arrangement: [minX, minY, maxY, anchorTop]]
    private static let legacyPositionKey = "panelPosition"

    // Idle dimming: fade to dimmedAlpha after dimAfterSeconds without the mouse over the panel
    var dimAfterSeconds: Int = 10 { didSet { touch() } }
    // Set while something needs attention (nudge, calendar suggestion); keeps the panel fully visible
    var holdAwake = false { didSet { touch() } }
    private let dimmedAlpha: CGFloat = 0.45
    private var dimTimer: Timer?
    private var mouseInside = false

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

        let hosting = NSHostingView(rootView: content().fixedSize())
        hosting.sizingOptions = [.minSize, .maxSize]
        contentView = hosting
        hosting.addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))

        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: NSWindow.didMoveNotification, object: self, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.rememberPosition() }
        })
        observers.append(nc.addObserver(forName: NSWindow.didResizeNotification, object: self, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.keepAnchored()
                self?.touch()
            }
        })
        // Display plugged/unplugged or resolution changed: use the position saved for that arrangement
        observers.append(nc.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.restorePosition() }
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // Allow text fields inside the panel to receive keyboard input
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func becomeKey() {
        super.becomeKey()
        touch()
    }

    override func resignKey() {
        super.resignKey()
        touch()
    }

    override func mouseEntered(with event: NSEvent) {
        mouseInside = true
        touch()
    }

    override func mouseExited(with event: NSEvent) {
        mouseInside = false
        touch()
    }

    // MARK: - Idle dimming

    // Something happened: show at full opacity and restart the idle countdown
    func touch() {
        dimTimer?.invalidate()
        setAlpha(1)
        guard dimAfterSeconds > 0, !mouseInside, !holdAwake, !isKeyWindow else { return }
        dimTimer = Timer.scheduledTimer(withTimeInterval: Double(dimAfterSeconds), repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.mouseInside, !self.holdAwake, !self.isKeyWindow else { return }
                self.setAlpha(self.dimmedAlpha)
            }
        }
    }

    private func setAlpha(_ a: CGFloat) {
        guard abs(alphaValue - a) > 0.01 else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            animator().alphaValue = a
        }
    }

    // MARK: - Position (per display arrangement)

    // Identifies the current set of displays by their frames
    private static var arrangementKey: String {
        NSScreen.screens
            .map { "\(Int($0.frame.minX)),\(Int($0.frame.minY)),\(Int($0.frame.width))x\(Int($0.frame.height))" }
            .sorted()
            .joined(separator: "|")
    }

    private var isPositionRestored = false

    // Saved position for this arrangement wins; otherwise bottom-left corner of the main screen
    func restorePosition() {
        let d = UserDefaults.standard
        var positions = d.dictionary(forKey: Self.positionsKey) as? [String: [Double]] ?? [:]
        // One-time migration from the single-position format
        if positions.isEmpty, let old = d.array(forKey: Self.legacyPositionKey) as? [Double], old.count == 4 {
            positions[Self.arrangementKey] = old
            d.removeObject(forKey: Self.legacyPositionKey)
        }
        if let v = positions[Self.arrangementKey], v.count == 4 {
            let top = v[3] != 0
            setFrameOrigin(NSPoint(x: v[0], y: top ? v[2] - frame.height : v[1]))
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
                placeDefault()
            }
        } else {
            placeDefault()
        }
        isPositionRestored = true
        rememberPosition()
    }

    private func placeDefault() {
        guard let vf = NSScreen.main?.visibleFrame else { return }
        setFrameOrigin(NSPoint(x: vf.minX + 16, y: vf.minY + 16))
    }

    private func rememberPosition() {
        guard isPositionRestored else { return }
        let vf = (screen ?? NSScreen.main)?.visibleFrame ?? frame
        anchorTop = (vf.maxY - frame.maxY) < (frame.minY - vf.minY)
        anchoredTop = frame.maxY
        var positions = UserDefaults.standard.dictionary(forKey: Self.positionsKey) as? [String: [Double]] ?? [:]
        positions[Self.arrangementKey] = [frame.minX, frame.minY, frame.maxY, anchorTop ? 1.0 : 0.0]
        UserDefaults.standard.set(positions, forKey: Self.positionsKey)
    }

    private func keepAnchored() {
        // AppKit keeps the bottom edge; only intervene when the top edge is the anchor
        guard anchorTop, abs(frame.maxY - anchoredTop) > 0.5 else { return }
        var y = anchoredTop - frame.height
        if let vf = (screen ?? NSScreen.main)?.visibleFrame, y < vf.minY {
            y = vf.minY
        }
        setFrameOrigin(NSPoint(x: frame.minX, y: y))
    }
}
