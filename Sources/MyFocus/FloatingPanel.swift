import AppKit
import SwiftUI

// Borderless always-on-top panel that does not steal focus from other apps.
// Its size follows the SwiftUI content: the hosting view installs min/max size
// constraints equal to the content's ideal size and AppKit resizes the window.
final class FloatingPanel: NSPanel {
    // Position is persisted per display arrangement (frame autosave would also store the height,
    // which is content-driven). When the content height changes the top edge stays put, so the
    // header with the controls never moves; near the bottom of the screen the window is pushed up instead.
    private var anchorTop = false
    private var anchoredTop: CGFloat = 0
    private var anchoredBottom: CGFloat = 0
    // Size at the last remembered position; a move reported while the size differs is a side effect of a resize
    private var lastSize: CGSize = .zero
    private var observers: [NSObjectProtocol] = []
    private static let positionsKey = "panelPositions" // [arrangement: [minX, minY, maxY, anchorTop]]
    private static let legacyPositionKey = "panelPosition"

    // Idle dimming: fade to dimmedAlpha after dimAfterSeconds without the mouse over the panel; a click wakes it
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

        let hosting = FirstMouseHostingView(rootView: content().fixedSize())
        hosting.sizingOptions = [.minSize, .maxSize]
        contentView = hosting
        hosting.addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))

        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: NSWindow.didMoveNotification, object: self, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.frame.size == self.lastSize else { return }
                self.rememberPosition()
            }
        })
        observers.append(nc.addObserver(forName: NSWindow.didResizeNotification, object: self, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
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

    // Hovering neither wakes a dimmed panel nor lets a visible one fade; only a click wakes it
    override func mouseEntered(with event: NSEvent) {
        mouseInside = true
        dimTimer?.invalidate()
    }

    override func mouseExited(with event: NSEvent) {
        mouseInside = false
        if alphaValue > dimmedAlpha + 0.01 { touch() }
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .rightMouseDown { touch() }
        super.sendEvent(event)
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
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
                // The content has not been laid out yet, so the height is still provisional
                anchorTop = true
                anchoredTop = v[2]
                anchoredBottom = v[1]
                lastSize = frame.size
                isPositionRestored = true
                return
            }
            placeDefault()
        } else {
            placeDefault()
        }
        isPositionRestored = true
        rememberPosition()
    }

    private func placeDefault() {
        guard let vf = NSScreen.main?.visibleFrame else { return }
        setFrameOrigin(NSPoint(x: vf.minX + 16, y: vf.maxY - frame.height - 16))
    }

    private func rememberPosition() {
        guard isPositionRestored else { return }
        // The top edge is always the anchor: the window grows downward and the header never moves
        anchorTop = true
        anchoredTop = frame.maxY
        anchoredBottom = frame.minY
        lastSize = frame.size
        var positions = UserDefaults.standard.dictionary(forKey: Self.positionsKey) as? [String: [Double]] ?? [:]
        positions[Self.arrangementKey] = [frame.minX, frame.minY, frame.maxY, anchorTop ? 1.0 : 0.0]
        UserDefaults.standard.set(positions, forKey: Self.positionsKey)
        // The app may be killed (reinstall) right after a move; do not leave the write pending
        UserDefaults.standard.synchronize()
    }

    // After a content-driven resize put the anchored edge back where it was, whichever edge AppKit kept
    private func keepAnchored() {
        guard isPositionRestored else { return }
        var y = anchorTop ? anchoredTop - frame.height : anchoredBottom
        if let vf = (screen ?? NSScreen.main)?.visibleFrame {
            y = min(max(y, vf.minY), vf.maxY - frame.height)
        }
        if abs(frame.minY - y) > 0.5 {
            setFrameOrigin(NSPoint(x: frame.minX, y: y))
        }
        lastSize = frame.size
        rememberPosition()
    }
}

// The panel is usually not the key window. By default AppKit uses the first click only to make it key and
// drops the event, so a button would need two clicks; accepting the first mouse makes every click count.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
