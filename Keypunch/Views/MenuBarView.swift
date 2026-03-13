import SwiftUI

struct MenuBarView: View {
    var store: ShortcutStore

    var body: some View {
        if store.shortcuts.isEmpty {
            Button("No shortcuts configured") {}
                .disabled(true)
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
