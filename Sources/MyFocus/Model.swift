import Foundation

struct Focus: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    // "Where did I leave off" note, shown when you come back to this focus
    var note: String = ""
    var createdAt = Date()
    var totalSeconds: TimeInterval = 0
    var isDone = false
}

struct SwitchEvent: Codable, Identifiable {
    var id = UUID()
    var at: Date
    var focusID: UUID?
    var title: String
}

struct AppState: Codable {
    var focuses: [Focus] = []
    var activeID: UUID?
    var activeSince: Date?
    var log: [SwitchEvent] = []
}
