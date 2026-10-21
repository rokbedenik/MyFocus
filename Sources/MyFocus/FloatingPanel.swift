import AppKit
import SwiftUI

// Borderless always-on-top panel that does not steal focus from other apps.
// SwiftUI reports its content size; the panel animates its frame to match, keeping the
// anchored edge (top or bottom, whichever is nearer to the screen edge) where it is.
final class FloatingPanel: NSPanel {
    // Position is persisted per display arrangement (frame autosave would also store the height,
    // which is content-driven). The anchor is decided only when the user moves the window.
    private(set) var anchorTop = false { didSet { if anchorTop != oldValue { onAnchorChange?(anchorTop) } } }
    private var anchoredTop: CGFloat = 0
    private var anchoredBottom: CGFloat = 0
    // Size at the last remembered position; a move reported while the size differs is a side effect of a resize
    private var lastSize: CGSize = .zero
    private var fitting = false
    private var observers: [NSObjectProtocol] = []
    private static let positionsKey = "panelPositions" // [arrangement: [minX, minY, maxY, anchorTop]]
    private static let legacyPositionKey = "panelPosition"

    // Lets SwiftUI lay the header on the anchored edge
    var onAnchorChange: ((Bool) -> Void)?
    // Lets SwiftUI know whether the panel has keyboard focus (typing keeps the list expanded)
    var onKeyChange: ((Bool) -> Void)?

    // Idle dimming: fade to dimmedAlpha after dimAfterSeconds without the mouse over the panel
    var dimAfterSeconds: Int = 10 { didSet { touch() } }
    // Set while something needs attention (running focus, nudge, calendar suggestion); keeps the panel fully visible
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
        animationBehavior = .none

        let hosting = FittingHostingView(rootView: content())
        // The window size is driven by fit(to:), not by constraints
        hosting.sizingOptions = []
        contentView = hosting
        // SwiftUI invalidates the intrinsic size whenever the content's ideal size changes
        hosting.onContentSizeChange = { [weak self, weak hosting] in
            guard let self, let hosting else { return }
            self.fit(to: hosting.fittingSize)
        }
        hosting.addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))

        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: NSWindow.didMoveNotification, object: self, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.fitting, self.frame.size == self.lastSize else { return }
                self.rememberPosition()
            }
        })
        observers.append(nc.addObserver(forName: NSWindow.didResizeNotification, object: self, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.touch() }
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
        onKeyChange?(true)
        touch()
    }

    override func resignKey() {
        super.resignKey()
        onKeyChange?(false)
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

    // MARK: - Size follows content

    // Called whenever the SwiftUI content changes size; animates the frame, anchored edge fixed
    func fit(to size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        let w = ceil(size.width), h = ceil(size.height)
        guard abs(frame.width - w) > 0.5 || abs(frame.height - h) > 0.5 else { return }

        guard isPositionRestored else {
            setContentSize(NSSize(width: w, height: h))
            lastSize = frame.size
            return
        }
        var y = anchorTop ? anchoredTop - h : anchoredBottom
        if let vf = (screen ?? NSScreen.main)?.visibleFrame {
            y = min(max(y, vf.minY), vf.maxY - h)
        }
        let target = NSRect(x: frame.minX, y: y, width: w, height: h)
        lastSize = target.size

        guard isVisible else {
            setFrame(target, display: true)
            savePosition()
            return
        }
        fitting = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.fitting = false
                self.savePosition()
            }
        })
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
                anchorTop = top
                anchoredTop = v[2]
                anchoredBottom = v[1]
                lastSize = frame.size
                isPositionRestored = true
                onAnchorChange?(anchorTop)
                return
            }
            placeDefault()
        } else {
            placeDefault()
        }
        isPositionRestored = true
        rememberPosition()
        onAnchorChange?(anchorTop)
    }

    private func placeDefault() {
        guard let vf = NSScreen.main?.visibleFrame else { return }
        setFrameOrigin(NSPoint(x: vf.minX + 16, y: vf.minY + 16))
    }

    // The user moved the window: pick the anchor edge anew and save
    private func rememberPosition() {
        guard isPositionRestored else { return }
        let vf = (screen ?? NSScreen.main)?.visibleFrame ?? frame
        anchorTop = (vf.maxY - frame.maxY) < (frame.minY - vf.minY)
        anchoredTop = frame.maxY
        anchoredBottom = frame.minY
        lastSize = frame.size
        savePosition()
    }

    private func savePosition() {
        guard isPositionRestored else { return }
        var positions = UserDefaults.standard.dictionary(forKey: Self.positionsKey) as? [String: [Double]] ?? [:]
        positions[Self.arrangementKey] = [frame.minX, anchoredBottom, anchoredTop, anchorTop ? 1.0 : 0.0]
        UserDefaults.standard.set(positions, forKey: Self.positionsKey)
        // The app may be killed (reinstall) right after a move; do not leave the write pending
        UserDefaults.standard.synchronize()
    }
}

// NSHostingView that reports when SwiftUI changes the content's ideal size
final class FittingHostingView<Content: View>: NSHostingView<Content> {
    var onContentSizeChange: (() -> Void)?

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        // Defer out of the layout pass; fittingSize is accurate by then
        DispatchQueue.main.async { [weak self] in self?.onContentSizeChange?() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in self?.onContentSizeChange?() }
    }
}
