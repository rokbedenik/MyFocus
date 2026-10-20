import AppKit
import SwiftUI
import Carbon.HIToolbox

// Button that records a key combination: click, press keys. Esc cancels, Delete clears.
struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: KeyShortcut?

    func makeNSView(context: Context) -> RecorderButton {
        let b = RecorderButton()
        b.onChange = { context.coordinator.parent.shortcut = $0 }
        b.shortcut = shortcut
        return b
    }

    func updateNSView(_ b: RecorderButton, context: Context) {
        context.coordinator.parent = self
        if !b.recording { b.shortcut = shortcut }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator {
        var parent: ShortcutRecorder
        init(parent: ShortcutRecorder) { self.parent = parent }
    }

    final class RecorderButton: NSButton {
        var onChange: ((KeyShortcut?) -> Void)?
        var shortcut: KeyShortcut? { didSet { refreshTitle() } }
        private(set) var recording = false { didSet { refreshTitle() } }

        init() {
            super.init(frame: .zero)
            bezelStyle = .rounded
            setButtonType(.momentaryPushIn)
            target = self
            action = #selector(startRecording)
            widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
            refreshTitle()
        }

        required init?(coder: NSCoder) { fatalError() }

        override var acceptsFirstResponder: Bool { true }

        @objc private func startRecording() {
            recording = true
            HotKeyCenter.shared.setPaused(true)
            window?.makeFirstResponder(self)
        }

        private func stopRecording() {
            recording = false
            HotKeyCenter.shared.setPaused(false)
        }

        override func resignFirstResponder() -> Bool {
            if recording { stopRecording() }
            return super.resignFirstResponder()
        }

        // ⌘-combinations arrive here before keyDown
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard recording else { return super.performKeyEquivalent(with: event) }
            handle(event)
            return true
        }

        override func keyDown(with event: NSEvent) {
            guard recording else { return super.keyDown(with: event) }
            handle(event)
        }

        private func handle(_ event: NSEvent) {
            switch Int(event.keyCode) {
            case kVK_Escape:
                stopRecording()
            case kVK_Delete, kVK_ForwardDelete:
                shortcut = nil
                onChange?(nil)
                stopRecording()
            default:
                guard let s = KeyShortcut(event: event) else {
                    NSSound.beep()
                    return
                }
                shortcut = s
                onChange?(s)
                stopRecording()
            }
        }

        private func refreshTitle() {
            if recording {
                title = L.t("Press keys …")
            } else {
                title = shortcut?.display ?? L.t("Off")
            }
        }
    }
}
