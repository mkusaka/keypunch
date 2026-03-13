import SwiftUI
import UniformTypeIdentifiers
import KeyboardShortcuts

struct SettingsView: View {
    var store: ShortcutStore
    @State private var selectedShortcut: AppShortcut?
    @State private var showDuplicateAlert = false
    @State private var duplicateAppName = ""

    var body: some View {
        HSplitView {
            VStack {
                List(store.shortcuts, selection: $selectedShortcut) { shortcut in
                    HStack(spacing: 6) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: shortcut.appPath))
                            .resizable()
                            .frame(width: 18, height: 18)
                        Text(shortcut.name)
                        Spacer()
                        if let ks = KeyboardShortcuts.getShortcut(for: shortcut.keyboardShortcutName) {
                            Text(ks.description)
                                .foregroundStyle(.secondary)
                                .font(.callout)
                        }
                    }
                    .tag(shortcut)
                }

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
            .frame(width: 220)

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
        .alert("Duplicate Application", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(duplicateAppName) has already been added.")
        }
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
        let appPath = url.path(percentEncoded: false)
        let bundle = Bundle(url: url)
        let bundleID = bundle?.bundleIdentifier

        let isDuplicate = store.containsApp(path: appPath)
            || (bundleID != nil && store.containsApp(bundleIdentifier: bundleID!))

        if isDuplicate {
            duplicateAppName = appName
            showDuplicateAlert = true
            return
        }

        let shortcut = AppShortcut(
            name: appName,
            bundleIdentifier: bundleID,
            appPath: appPath
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
