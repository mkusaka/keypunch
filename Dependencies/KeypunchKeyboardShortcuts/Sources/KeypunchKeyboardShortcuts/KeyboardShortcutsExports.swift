import KeyboardShortcuts

public enum KeyboardShortcutsClient {
    public typealias Name = KeyboardShortcuts.Name
    public typealias Shortcut = KeyboardShortcuts.Shortcut

    public static func onKeyUp(for name: Name, action: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: name, action: action)
    }

    public static func reset(_ name: Name) {
        KeyboardShortcuts.reset(name)
    }

    public static func getShortcut(for name: Name) -> Shortcut? {
        KeyboardShortcuts.getShortcut(for: name)
    }

    public static func setShortcut(_ shortcut: Shortcut?, for name: Name) {
        KeyboardShortcuts.setShortcut(shortcut, for: name)
    }
}
