import Foundation
import Combine

// User settings, persisted in UserDefaults
@MainActor
final class AppSettings: ObservableObject {
    static let maxFocusesRange = 1...50
    static let nudgeMinutesRange = 0...240
    static let dimAfterRange = 0...300
    static let uiScaleRange = 0.8...2.0

    @Published var maxFocuses: Int {
        didSet {
            let clamped = Self.maxFocusesRange.clamping(maxFocuses)
            if clamped != maxFocuses { maxFocuses = clamped; return }
            UserDefaults.standard.set(maxFocuses, forKey: Keys.maxFocuses)
        }
    }

    // Minutes on the same focus before the panel asks "still on this?"; 0 disables
    @Published var nudgeMinutes: Int {
        didSet {
            let clamped = Self.nudgeMinutesRange.clamping(nudgeMinutes)
            if clamped != nudgeMinutes { nudgeMinutes = clamped; return }
            UserDefaults.standard.set(nudgeMinutes, forKey: Keys.nudgeMinutes)
        }
    }

    // Seconds without the mouse over the panel before it fades; 0 disables
    @Published var dimAfterSeconds: Int {
        didSet {
            let clamped = Self.dimAfterRange.clamping(dimAfterSeconds)
            if clamped != dimAfterSeconds { dimAfterSeconds = clamped; return }
            UserDefaults.standard.set(dimAfterSeconds, forKey: Keys.dimAfterSeconds)
        }
    }

    // Turn on Do Not Disturb (via Shortcuts) while a focus runs, off on pause/lock/quit
    @Published var dndEnabled: Bool {
        didSet { UserDefaults.standard.set(dndEnabled, forKey: Keys.dndEnabled) }
    }

    // Global shortcuts; nil = off
    @Published var toggleShortcut: KeyShortcut? {
        didSet { Self.store(toggleShortcut, key: Keys.toggleShortcut) }
    }
    @Published var newFocusShortcut: KeyShortcut? {
        didSet { Self.store(newFocusShortcut, key: Keys.newFocusShortcut) }
    }
    @Published var noteShortcut: KeyShortcut? {
        didSet { Self.store(noteShortcut, key: Keys.noteShortcut) }
    }

    // Scale factor for the whole panel (fonts, icons, paddings, width); 1 = default
    @Published var uiScale: Double {
        didSet {
            let clamped = min(max(uiScale, Self.uiScaleRange.lowerBound), Self.uiScaleRange.upperBound)
            if clamped != uiScale { uiScale = clamped; return }
            UserDefaults.standard.set(uiScale, forKey: Keys.uiScale)
        }
    }

    // Offer to switch focus when a calendar event starts
    @Published var calendarEnabled: Bool {
        didSet { UserDefaults.standard.set(calendarEnabled, forKey: Keys.calendarEnabled) }
    }

    // Keep state.json in a cloud-synced folder instead of Application Support
    @Published var syncEnabled: Bool {
        didSet { UserDefaults.standard.set(syncEnabled, forKey: Keys.syncEnabled) }
    }
    @Published var syncFolder: String {
        didSet { UserDefaults.standard.set(syncFolder, forKey: Keys.syncFolder) }
    }

    static let defaultSyncFolder = NSHomeDirectory() + "/Library/Mobile Documents/com~apple~CloudDocs/MyFocus"

    @Published var language: Language {
        didSet {
            L.current = language
            UserDefaults.standard.set(language.rawValue, forKey: Keys.language)
        }
    }

    private enum Keys {
        static let maxFocuses = "maxFocuses"
        static let nudgeMinutes = "nudgeMinutes"
        static let dimAfterSeconds = "dimAfterSeconds"
        static let dndEnabled = "dndEnabled"
        static let toggleShortcut = "toggleShortcut"
        static let newFocusShortcut = "newFocusShortcut"
        static let noteShortcut = "noteShortcut"
        static let uiScale = "uiScale"
        static let calendarEnabled = "calendarEnabled"
        static let syncEnabled = "syncEnabled"
        static let syncFolder = "syncFolder"
        static let language = "language"
    }

    init() {
        let d = UserDefaults.standard
        let storedMax = d.integer(forKey: Keys.maxFocuses)
        maxFocuses = Self.maxFocusesRange.contains(storedMax) ? storedMax : 3
        nudgeMinutes = d.object(forKey: Keys.nudgeMinutes) == nil ? 45 : d.integer(forKey: Keys.nudgeMinutes)
        dimAfterSeconds = d.object(forKey: Keys.dimAfterSeconds) == nil ? 10 : d.integer(forKey: Keys.dimAfterSeconds)
        dndEnabled = d.bool(forKey: Keys.dndEnabled)
        toggleShortcut = Self.load(key: Keys.toggleShortcut, default: .toggleDefault)
        newFocusShortcut = Self.load(key: Keys.newFocusShortcut, default: nil)
        noteShortcut = Self.load(key: Keys.noteShortcut, default: nil)
        let scale = d.double(forKey: Keys.uiScale)
        uiScale = Self.uiScaleRange.contains(scale) ? scale : 1.0
        calendarEnabled = d.bool(forKey: Keys.calendarEnabled)
        syncEnabled = d.bool(forKey: Keys.syncEnabled)
        syncFolder = d.string(forKey: Keys.syncFolder) ?? Self.defaultSyncFolder
        language = d.string(forKey: Keys.language).flatMap(Language.init(rawValue:)) ?? .system
        L.current = language
    }
}

extension AppSettings {
    // Shortcuts are stored as JSON; an empty value means "explicitly off" (as opposed to never set)
    fileprivate static func store(_ s: KeyShortcut?, key: String) {
        let data = s.flatMap { try? JSONEncoder().encode($0) } ?? Data()
        UserDefaults.standard.set(data, forKey: key)
    }

    fileprivate static func load(key: String, default def: KeyShortcut?) -> KeyShortcut? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return def }
        return data.isEmpty ? nil : try? JSONDecoder().decode(KeyShortcut.self, from: data)
    }
}

private extension ClosedRange where Bound == Int {
    func clamping(_ v: Int) -> Int { Swift.min(Swift.max(v, lowerBound), upperBound) }
}
