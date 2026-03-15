import AppKit
import KeyboardShortcuts
import SwiftUI

@MainActor
final class FloatingWidgetController: NSObject {
    private var settingsWindow: NSWindow?
    private let store: ShortcutStore
    private let loginItem: LoginItemService
    private let isTestMode: Bool
    private var statusItem: NSStatusItem?

    init(store: ShortcutStore, isTestMode: Bool, loginItem: LoginItemService? = nil) {
        self.store = store
        self.loginItem = loginItem ?? LoginItemService()
        self.isTestMode = isTestMode
        super.init()
    }

    func setup() {
        setupStatusBar()
        setupSettingsWindow()

        store.onSelfActivate = { [weak self] in
            self?.showSettingsWindow()
        }

        if isTestMode {
            showSettingsWindow()
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

    // MARK: - Settings Window

    private func setupSettingsWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 616),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Keypunch"
        window.isReleasedWhenClosed = false
        window.center()
        window.setAccessibilityIdentifier("keypunch-panel")

        let hostingView = NSHostingView(
            rootView: SettingsPanelView(
                store: store,
                showAllForTesting: isTestMode
            )
        )
        window.contentView = hostingView

        settingsWindow = window
    }

    func showSettingsWindow() {
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
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
