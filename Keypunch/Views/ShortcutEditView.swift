import SwiftUI
import KeyboardShortcuts

struct ShortcutEditView: View {
    @Binding var shortcut: AppShortcut

    var body: some View {
        Form {
            TextField("Name:", text: $shortcut.name)

            LabeledContent("Application:") {
                Text(shortcut.appPath)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if let bundleID = shortcut.bundleIdentifier {
                LabeledContent("Bundle ID:") {
                    Text(bundleID)
                        .foregroundStyle(.secondary)
                }
            }

            KeyboardShortcuts.Recorder("Shortcut:", name: shortcut.keyboardShortcutName)
        }
        .formStyle(.grouped)
    }
}
