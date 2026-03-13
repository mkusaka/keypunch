import Foundation
import KeyboardShortcuts

struct AppShortcut: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var bundleIdentifier: String?
    var appPath: String
    var shortcutName: String

    init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String?,
        appPath: String,
        shortcutName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.appPath = appPath
        self.shortcutName = shortcutName ?? "appShortcut_\(id.uuidString)"
    }

    var keyboardShortcutName: KeyboardShortcuts.Name {
        KeyboardShortcuts.Name(shortcutName)
    }

    var appURL: URL {
        URL(filePath: appPath)
    }

    var appDirectory: String {
        URL(filePath: appPath).deletingLastPathComponent().path
    }
}
