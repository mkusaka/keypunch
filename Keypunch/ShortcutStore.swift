import Foundation
import KeyboardShortcuts
import AppKit

@MainActor
@Observable
final class ShortcutStore {
    private(set) var shortcuts: [AppShortcut] = []

    static let storageKey = "savedAppShortcuts"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadShortcuts()
        registerAllHandlers()
    }

    func addShortcut(_ shortcut: AppShortcut) {
        shortcuts.append(shortcut)
        registerHandler(for: shortcut)
        saveShortcuts()
    }

    func removeShortcut(_ shortcut: AppShortcut) {
        KeyboardShortcuts.reset(shortcut.keyboardShortcutName)
        shortcuts.removeAll { $0.id == shortcut.id }
        saveShortcuts()
    }

    func removeShortcuts(at offsets: IndexSet) {
        let toRemove = offsets.map { shortcuts[$0] }
        for shortcut in toRemove {
            KeyboardShortcuts.reset(shortcut.keyboardShortcutName)
        }
        shortcuts.remove(atOffsets: offsets)
        saveShortcuts()
    }

    func updateShortcut(_ shortcut: AppShortcut) {
        guard let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) else { return }
        let old = shortcuts[index]
        if old.shortcutName != shortcut.shortcutName {
            KeyboardShortcuts.reset(old.keyboardShortcutName)
        }
        shortcuts[index] = shortcut
        registerHandler(for: shortcut)
        saveShortcuts()
    }

    func containsApp(path: String) -> Bool {
        shortcuts.contains { $0.appPath == path }
    }

    func containsApp(bundleIdentifier: String) -> Bool {
        shortcuts.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    func launchApp(for shortcut: AppShortcut) {
        let url: URL
        if let bundleID = shortcut.bundleIdentifier,
           let resolved = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            url = resolved
        } else {
            url = shortcut.appURL
        }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                print("Failed to launch \(shortcut.name): \(error)")
            }
        }
    }

    private func registerHandler(for shortcut: AppShortcut) {
        KeyboardShortcuts.onKeyUp(for: shortcut.keyboardShortcutName) { [weak self] in
            self?.launchApp(for: shortcut)
        }
    }

    private func registerAllHandlers() {
        for shortcut in shortcuts {
            registerHandler(for: shortcut)
        }
    }

    private func saveShortcuts() {
        guard let data = try? JSONEncoder().encode(shortcuts) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private func loadShortcuts() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([AppShortcut].self, from: data) else {
            return
        }
        shortcuts = decoded
    }
}
