import SwiftUI

struct MenuBarView: View {
    var store: ShortcutStore

    var body: some View {
        if store.shortcuts.isEmpty {
            Text("No shortcuts configured")
                .foregroundStyle(.secondary)
        } else {
            ForEach(store.shortcuts) { shortcut in
                Button(shortcut.name) {
                    store.launchApp(for: shortcut)
                }
            }
        }

        Divider()

        SettingsLink {
            Text("Settings...")
        }
        .keyboardShortcut(",")

        Button("Quit Keypunch") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
