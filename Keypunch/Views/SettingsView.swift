import SwiftUI
import UniformTypeIdentifiers
import KeyboardShortcuts

struct SettingsView: View {
    var store: ShortcutStore
    @State private var selectedShortcut: AppShortcut?
    @State private var showDuplicateAlert = false
    @State private var duplicateAppName = ""
    @State private var toggleConflictError: String?

    var body: some View {
        HSplitView {
            VStack {
                List(store.shortcuts, selection: $selectedShortcut) { shortcut in
                    let _ = store.shortcutKeysVersion
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

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Toggle Keypunch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    KeyboardShortcuts.Recorder(for: .toggleKeypunch) { newShortcut in
                        if let newShortcut, store.isShortcutConflicting(newShortcut, excluding: .toggleKeypunch) {
                            KeyboardShortcuts.reset(.toggleKeypunch)
                            toggleConflictError = "Already used by an app shortcut."
                        } else {
                            toggleConflictError = nil
                        }
                    }
                    if let toggleConflictError {
                        Text(toggleConflictError)
                            .foregroundStyle(.red)
                            .font(.caption2)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

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
                    ),
                    store: store
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

        switch store.addShortcutFromURL(url) {
        case .success(let shortcut):
            selectedShortcut = shortcut
        case .duplicate(let name):
            duplicateAppName = name
            showDuplicateAlert = true
        }
    }

    private func removeSelected() {
        guard let selected = selectedShortcut else { return }
        store.removeShortcut(selected)
        selectedShortcut = nil
    }
}
