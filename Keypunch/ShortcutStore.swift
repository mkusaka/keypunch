import AppKit
import Foundation
import KeyboardShortcuts

@MainActor
@Observable
final class ShortcutStore {
    private(set) var shortcuts: [AppShortcut] = []
    private(set) var shortcutKeysVersion: Int = 0

    let launcher: AppLaunchService
    private let registration: ShortcutRegistrationService

    static let storageKey = "savedAppShortcuts"
    private let defaults: UserDefaults
    private var shortcutChangeObserver: NSObjectProtocol?

    init(
        defaults: UserDefaults = .standard,
        workspace: AppLaunching = NSWorkspace.shared,
        registrar: ShortcutRegistering = KeyboardShortcutsRegistrar(),
        mainBundle: BundleProviding = Bundle.main
    ) {
        self.defaults = defaults
        launcher = AppLaunchService(workspace: workspace, mainBundle: mainBundle)
        registration = ShortcutRegistrationService(registrar: registrar)
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

    // MARK: - Public API

    var onSelfActivate: (() -> Void)? {
        get { launcher.onSelfActivate }
        set { launcher.onSelfActivate = newValue }
    }

    func addShortcut(_ shortcut: AppShortcut) {
        shortcuts.append(shortcut)
        registerHandler(for: shortcut)
        saveShortcuts()
    }

    func removeShortcut(_ shortcut: AppShortcut) {
        registration.reset(for: shortcut)
        shortcuts.removeAll { $0.id == shortcut.id }
        saveShortcuts()
    }

    func removeShortcuts(at offsets: IndexSet) {
        let toRemove = offsets.map { shortcuts[$0] }
        for shortcut in toRemove {
            registration.reset(for: shortcut)
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
            registration.reset(name: old.keyboardShortcutName)
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
            registration.registerDisabled(for: shortcut)
        }
        saveShortcuts()
    }

    func unsetShortcut(for shortcut: AppShortcut) {
        registration.reset(for: shortcut)
        shortcutKeysVersion += 1
    }

    func containsApp(path: String) -> Bool {
        shortcuts.contains { $0.appPath == path }
    }

    func containsApp(bundleIdentifier: String) -> Bool {
        shortcuts.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    func isShortcutConflicting(
        _ shortcut: KeyboardShortcuts.Shortcut,
        excluding name: KeyboardShortcuts.Name
    ) -> Bool {
        for appShortcut in shortcuts {
            let ksName = appShortcut.keyboardShortcutName
            guard ksName != name else { continue }
            if let existing = registration.getShortcut(for: ksName),
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
        launcher.launch(for: shortcut)
    }

    // MARK: - Private

    private func registerHandler(for shortcut: AppShortcut) {
        registration.register(for: shortcut) { [weak self] in
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
