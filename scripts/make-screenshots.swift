import AppKit
import SwiftUI

// Renders the panel and the settings window with sample data into PNG files, without showing any window.
// Compiled together with Sources/MyFocus/*.swift (except main.swift) by scripts/make-screenshots.sh.
// Usage: make-screenshots <output directory>

@main
struct MakeScreenshots {
    static func main() {
        MainActor.assumeIsolated { run() }
    }

    @MainActor
    static func run() {
        let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/screenshots",
                         isDirectory: true)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        // Sample state lives in a scratch directory so the real data is never touched
        let tmp = ProcessInfo.processInfo.environment["TMPDIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.temporaryDirectory
        let stateDir = tmp.appendingPathComponent("myfocus-screenshots-\(getpid())", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
        } catch {
            print("Could not create \(stateDir.path): \(error)")
            exit(1)
        }
        setenv("MYFOCUS_STATE_DIR", stateDir.path, 1)
        defer { try? FileManager.default.removeItem(at: stateDir) }

        // Running: three focuses, the second one active for 23 minutes, one with a note
        shoot("panel-running", state: sample(active: 1), collapse: false, minutes: 23, outDir: outDir)
        // Collapsed: only the active focus, the others as dots
        shoot("panel-collapsed", state: sample(active: 1), collapse: true, minutes: 23, outDir: outDir)
        // Paused: no active focus, the last one stays visible
        shoot("panel-paused", state: sample(active: nil), collapse: false, minutes: 0, outDir: outDir)
        // Nudge: 52 minutes on the same focus with the 45 minute default
        shoot("panel-nudge", state: sample(active: 0), collapse: false, minutes: 52, outDir: outDir)

        // The settings window is not rendered: its sidebar List needs a real window to lay out
        print("Screenshots written to \(outDir.path)")
    }

    // MARK: - Sample data

    @MainActor
    static func sample(active: Int?) -> AppState {
        var s = AppState()
        var a = Focus(title: "Write release notes", colorIndex: 0)
        a.totalSeconds = 41 * 60
        var b = Focus(title: "Review PR #412", colorIndex: 1)
        b.note = "Left off at the migration script, check the rollback path"
        // While active its elapsed time comes from the clock offset instead
        b.totalSeconds = active == 1 ? 0 : 23 * 60
        var c = Focus(title: "Prepare demo for Thursday", colorIndex: 2)
        c.totalSeconds = 12 * 60
        s.focuses = [a, b, c]
        if let active {
            s.activeID = s.focuses[active].id
            s.lastActiveID = s.activeID
            s.activeSince = Date()
        } else {
            s.lastActiveID = b.id
        }
        s.templates = [
            FocusTemplate(title: "Email", colorIndex: 5),
            FocusTemplate(title: "Daily standup", colorIndex: 3),
        ]
        let now = Date()
        s.log = [
            SwitchEvent(at: now.addingTimeInterval(-3 * 3600), focusID: a.id, title: a.title),
            SwitchEvent(at: now.addingTimeInterval(-50 * 60), focusID: c.id, title: c.title),
            SwitchEvent(at: now.addingTimeInterval(-23 * 60), focusID: b.id, title: b.title),
        ]
        return s
    }

    static func write(state: AppState, to dir: URL) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        do {
            try enc.encode(state).write(to: dir.appendingPathComponent("state.json"))
        } catch {
            print("Could not write sample state: \(error)")
        }
    }

    @MainActor
    static func makeSettings(collapse: Bool) -> AppSettings {
        let settings = AppSettings()
        settings.language = .en
        settings.uiScale = 1.0
        settings.maxFocuses = 3
        settings.nudgeMinutes = 45
        settings.collapseWhenIdle = collapse
        return settings
    }

    // MARK: - Rendering

    @MainActor
    static func shoot(_ name: String, state: AppState, collapse: Bool, minutes: Int, outDir: URL) {
        let stateDir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["MYFOCUS_STATE_DIR"]!, isDirectory: true)
        write(state: state, to: stateDir)
        let settings = makeSettings(collapse: collapse)
        let store = FocusStore(settings: settings)
        if store.focuses.isEmpty {
            print("Sample state was not loaded from \(store.fileURL.path)")
            exit(1)
        }
        // The clock the panel reads; moving it forward gives the elapsed time (and the nudge) without waiting
        store.now = Date().addingTimeInterval(Double(minutes * 60))
        let panel = PanelView(store: store, settings: settings, commands: PanelCommands(), calendar: CalendarWatcher())
            .fixedSize()
            .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
            .padding(28)
        for dark in [false, true] {
            // A soft desktop-like backdrop so the floating panel reads as a window
            let backdrop = LinearGradient(
                colors: dark ? [Color(red: 0.16, green: 0.18, blue: 0.24), Color(red: 0.10, green: 0.11, blue: 0.15)]
                             : [Color(red: 0.86, green: 0.90, blue: 0.96), Color(red: 0.76, green: 0.82, blue: 0.92)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            let hosting = NSHostingView(rootView: panel.background(backdrop))
            let size = hosting.fittingSize
            render(hosting, size: size, dark: dark, to: outDir.appendingPathComponent("\(name)\(dark ? "-dark" : "").png"))
        }
    }

    // Draws the view at 2x into a PNG (Retina-like crispness)
    @MainActor
    static func render(_ view: NSView, size: CGSize, dark: Bool, to url: URL) {
        view.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        let scale = 2
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width) * scale, pixelsHigh: Int(size.height) * scale,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
            print("Could not create bitmap for \(url.lastPathComponent)")
            return
        }
        rep.size = size
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        do {
            try png.write(to: url)
            print("  \(url.lastPathComponent)  \(Int(size.width))x\(Int(size.height))")
        } catch {
            print("Could not write \(url.path): \(error)")
        }
    }
}
