import Foundation
import Combine

// User settings, persisted in UserDefaults
@MainActor
final class AppSettings: ObservableObject {
    static let maxFocusesRange = 1...50

    @Published var maxFocuses: Int {
        didSet {
            let clamped = min(max(maxFocuses, Self.maxFocusesRange.lowerBound), Self.maxFocusesRange.upperBound)
            if clamped != maxFocuses { maxFocuses = clamped; return }
            UserDefaults.standard.set(maxFocuses, forKey: Keys.maxFocuses)
        }
    }

    private enum Keys {
        static let maxFocuses = "maxFocuses"
    }

    init() {
        let stored = UserDefaults.standard.integer(forKey: Keys.maxFocuses)
        maxFocuses = Self.maxFocusesRange.contains(stored) ? stored : 3
    }
}
