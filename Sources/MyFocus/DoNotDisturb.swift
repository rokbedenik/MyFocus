import Foundation
import Combine

// macOS has no public API for Focus modes, so Do Not Disturb is toggled through two user-made
// shortcuts in the Shortcuts app (each a single "Set Focus" action), run via the `shortcuts` CLI.
@MainActor
final class DoNotDisturb {
    static let onShortcut = "MyFocus DND On"
    static let offShortcut = "MyFocus DND Off"

    private var cancellables = Set<AnyCancellable>()
    // What we last asked the system for; nil until the first decision
    private var requestedOn: Bool?

    init(store: FocusStore, settings: AppSettings) {
        store.$state.map { $0.activeID != nil }.removeDuplicates()
            .combineLatest(settings.$dndEnabled)
            .receive(on: RunLoop.main)
            .sink { [weak self] running, enabled in self?.apply(wantOn: enabled && running) }
            .store(in: &cancellables)
    }

    private func apply(wantOn: Bool) {
        guard wantOn != (requestedOn ?? false) else { return }
        requestedOn = wantOn
        Self.run(wantOn ? Self.onShortcut : Self.offShortcut)
    }

    // Never leave DND on after the app quits
    func shutdown() {
        guard requestedOn == true else { return }
        requestedOn = false
        Self.run(Self.offShortcut, wait: true)
    }

    nonisolated static func run(_ name: String, wait: Bool = false) {
        let work = {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            p.arguments = ["run", name]
            p.standardOutput = FileHandle.nullDevice
            let err = Pipe()
            p.standardError = err
            do {
                try p.run()
                p.waitUntilExit()
                if p.terminationStatus != 0 {
                    let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    NSLog("MyFocus: shortcut \"%@\" failed (%d): %@", name, p.terminationStatus, msg)
                }
            } catch {
                NSLog("MyFocus: cannot run shortcuts CLI: %@", "\(error)")
            }
        }
        if wait { work() } else { Task.detached(priority: .utility) { work() } }
    }
}
