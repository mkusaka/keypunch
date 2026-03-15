import AppKit
import Foundation
import KeyboardShortcuts

@MainActor
@Observable
final class ShortcutStore {
    private(set) var shortcuts: [AppShortcut] = []
    private(set) var shortcutKeysVersion: Int = 0

    /// Called instead of launching when the shortcut targets Keypunch itself.
    var onSelfActivate: (() -> Void)?

    static let storageKey = "savedAppShortcuts"
    private let defaults: UserDefaults
    private let workspace: AppLaunching
    private let registrar: ShortcutRegistering
    private let mainBundle: BundleProviding
    private var shortcutChangeObserver: NSObjectProtocol?

    init(
        defaults: UserDefaults = .standard,
        workspace: AppLaunching = NSWorkspace.shared,
        registrar: ShortcutRegistering = KeyboardShortcutsRegistrar(),
        mainBundle: BundleProviding = Bundle.main
    ) {
        self.defaults = defaults
        self.workspace = workspace
        self.registrar = registrar
        self.mainBundle = mainBundle
        loadShortcuts()
        registerAllHandlers()
        shortcutChangeObserver = NotificationCenter.default.addObserver(
            forName: .init("KeyboardShortcuts_shortcutByNameDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.shortcutKeysVersion += 1
            }
        }
    }

    func addShortcut(_ shortcut: AppShortcut) {
        shortcuts.append(shortcut)
        registerHandler(for: shortcut)
        saveShortcuts()
    }

    func removeShortcut(_ shortcut: AppShortcut) {
        registrar.reset(shortcut.keyboardShortcutName)
        shortcuts.removeAll { $0.id == shortcut.id }
        saveShortcuts()
    }

    func removeShortcuts(at offsets: IndexSet) {
        let toRemove = offsets.map { shortcuts[$0] }
        for shortcut in toRemove {
            registrar.reset(shortcut.keyboardShortcutName)
        }
        shortcuts.remove(atOffsets: offsets)
        saveShortcuts()
    }

    func moveShortcuts(from source: IndexSet, to destination: Int) {
        shortcuts.move(fromOffsets: source, toOffset: destination)
        saveShortcuts()
    }

    func updateShortcut(_ shortcut: AppShortcut) {
        guard let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) else { return }
        let old = shortcuts[index]
        if old.shortcutName != shortcut.shortcutName {
            registrar.reset(old.keyboardShortcutName)
        }
        shortcuts[index] = shortcut
        registerHandler(for: shortcut)
        saveShortcuts()
    }

    func toggleEnabled(for shortcut: AppShortcut) {
        guard let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) else { return }
        shortcuts[index].isEnabled.toggle()
        if shortcuts[index].isEnabled {
            registerHandler(for: shortcuts[index])
        } else {
            registrar.onKeyUp(for: shortcut.keyboardShortcutName) {}
        }
        saveShortcuts()
    }

    func unsetShortcut(for shortcut: AppShortcut) {
        registrar.reset(shortcut.keyboardShortcutName)
        shortcutKeysVersion += 1
    }

    func containsApp(path: String) -> Bool {
        shortcuts.contains { $0.appPath == path }
    }

    func containsApp(bundleIdentifier: String) -> Bool {
        shortcuts.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    func isShortcutConflicting(_ shortcut: KeyboardShortcuts.Shortcut, excluding name: KeyboardShortcuts.Name) -> Bool {
        for appShortcut in shortcuts {
            let ksName = appShortcut.keyboardShortcutName
            guard ksName != name else { continue }
            if let existing = registrar.getShortcut(for: ksName),
               existing == shortcut
            {
                return true
            }
        }
        return false
    }

    enum AddAppResult {
        case success(AppShortcut)
        case duplicate(String)
    }

    func addShortcutFromURL(_ url: URL) -> AddAppResult {
        let appName = url.deletingPathExtension().lastPathComponent
        let appPath = url.path(percentEncoded: false)
        let bundle = Bundle(url: url)
        let bundleID = bundle?.bundleIdentifier

        if containsApp(path: appPath) || (bundleID.map { containsApp(bundleIdentifier: $0) } ?? false) {
            return .duplicate(appName)
        }

        let shortcut = AppShortcut(name: appName, bundleIdentifier: bundleID, appPath: appPath)
        addShortcut(shortcut)
        return .success(shortcut)
    }

    func launchApp(for shortcut: AppShortcut) {
        // If the shortcut targets Keypunch itself, activate keyboard mode instead of launching
        if let bundleID = shortcut.bundleIdentifier,
           bundleID == mainBundle.bundleIdentifier
        {
            onSelfActivate?()
            return
        }

        let url: URL = if let bundleID = shortcut.bundleIdentifier,
                          let resolved = workspace.urlForApplication(withBundleIdentifier: bundleID)
        {
            resolved
        } else {
            shortcut.appURL
        }

        let configuration = NSWorkspace.OpenConfiguration()
        Task {
            do {
                try await workspace.openApplication(at: url, configuration: configuration)
            } catch {
                print("Failed to launch \(shortcut.name): \(error)")
            }
        }
    }

    private func registerHandler(for shortcut: AppShortcut) {
        guard shortcut.isEnabled else {
            registrar.onKeyUp(for: shortcut.keyboardShortcutName) {}
            return
        }
        registrar.onKeyUp(for: shortcut.keyboardShortcutName) { [weak self] in
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
              let decoded = try? JSONDecoder().decode([AppShortcut].self, from: data)
        else {
            return
        }
        shortcuts = decoded
    }
}
