import AppKit
import KeypunchKeyboardShortcuts

@MainActor
final class FloatingWidgetController: NSObject {
    private let store: ShortcutStore
    private let loginItem: LoginItemService
    private let settingsWindowCoordinator: SettingsWindowCoordinator
    private var statusItem: NSStatusItem?

    init(
        store: ShortcutStore,
        settingsWindowCoordinator: SettingsWindowCoordinator,
        loginItem: LoginItemService? = nil
    ) {
        self.store = store
        self.settingsWindowCoordinator = settingsWindowCoordinator
        self.loginItem = loginItem ?? LoginItemService()
        super.init()
    }

    func setup() {
        setupStatusBar()

        store.onSelfActivate = { [weak self] in
            self?.showSettingsWindow()
        }
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keypunch")
        }

        let menu = NSMenu()
        menu.delegate = self

        let showItem = NSMenuItem(title: "Show Keypunch", action: #selector(statusBarShowWindow), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(.separator())

        let loginItem = NSMenuItem(
            title: "Start at Login",
            action: #selector(statusBarToggleLoginItem),
            keyEquivalent: ""
        )
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(statusBarQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        self.statusItem = statusItem
    }

    @objc private func statusBarShowWindow() {
        showSettingsWindow()
    }

    @objc private func statusBarToggleLoginItem() {
        loginItem.toggle()
    }

    @objc private func statusBarQuit() {
        NSApplication.shared.terminate(nil)
    }

    func showSettingsWindow() {
        settingsWindowCoordinator.showSettingsWindow()
    }
}

// MARK: - NSMenuDelegate

extension FloatingWidgetController: NSMenuDelegate {
    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        MainActor.assumeIsolated {
            for item in menu.items where item.action == #selector(statusBarToggleLoginItem) {
                item.state = loginItem.isEnabled ? .on : .off
            }
        }
    }
}
