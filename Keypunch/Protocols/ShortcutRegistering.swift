import KeyboardShortcuts

protocol ShortcutRegistering {
    func onKeyUp(for name: KeyboardShortcuts.Name, action: @escaping () -> Void)
    func reset(_ name: KeyboardShortcuts.Name)
    func getShortcut(for name: KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut?
}

struct KeyboardShortcutsRegistrar: ShortcutRegistering {
    func onKeyUp(for name: KeyboardShortcuts.Name, action: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: name, action: action)
    }

    func reset(_ name: KeyboardShortcuts.Name) {
        KeyboardShortcuts.reset(name)
    }

    func getShortcut(for name: KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.getShortcut(for: name)
    }
}
