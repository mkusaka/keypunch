import KeypunchKeyboardShortcuts

protocol ShortcutRegistering {
    func onKeyUp(for name: KeyboardShortcutsClient.Name, action: @escaping () -> Void)
    func removeHandler(for name: KeyboardShortcutsClient.Name)
    func disable(_ name: KeyboardShortcutsClient.Name)
    func reset(_ name: KeyboardShortcutsClient.Name)
    func getShortcut(for name: KeyboardShortcutsClient.Name) -> KeyboardShortcutsClient.Shortcut?
}

struct KeyboardShortcutsRegistrar: ShortcutRegistering {
    func onKeyUp(for name: KeyboardShortcutsClient.Name, action: @escaping () -> Void) {
        KeyboardShortcutsClient.onKeyUp(for: name, action: action)
    }

    func removeHandler(for name: KeyboardShortcutsClient.Name) {
        KeyboardShortcutsClient.removeHandler(for: name)
    }

    func disable(_ name: KeyboardShortcutsClient.Name) {
        KeyboardShortcutsClient.disable(name)
    }

    func reset(_ name: KeyboardShortcutsClient.Name) {
        KeyboardShortcutsClient.reset(name)
    }

    func getShortcut(for name: KeyboardShortcutsClient.Name) -> KeyboardShortcutsClient.Shortcut? {
        KeyboardShortcutsClient.getShortcut(for: name)
    }
}
