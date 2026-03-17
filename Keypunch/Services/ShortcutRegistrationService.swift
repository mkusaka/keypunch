import KeypunchKeyboardShortcuts

@MainActor
final class ShortcutRegistrationService {
    private let registrar: ShortcutRegistering

    init(registrar: ShortcutRegistering = KeyboardShortcutsRegistrar()) {
        self.registrar = registrar
    }

    func register(for shortcut: AppShortcut, action: @escaping () -> Void) {
        guard shortcut.isEnabled else {
            registrar.onKeyUp(for: shortcut.keyboardShortcutName) {}
            return
        }
        registrar.onKeyUp(for: shortcut.keyboardShortcutName, action: action)
    }

    func registerDisabled(for shortcut: AppShortcut) {
        registrar.onKeyUp(for: shortcut.keyboardShortcutName) {}
    }

    func reset(for shortcut: AppShortcut) {
        registrar.reset(shortcut.keyboardShortcutName)
    }

    func reset(name: KeyboardShortcutsClient.Name) {
        registrar.reset(name)
    }

    func getShortcut(for name: KeyboardShortcutsClient.Name) -> KeyboardShortcutsClient.Shortcut? {
        registrar.getShortcut(for: name)
    }
}
