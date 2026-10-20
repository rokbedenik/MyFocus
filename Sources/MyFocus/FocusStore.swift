import Foundation
import Combine

@MainActor
final class FocusStore: ObservableObject {
    let settings: AppSettings

    @Published private(set) var state = AppState()
    @Published var now = Date()

    private let fileURL: URL
    private var ticker: Timer?
    // Focus that was active when the screen got locked; resumed on unlock
    private var pausedByLock: UUID?

    // Snapshots taken before destructive actions (delete, done); newest last
    private var undoStack: [(label: String, state: AppState)] = []
    @Published private(set) var undoLabel: String?

    // When the user last confirmed "still on this?"; nil until asked
    @Published private(set) var nudgeAckAt: Date?

    init(settings: AppSettings) {
        self.settings = settings
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
    var canAdd: Bool { focuses.count < settings.maxFocuses }

    // True when the active focus has run for nudgeMinutes without a switch or acknowledgement
    var nudgeDue: Bool {
        guard settings.nudgeMinutes > 0, let since = state.activeSince else { return false }
        let base = max(since, nudgeAckAt ?? .distantPast)
        return now.timeIntervalSince(base) >= Double(settings.nudgeMinutes * 60)
    }

    func acknowledgeNudge() {
        nudgeAckAt = Date()
        now = Date()
    }

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

    // Newest first, "HH:mm  title" per line
    var todaysLogText: String {
        todaysLog.reversed()
            .map { "\($0.at.formatted(date: .omitted, time: .shortened))  \($0.title)" }
            .joined(separator: "\n")
    }

    // MARK: - Actions

    func add(_ title: String, activate: Bool = true) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, canAdd else { return }
        // First palette color not used by an open focus
        let used = Set(focuses.map(\.colorIndex))
        let color = (0..<FocusPalette.colors.count).first { !used.contains($0) } ?? focuses.count
        let f = Focus(title: t, colorIndex: color)
        state.focuses.append(f)
        if activate { switchTo(f.id) } else { save() }
    }

    func setColor(_ id: UUID, _ index: Int) {
        guard let i = state.focuses.firstIndex(where: { $0.id == id }) else { return }
        state.focuses[i].colorIndex = index
        save()
    }

    func switchTo(_ id: UUID?, pauseLabel: String = L.t("(paused)")) {
        guard id != state.activeID else { return }
        closeActiveInterval()
        state.activeID = id
        state.activeSince = id == nil ? nil : Date()
        nudgeAckAt = nil
        let title = id.flatMap { i in state.focuses.first { $0.id == i }?.title } ?? pauseLabel
        state.log.append(SwitchEvent(at: Date(), focusID: id, title: title))
        // Keep the log bounded
        if state.log.count > 5000 { state.log.removeFirst(state.log.count - 5000) }
        now = Date()
        save()
    }

    func pause() {
        pausedByLock = nil
        switchTo(nil)
    }

    // Screen lock / sleep: pause, remember what was running
    func pauseForLock() {
        guard let id = state.activeID else { return }
        pausedByLock = id
        switchTo(nil, pauseLabel: L.t("(locked)"))
    }

    // Unlock / wake: resume the focus that was running before the lock
    func resumeAfterLock() {
        guard let id = pausedByLock else { return }
        pausedByLock = nil
        if state.focuses.contains(where: { $0.id == id && !$0.isDone }) {
            switchTo(id)
        }
    }

    func update(_ id: UUID, title: String? = nil, note: String? = nil) {
        guard let i = state.focuses.firstIndex(where: { $0.id == id }) else { return }
        if let title, !title.trimmingCharacters(in: .whitespaces).isEmpty { state.focuses[i].title = title }
        if let note { state.focuses[i].note = note }
        save()
    }

    func markDone(_ id: UUID) {
        guard let f = state.focuses.first(where: { $0.id == id }) else { return }
        snapshot(L.t("finished \"%@\"", f.title))
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
        guard let f = state.focuses.first(where: { $0.id == id }) else { return }
        snapshot(L.t("deleted \"%@\"", f.title))
        if state.activeID == id { switchTo(nil) }
        state.focuses.removeAll { $0.id == id }
        save()
    }

    // MARK: - Undo

    private func snapshot(_ label: String) {
        closeActiveInterval()
        undoStack.append((label, state))
        if undoStack.count > 20 { undoStack.removeFirst() }
        undoLabel = label
    }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        closeActiveInterval()
        state = last.state
        // Time that passed since the snapshot is not counted
        if state.activeID != nil { state.activeSince = Date() }
        undoLabel = undoStack.last?.label
        now = Date()
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
