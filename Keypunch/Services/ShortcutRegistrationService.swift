import KeypunchKeyboardShortcuts

@MainActor
final class ShortcutRegistrationService {
    private let registrar: ShortcutRegistering

    init(registrar: ShortcutRegistering = KeyboardShortcutsRegistrar()) {
        self.registrar = registrar
    }

    func register(for shortcut: AppShortcut, action: @escaping () -> Void) {
        registrar.removeHandler(for: shortcut.keyboardShortcutName)
        guard shortcut.isEnabled else {
            registrar.disable(shortcut.keyboardShortcutName)
            return
        }
        registrar.onKeyUp(for: shortcut.keyboardShortcutName, action: action)
    }

    func registerDisabled(for shortcut: AppShortcut) {
        registrar.removeHandler(for: shortcut.keyboardShortcutName)
        registrar.disable(shortcut.keyboardShortcutName)
    }

    func reset(for shortcut: AppShortcut) {
        registrar.removeHandler(for: shortcut.keyboardShortcutName)
        registrar.reset(shortcut.keyboardShortcutName)
    }

    func reset(name: KeyboardShortcutsClient.Name) {
        registrar.removeHandler(for: name)
        registrar.reset(name)
    }

    func getShortcut(for name: KeyboardShortcutsClient.Name) -> KeyboardShortcutsClient.Shortcut? {
        registrar.getShortcut(for: name)
    }
}
