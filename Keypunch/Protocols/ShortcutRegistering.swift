import KeypunchKeyboardShortcuts

protocol ShortcutRegistering {
    func onKeyUp(for name: KeyboardShortcutsClient.Name, action: @escaping () -> Void)
    func reset(_ name: KeyboardShortcutsClient.Name)
    func getShortcut(for name: KeyboardShortcutsClient.Name) -> KeyboardShortcutsClient.Shortcut?
}

struct KeyboardShortcutsRegistrar: ShortcutRegistering {
    func onKeyUp(for name: KeyboardShortcutsClient.Name, action: @escaping () -> Void) {
        KeyboardShortcutsClient.onKeyUp(for: name, action: action)
    }

    func reset(_ name: KeyboardShortcutsClient.Name) {
        KeyboardShortcutsClient.reset(name)
    }

    func getShortcut(for name: KeyboardShortcutsClient.Name) -> KeyboardShortcutsClient.Shortcut? {
        KeyboardShortcutsClient.getShortcut(for: name)
    }
}
