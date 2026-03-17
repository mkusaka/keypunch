import Foundation
import KeypunchKeyboardShortcuts

struct AppShortcut: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var bundleIdentifier: String?
    var appPath: String
    var shortcutName: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String?,
        appPath: String,
        shortcutName: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.appPath = appPath
        self.shortcutName = shortcutName ?? "appShortcut_\(id.uuidString)"
        self.isEnabled = isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        appPath = try container.decode(String.self, forKey: .appPath)
        shortcutName = try container.decode(String.self, forKey: .shortcutName)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }

    var keyboardShortcutName: KeyboardShortcutsClient.Name {
        KeyboardShortcutsClient.Name(shortcutName)
    }

    var appURL: URL {
        URL(filePath: appPath)
    }

    var appDirectory: String {
        URL(filePath: appPath).deletingLastPathComponent().path
    }
}
