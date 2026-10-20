import Foundation
import EventKit
import Combine

// Polls the user's calendars once a minute and suggests a focus when an event starts
@MainActor
final class CalendarWatcher: ObservableObject {
    struct Suggestion: Equatable {
        let eventID: String
        let title: String
        let start: Date
    }

    @Published private(set) var suggestion: Suggestion?
    @Published private(set) var accessDenied = false

    private let eventStore = EKEventStore()
    private var timer: Timer?
    private var enabled = false
    // Events already offered this session, so one event is suggested once
    private var offered = Set<String>()

    func setEnabled(_ on: Bool) {
        enabled = on
        timer?.invalidate()
        timer = nil
        suggestion = nil
        guard on else { return }
        Task { await requestAccessAndStart() }
    }

    func dismiss() {
        suggestion = nil
    }

    private func requestAccessAndStart() async {
        let granted = (try? await eventStore.requestFullAccessToEvents()) ?? false
        accessDenied = !granted
        guard granted, enabled else { return }
        check()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
    }

    private func check() {
        let now = Date()
        // Events that started in the last two minutes or start within the next minute
        let predicate = eventStore.predicateForEvents(
            withStart: now.addingTimeInterval(-120), end: now.addingTimeInterval(60), calendars: nil)
        let candidates = eventStore.events(matching: predicate)
            .filter { !$0.isAllDay && $0.status != .canceled }
            .filter { $0.startDate >= now.addingTimeInterval(-120) && $0.startDate <= now.addingTimeInterval(60) }
            .sorted { $0.startDate < $1.startDate }

        for e in candidates {
            let id = e.eventIdentifier ?? e.calendarItemIdentifier
            guard !offered.contains(id) else { continue }
            if let me = e.attendees?.first(where: { $0.isCurrentUser }), me.participantStatus == .declined { continue }
            let title = (e.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            offered.insert(id)
            suggestion = Suggestion(eventID: id, title: title, start: e.startDate)
            return
        }

        // A suggestion nobody acted on goes away after 15 minutes
        if let s = suggestion, now.timeIntervalSince(s.start) > 15 * 60 {
            suggestion = nil
        }
    }
}
