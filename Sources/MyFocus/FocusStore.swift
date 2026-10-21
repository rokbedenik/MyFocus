import Foundation
import Combine

@MainActor
final class FocusStore: ObservableObject {
    let settings: AppSettings

    @Published private(set) var state = AppState()
    @Published var now = Date()

    // Where state.json lives: Application Support, or a cloud-synced folder when sync is on
    private(set) var fileURL: URL
    private var ticker: Timer?
    // Modification date of the file as last written/read by us; a newer file means another Mac wrote it
    private var knownFileDate: Date?
    // Focus that was active when the screen got locked; resumed on unlock
    private var pausedByLock: UUID?

    // Snapshots taken before destructive actions (delete, done); newest last
    private var undoStack: [(label: String, state: AppState)] = []
    @Published private(set) var undoLabel: String?

    // When the user last confirmed "still on this?"; nil until asked
    @Published private(set) var nudgeAckAt: Date?

    init(settings: AppSettings) {
        self.settings = settings
        // Start from the synced file right away when sync is on, so the stale local copy never shows
        fileURL = Self.localURL
        if settings.syncEnabled {
            let folder = settings.syncFolder.trimmingCharacters(in: .whitespaces)
            let synced = URL(fileURLWithPath: folder, isDirectory: true).appendingPathComponent("state.json")
            if !folder.isEmpty, FileManager.default.fileExists(atPath: synced.path) {
                fileURL = synced
            }
        }
        load(resetActive: true)
        // Refresh elapsed time display every 30 s; also notice writes from another Mac
        ticker = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.now = Date()
                self?.reloadIfChangedExternally()
            }
        }
    }

    // MYFOCUS_STATE_DIR overrides the location (used by scripts/make-screenshots.sh for sample data)
    static var localURL: URL {
        let dir = ProcessInfo.processInfo.environment["MYFOCUS_STATE_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("MyFocus", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("state.json")
    }

    // Move the state file: nil = back to Application Support. An existing synced file is adopted,
    // otherwise the current state is written to the new place.
    func relocate(to folder: URL?) {
        let target = folder.map { $0.appendingPathComponent("state.json") } ?? Self.localURL
        guard target != fileURL else { return }
        flush()
        if let folder {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        fileURL = target
        if folder != nil, FileManager.default.fileExists(atPath: target.path) {
            load(resetActive: false)
        } else {
            save()
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

    // MARK: - Templates

    var templates: [FocusTemplate] { state.templates }

    func addTemplate(title: String, colorIndex: Int = 0, note: String = "") {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        state.templates.append(FocusTemplate(title: t, colorIndex: colorIndex, note: note))
        save()
    }

    func updateTemplate(_ id: UUID, title: String? = nil, colorIndex: Int? = nil, note: String? = nil) {
        guard let i = state.templates.firstIndex(where: { $0.id == id }) else { return }
        if let title, !title.trimmingCharacters(in: .whitespaces).isEmpty { state.templates[i].title = title }
        if let colorIndex { state.templates[i].colorIndex = colorIndex }
        if let note { state.templates[i].note = note }
        save()
    }

    func deleteTemplate(_ id: UUID) {
        state.templates.removeAll { $0.id == id }
        save()
    }

    func saveAsTemplate(_ focusID: UUID) {
        guard let f = state.focuses.first(where: { $0.id == focusID }) else { return }
        guard !state.templates.contains(where: { $0.title == f.title }) else { return }
        addTemplate(title: f.title, colorIndex: f.colorIndex, note: f.note)
    }

    // Switch to an open focus with the template's title, or create one from the template
    func useTemplate(_ id: UUID) {
        guard let t = state.templates.first(where: { $0.id == id }) else { return }
        if let existing = focuses.first(where: { $0.title == t.title }) {
            switchTo(existing.id)
            return
        }
        guard canAdd else { return }
        var f = Focus(title: t.title, colorIndex: t.colorIndex)
        f.note = t.note
        state.focuses.append(f)
        switchTo(f.id)
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
        if let id { state.lastActiveID = id }
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
        state.focuses[i].doneAt = Date()
        save()
    }

    // MARK: - Suggestions from finished focuses

    // The last three finished focuses, newest first, offered next to the templates when adding a focus.
    // Skips dismissed ones, titles that are open again and titles a template already covers.
    var recentSuggestions: [Focus] {
        let open = Set(focuses.map(\.title))
        let covered = Set(templates.map(\.title))
        var seen = Set<String>()
        return doneFocuses
            .filter { !$0.hiddenFromSuggestions && !open.contains($0.title) && !covered.contains($0.title) }
            .sorted { ($0.doneAt ?? $0.createdAt) > ($1.doneAt ?? $1.createdAt) }
            .filter { seen.insert($0.title).inserted }
            .prefix(3)
            .map { $0 }
    }

    // Start a fresh focus with the title, color and note of a finished one (its time stays in the log)
    func reuseFinished(_ id: UUID) {
        guard canAdd, let f = state.focuses.first(where: { $0.id == id && $0.isDone }) else { return }
        var n = Focus(title: f.title, colorIndex: f.colorIndex)
        n.note = f.note
        state.focuses.append(n)
        switchTo(n.id)
    }

    // Never suggest this title again (applies to every finished focus with that title)
    func dismissSuggestion(_ id: UUID) {
        guard let title = state.focuses.first(where: { $0.id == id })?.title else { return }
        for i in state.focuses.indices where state.focuses[i].isDone && state.focuses[i].title == title {
            state.focuses[i].hiddenFromSuggestions = true
        }
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

    private var fileDate: Date? {
        (try? FileManager.default.attributesOfItem(atPath: fileURL.path))?[.modificationDate] as? Date
    }

    // resetActive: true at app launch (time while the app was closed must not count);
    // false when adopting a file another Mac is writing to, where activeSince is real
    private func load(resetActive: Bool) {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if let s = try? dec.decode(AppState.self, from: data) {
            state = s
            if resetActive, state.activeID != nil { state.activeSince = Date() }
            knownFileDate = fileDate
            now = Date()
        }
    }

    private func reloadIfChangedExternally() {
        guard let d = fileDate else { return }
        if let known = knownFileDate, d <= known.addingTimeInterval(1) { return }
        load(resetActive: false)
    }

    private func save() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(state) {
            try? data.write(to: fileURL, options: .atomic)
            knownFileDate = fileDate
        }
    }
}

func formatDuration(_ s: TimeInterval) -> String {
    let m = Int(s) / 60
    return m < 60 ? "\(m) min" : String(format: "%d h %02d min", m / 60, m % 60)
}
