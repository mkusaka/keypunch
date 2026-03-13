import SwiftUI
import KeyboardShortcuts

struct MenuBarView: View {
    var store: ShortcutStore
    var showAllForTesting: Bool = false

    private var displayedShortcuts: [AppShortcut] {
        if showAllForTesting {
            return store.shortcuts
        }
        return store.shortcuts.filter { shortcut in
            KeyboardShortcuts.getShortcut(for: shortcut.keyboardShortcutName) != nil
        }
    }

    var body: some View {
        if displayedShortcuts.isEmpty {
            Button("No shortcuts configured") {}
                .disabled(true)
        } else {
            ForEach(displayedShortcuts) { shortcut in
                Button {
                    store.launchApp(for: shortcut)
                } label: {
                    Label {
                        HStack {
                            Text(shortcut.name)
                            Spacer()
                            if let ks = KeyboardShortcuts.getShortcut(for: shortcut.keyboardShortcutName) {
                                Text(ks.description)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: shortcut.appPath))
                    }
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
