import AppKit
import SwiftUI
import Combine
import ServiceManagement
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    lazy var store = FocusStore(settings: settings)
    private lazy var settingsWindow = SettingsWindowController(settings: settings)
    private lazy var logWindow = LogWindowController(store: store)
    private var dnd: DoNotDisturb!
    private var panel: FloatingPanel!
    private var statusItem: NSStatusItem!
    private let commands = PanelCommands()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = FloatingPanel { PanelView(store: store, settings: settings, commands: commands) }
        panel.restorePosition()
        panel.orderFrontRegardless()

        setupStatusItem()
        observeLockAndSleep()
        dnd = DoNotDisturb(store: store, settings: settings)

        // Global shortcuts follow the settings
        settings.$toggleShortcut.receive(on: RunLoop.main)
            .sink { [weak self] s in
                HotKeyCenter.shared.register(id: 1, shortcut: s) { self?.togglePanel() }
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
        settings.$newFocusShortcut.receive(on: RunLoop.main)
            .sink { [weak self] s in HotKeyCenter.shared.register(id: 2, shortcut: s) { self?.newFocus() } }
            .store(in: &cancellables)
        settings.$noteShortcut.receive(on: RunLoop.main)
            .sink { [weak self] s in HotKeyCenter.shared.register(id: 3, shortcut: s) { self?.editActiveNote() } }
            .store(in: &cancellables)

        store.$state.combineLatest(store.$now)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshStatusTitle()
                self.panel.holdAwake = self.store.nudgeDue
            }
            .store(in: &cancellables)
        // A switch/add/delete should bring the panel back to full opacity
        store.$state.map(\.activeID).removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.panel.touch() }
            .store(in: &cancellables)

        // Language change: rebuild the AppKit menu (SwiftUI views observe settings themselves)
        settings.$language
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
        settings.$dimAfterSeconds
            .receive(on: RunLoop.main)
            .sink { [weak self] s in self?.panel.dimAfterSeconds = s }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.flush()
        dnd.shutdown()
    }

    // MARK: - Screen lock / sleep -> pause, unlock / wake -> resume

    private func observeLockAndSleep() {
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.store.pauseForLock() }
        }
        dnc.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.store.resumeAfterLock() }
        }
        let wnc = NSWorkspace.shared.notificationCenter
        wnc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.store.pauseForLock() }
        }
        wnc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.store.resumeAfterLock() }
        }
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "scope", accessibilityDescription: "My Focus")
        statusItem.button?.imagePosition = .imageLeading
        rebuildMenu()
    }

    private func refreshStatusTitle() {
        let title = store.active?.title ?? ""
        statusItem?.button?.title = title.count > 30 ? String(title.prefix(29)) + "…" : title
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        // We set isEnabled ourselves (undo item); otherwise AppKit would re-enable it
        menu.autoenablesItems = false
        for f in store.focuses {
            let item = NSMenuItem(title: f.title, action: #selector(switchFromMenu(_:)), keyEquivalent: "")
            item.representedObject = f.id
            item.state = f.id == store.state.activeID ? .on : .off
            item.target = self
            menu.addItem(item)
        }
        if !store.focuses.isEmpty { menu.addItem(.separator()) }
        menu.addItem(withTitle: L.t("Pause"), action: #selector(pause), keyEquivalent: "").target = self

        let undo = NSMenuItem(
            title: store.undoLabel.map { L.t("Undo: %@", $0) } ?? L.t("Undo"),
            action: #selector(undoAction), keyEquivalent: "z")
        undo.target = self
        undo.isEnabled = store.undoLabel != nil
        menu.addItem(undo)
        menu.addItem(.separator())
        let toggleTitle = settings.toggleShortcut.map { L.t("Show/hide window (%@)", $0.display) } ?? L.t("Show/hide window")
        menu.addItem(withTitle: toggleTitle, action: #selector(togglePanel), keyEquivalent: "").target = self
        menu.addItem(withTitle: L.t("Log …"), action: #selector(showLog), keyEquivalent: "l").target = self

        let login = NSMenuItem(title: L.t("Launch at login"), action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(withTitle: L.t("Settings …"), action: #selector(showSettings), keyEquivalent: ",").target = self

        menu.addItem(.separator())
        menu.addItem(withTitle: L.t("Quit My Focus"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func switchFromMenu(_ sender: NSMenuItem) {
        store.switchTo(sender.representedObject as? UUID)
    }

    @objc private func pause() { store.pause() }

    @objc private func undoAction() { store.undo() }

    @objc private func showSettings() { settingsWindow.show() }

    @objc private func showLog() { logWindow.show() }

    @objc func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        panel.orderFrontRegardless()
        panel.makeKey()
        panel.touch()
    }

    // Shortcut: open the "new focus" field
    private func newFocus() {
        showPanel()
        commands.newFocusTick += 1
    }

    // Shortcut: edit the note on the active focus
    private func editActiveNote() {
        guard store.active != nil else { return }
        showPanel()
        commands.noteTick += 1
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("MyFocus: login item change failed: \(error)")
        }
        rebuildMenu()
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    // Menu bar app: no Dock icon, no Cmd+Tab entry
    app.setActivationPolicy(.accessory)
    app.run()
}
