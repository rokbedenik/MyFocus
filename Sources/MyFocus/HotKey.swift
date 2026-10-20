import AppKit
import Carbon.HIToolbox

// A global keyboard shortcut: Carbon key code + Carbon modifier mask, plus a label for display
struct KeyShortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var keyLabel: String

    var display: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + keyLabel
    }

    static let toggleDefault = KeyShortcut(keyCode: UInt32(kVK_ANSI_F), modifiers: UInt32(controlKey | optionKey), keyLabel: "F")

    // Build from a key event; nil when no "real" modifier (⌘ ⌃ ⌥) is held
    init?(event: NSEvent) {
        let f = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var mods: UInt32 = 0
        if f.contains(.control) { mods |= UInt32(controlKey) }
        if f.contains(.option) { mods |= UInt32(optionKey) }
        if f.contains(.shift) { mods |= UInt32(shiftKey) }
        if f.contains(.command) { mods |= UInt32(cmdKey) }
        guard mods & ~UInt32(shiftKey) != 0 else { return nil }
        keyCode = UInt32(event.keyCode)
        modifiers = mods
        keyLabel = Self.label(for: event)
    }

    init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    private static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private static func label(for event: NSEvent) -> String {
        if let s = specialKeys[Int(event.keyCode)] { return s }
        return (event.charactersIgnoringModifiers ?? "?").uppercased()
    }
}

// One Carbon event handler for all global shortcuts; actions are dispatched by id
@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var handler: EventHandlerRef?
    private var entries: [UInt32: (ref: EventHotKeyRef?, shortcut: KeyShortcut, action: () -> Void)] = [:]
    private var paused = false
    private let signature = OSType(0x4D46_4F43) // "MFOC"

    private init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { center.entries[hk.id]?.action() }
            return noErr
        }, 1, &spec, selfPtr, &handler)
    }

    // nil shortcut removes the binding
    func register(id: UInt32, shortcut: KeyShortcut?, action: @escaping () -> Void) {
        if let old = entries[id]?.ref { UnregisterEventHotKey(old) }
        entries[id] = nil
        guard let shortcut else { return }
        var ref: EventHotKeyRef?
        if !paused {
            RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, EventHotKeyID(signature: signature, id: id),
                                GetApplicationEventTarget(), 0, &ref)
        }
        entries[id] = (ref, shortcut, action)
    }

    // While a shortcut is being recorded the global bindings must not fire
    func setPaused(_ p: Bool) {
        guard p != paused else { return }
        paused = p
        for (id, e) in entries {
            if p {
                if let r = e.ref { UnregisterEventHotKey(r) }
                entries[id]?.ref = nil
            } else {
                var ref: EventHotKeyRef?
                RegisterEventHotKey(e.shortcut.keyCode, e.shortcut.modifiers, EventHotKeyID(signature: signature, id: id),
                                    GetApplicationEventTarget(), 0, &ref)
                entries[id]?.ref = ref
            }
        }
    }
}
