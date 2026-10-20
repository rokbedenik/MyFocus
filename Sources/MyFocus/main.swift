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
    private var panel: FloatingPanel!
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = FloatingPanel { PanelView(store: store, settings: settings) }
        panel.placeTopRightIfNew()
        panel.orderFrontRegardless()

        setupStatusItem()
        observeLockAndSleep()

        // Ctrl+Opt+F toggles the panel
        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_F), modifiers: UInt32(controlKey | optionKey)) { [weak self] in
            Task { @MainActor in self?.togglePanel() }
        }

        store.$state.combineLatest(store.$now)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshStatusTitle() }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.flush()
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
        menu.addItem(withTitle: "Pavza", action: #selector(pause), keyEquivalent: "").target = self

        let undo = NSMenuItem(
            title: store.undoLabel.map { "Razveljavi: \($0)" } ?? "Razveljavi",
            action: #selector(undoAction), keyEquivalent: "z")
        undo.target = self
        undo.isEnabled = store.undoLabel != nil
        menu.addItem(undo)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Pokaži/skrij okno (⌃⌥F)", action: #selector(togglePanel), keyEquivalent: "").target = self

        let login = NSMenuItem(title: "Zaženi ob prijavi", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(withTitle: "Nastavitve …", action: #selector(showSettings), keyEquivalent: ",").target = self

        menu.addItem(.separator())
        menu.addItem(withTitle: "Zapri My Focus", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func switchFromMenu(_ sender: NSMenuItem) {
        store.switchTo(sender.representedObject as? UUID)
    }

    @objc private func pause() { store.pause() }

    @objc private func undoAction() { store.undo() }

    @objc private func showSettings() { settingsWindow.show() }

    @objc func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
            panel.makeKey()
        }
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
