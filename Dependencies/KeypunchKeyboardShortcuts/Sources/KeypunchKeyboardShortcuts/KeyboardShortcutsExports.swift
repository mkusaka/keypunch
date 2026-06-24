import KeyboardShortcuts

public enum KeyboardShortcutsClient {
    public typealias Name = KeyboardShortcuts.Name
    public typealias Shortcut = KeyboardShortcuts.Shortcut

    @MainActor
    public static func onKeyUp(for name: Name, action: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: name, action: action)
    }

    @MainActor
    public static func removeHandler(for name: Name) {
        KeyboardShortcuts.removeHandler(for: name)
    }

    @MainActor
    public static func disable(_ name: Name) {
        KeyboardShortcuts.disable(name)
    }

    @MainActor
    public static func reset(_ name: Name) {
        KeyboardShortcuts.reset(name)
    }

    @MainActor
    public static func getShortcut(for name: Name) -> Shortcut? {
        KeyboardShortcuts.getShortcut(for: name)
    }

    @MainActor
    public static func setShortcut(_ shortcut: Shortcut?, for name: Name) {
        KeyboardShortcuts.setShortcut(shortcut, for: name)
    }
}
