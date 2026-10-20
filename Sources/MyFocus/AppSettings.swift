import Foundation
import Combine

// User settings, persisted in UserDefaults
@MainActor
final class AppSettings: ObservableObject {
    static let maxFocusesRange = 1...50
    static let nudgeMinutesRange = 0...240

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

    @Published var language: Language {
        didSet {
            L.current = language
            UserDefaults.standard.set(language.rawValue, forKey: Keys.language)
        }
    }

    private enum Keys {
        static let maxFocuses = "maxFocuses"
        static let nudgeMinutes = "nudgeMinutes"
        static let language = "language"
    }

    init() {
        let d = UserDefaults.standard
        let storedMax = d.integer(forKey: Keys.maxFocuses)
        maxFocuses = Self.maxFocusesRange.contains(storedMax) ? storedMax : 3
        nudgeMinutes = d.object(forKey: Keys.nudgeMinutes) == nil ? 45 : d.integer(forKey: Keys.nudgeMinutes)
        language = d.string(forKey: Keys.language).flatMap(Language.init(rawValue:)) ?? .system
        L.current = language
    }
}

private extension ClosedRange where Bound == Int {
    func clamping(_ v: Int) -> Int { Swift.min(Swift.max(v, lowerBound), upperBound) }
}
