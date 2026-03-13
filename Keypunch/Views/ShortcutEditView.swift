import SwiftUI
import KeyboardShortcuts

struct ShortcutEditView: View {
    @Binding var shortcut: AppShortcut
    var store: ShortcutStore
    @State private var conflictError: String?

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

            KeyboardShortcuts.Recorder("Shortcut:", name: shortcut.keyboardShortcutName) { newShortcut in
                if let newShortcut, store.isShortcutConflicting(newShortcut, excluding: shortcut.keyboardShortcutName) {
                    KeyboardShortcuts.reset(shortcut.keyboardShortcutName)
                    conflictError = "Already used by another shortcut."
                } else {
                    conflictError = nil
                }
            }
            if let conflictError {
                Text(conflictError)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
    }
}
