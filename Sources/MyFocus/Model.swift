import Foundation
import SwiftUI

enum FocusPalette {
    // Names are L10n keys
    static let colors: [(name: String, color: Color)] = [
        ("Green", .green), ("Blue", .blue), ("Orange", .orange), ("Pink", .pink),
        ("Purple", .purple), ("Teal", .teal), ("Yellow", .yellow), ("Red", .red),
    ]

    static func color(_ index: Int) -> Color {
        colors[((index % colors.count) + colors.count) % colors.count].color
    }
}

struct Focus: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    // "Where did I leave off" note, shown when you come back to this focus
    var note: String = ""
    var createdAt = Date()
    var totalSeconds: TimeInterval = 0
    var isDone = false
    var colorIndex: Int = 0

    var color: Color { FocusPalette.color(colorIndex) }

    init(title: String, colorIndex: Int = 0) {
        self.title = title
        self.colorIndex = colorIndex
    }

    // Custom decoding so state files written before colorIndex existed still load
    private enum CodingKeys: String, CodingKey {
        case id, title, note, createdAt, totalSeconds, isDone, colorIndex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        totalSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .totalSeconds) ?? 0
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        colorIndex = try c.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
    }
}

struct SwitchEvent: Codable, Identifiable {
    var id = UUID()
    var at: Date
    var focusID: UUID?
    var title: String
}

// Reusable focus: one click creates (or switches to) a focus with this name and color
struct FocusTemplate: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var colorIndex: Int = 0
    var note: String = ""

    var color: Color { FocusPalette.color(colorIndex) }
}

struct AppState: Codable {
    var focuses: [Focus] = []
    var activeID: UUID?
    // The focus shown in collapsed mode while paused
    var lastActiveID: UUID?
    var activeSince: Date?
    var log: [SwitchEvent] = []
    var templates: [FocusTemplate] = []

    init() {}

    // Tolerant decoding so files written by older versions (without newer keys) still load
    private enum CodingKeys: String, CodingKey {
        case focuses, activeID, lastActiveID, activeSince, log, templates
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        focuses = try c.decodeIfPresent([Focus].self, forKey: .focuses) ?? []
        activeID = try c.decodeIfPresent(UUID.self, forKey: .activeID)
        lastActiveID = try c.decodeIfPresent(UUID.self, forKey: .lastActiveID)
        activeSince = try c.decodeIfPresent(Date.self, forKey: .activeSince)
        log = try c.decodeIfPresent([SwitchEvent].self, forKey: .log) ?? []
        templates = try c.decodeIfPresent([FocusTemplate].self, forKey: .templates) ?? []
    }
}
