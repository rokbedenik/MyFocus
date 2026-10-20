import Foundation
import Combine

@MainActor
final class FocusStore: ObservableObject {
    @Published private(set) var state = AppState()
    @Published var now = Date()

    private let fileURL: URL
    private var ticker: Timer?

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MyFocus", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("state.json")
        load()
        // Refresh elapsed time display every 30 s
        ticker = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
    }

    var focuses: [Focus] { state.focuses.filter { !$0.isDone } }
    var doneFocuses: [Focus] { state.focuses.filter { $0.isDone } }
    var active: Focus? { state.focuses.first { $0.id == state.activeID } }

    func seconds(for focus: Focus) -> TimeInterval {
        var s = focus.totalSeconds
        if focus.id == state.activeID, let since = state.activeSince {
            s += now.timeIntervalSince(since)
        }
        return s
    }

    var todaysLog: [SwitchEvent] {
        let start = Calendar.current.startOfDay(for: Date())
        return state.log.filter { $0.at >= start }
    }

    // MARK: - Actions

    func add(_ title: String, activate: Bool = true) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let f = Focus(title: t)
        state.focuses.append(f)
        if activate { switchTo(f.id) } else { save() }
    }

    func switchTo(_ id: UUID?) {
        guard id != state.activeID else { return }
        closeActiveInterval()
        state.activeID = id
        state.activeSince = id == nil ? nil : Date()
        let title = id.flatMap { i in state.focuses.first { $0.id == i }?.title } ?? "(pavza)"
        state.log.append(SwitchEvent(at: Date(), focusID: id, title: title))
        // Keep the log bounded
        if state.log.count > 5000 { state.log.removeFirst(state.log.count - 5000) }
        now = Date()
        save()
    }

    func pause() { switchTo(nil) }

    func update(_ id: UUID, title: String? = nil, note: String? = nil) {
        guard let i = state.focuses.firstIndex(where: { $0.id == id }) else { return }
        if let title, !title.trimmingCharacters(in: .whitespaces).isEmpty { state.focuses[i].title = title }
        if let note { state.focuses[i].note = note }
        save()
    }

    func markDone(_ id: UUID) {
        if state.activeID == id { switchTo(nil) }
        guard let i = state.focuses.firstIndex(where: { $0.id == id }) else { return }
        state.focuses[i].isDone = true
        save()
    }

    func reopen(_ id: UUID) {
        guard let i = state.focuses.firstIndex(where: { $0.id == id }) else { return }
        state.focuses[i].isDone = false
        save()
    }

    func delete(_ id: UUID) {
        if state.activeID == id { switchTo(nil) }
        state.focuses.removeAll { $0.id == id }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        var open = focuses
        open.move(fromOffsets: source, toOffset: destination)
        state.focuses = open + doneFocuses
        save()
    }

    // MARK: - Persistence

    private func closeActiveInterval() {
        guard let id = state.activeID, let since = state.activeSince,
              let i = state.focuses.firstIndex(where: { $0.id == id }) else { return }
        state.focuses[i].totalSeconds += Date().timeIntervalSince(since)
        state.activeSince = Date()
    }

    func flush() {
        closeActiveInterval()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if let s = try? dec.decode(AppState.self, from: data) {
            state = s
            // Do not count time while the app was not running
            if state.activeID != nil { state.activeSince = Date() }
        }
    }

    private func save() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(state) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

func formatDuration(_ s: TimeInterval) -> String {
    let m = Int(s) / 60
    return m < 60 ? "\(m) min" : String(format: "%d h %02d min", m / 60, m % 60)
}
