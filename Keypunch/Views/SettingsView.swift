import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var store: ShortcutStore
    @State private var selectedShortcut: AppShortcut?

    var body: some View {
        HSplitView {
            VStack {
                List(store.shortcuts, selection: $selectedShortcut) { shortcut in
                    Text(shortcut.name)
                        .tag(shortcut)
                }
                .frame(minWidth: 200)

                HStack {
                    Button(action: addShortcut) {
                        Image(systemName: "plus")
                    }

                    Button(action: removeSelected) {
                        Image(systemName: "minus")
                    }
                    .disabled(selectedShortcut == nil)

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }

            if let selected = selectedShortcut,
               store.shortcuts.contains(where: { $0.id == selected.id }) {
                ShortcutEditView(
                    shortcut: Binding(
                        get: {
                            store.shortcuts.first { $0.id == selected.id } ?? selected
                        },
                        set: { newValue in
                            store.updateShortcut(newValue)
                            selectedShortcut = newValue
                        }
                    )
                )
                .frame(minWidth: 300)
                .padding()
            } else {
                Text("Select a shortcut or add a new one")
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 550, minHeight: 300)
    }

    private func addShortcut() {
        let panel = NSOpenPanel()
        panel.title = "Choose an Application"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(filePath: "/Applications")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let appName = url.deletingPathExtension().lastPathComponent
        let bundle = Bundle(url: url)
        let bundleID = bundle?.bundleIdentifier

        let shortcut = AppShortcut(
            name: appName,
            bundleIdentifier: bundleID,
            appPath: url.path(percentEncoded: false)
        )

        store.addShortcut(shortcut)
        selectedShortcut = shortcut
    }

    private func removeSelected() {
        guard let selected = selectedShortcut else { return }
        store.removeShortcut(selected)
        selectedShortcut = nil
    }
}
