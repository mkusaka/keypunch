import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers

struct FloatingPanelView: View {
    var store: ShortcutStore
    var showAllForTesting: Bool = false
    @State private var hoveredShortcut: AppShortcut?
    @State private var showDuplicateAlert = false
    @State private var duplicateAppName = ""

    private var displayedShortcuts: [AppShortcut] {
        _ = store.shortcutKeysVersion
        if showAllForTesting {
            return store.shortcuts
        }
        return store.shortcuts.filter { shortcut in
            KeyboardShortcuts.getShortcut(for: shortcut.keyboardShortcutName) != nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Keypunch")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .tracking(-0.3)
                Spacer()
                Button {
                    FloatingWidgetController.openSettings()
                } label: {
                    Image(systemName: "gear")
                        .foregroundStyle(Color(white: 0.42))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings-button")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Divider
            Rectangle()
                .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                .frame(height: 1)

            // List
            ScrollView {
                VStack(spacing: 2) {
                    if displayedShortcuts.isEmpty {
                        Text("No shortcuts configured")
                            .foregroundStyle(Color(white: 0.42))
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 16)
                    }

                    ForEach(displayedShortcuts) { shortcut in
                        ShortcutRow(shortcut: shortcut, isHovered: hoveredShortcut?.id == shortcut.id)
                            .onHover { isHovered in
                                hoveredShortcut = isHovered ? shortcut : nil
                            }
                            .onTapGesture {
                                store.launchApp(for: shortcut)
                            }
                    }

                    // Add App button
                    Button(action: addShortcut) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12))
                            Text("Add App")
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(Color(white: 0.42))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
            }

            // Footer: Quit button
            Rectangle()
                .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                .frame(height: 1)

            HStack {
                Spacer()
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("Quit Keypunch")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.42))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .frame(width: 300, height: 290)
        .background(Color(red: 0.086, green: 0.086, blue: 0.10)) // #16161A
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 40, y: 8)
        .shadow(color: Color(red: 0.39, green: 0.40, blue: 0.95).opacity(0.08), radius: 80)
        .alert("Duplicate Application", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(duplicateAppName) has already been added.")
        }
    }

    private func addShortcut() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.title = "Choose an Application"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(filePath: "/Applications")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        switch store.addShortcutFromURL(url) {
        case .success:
            break
        case .duplicate(let name):
            duplicateAppName = name
            showDuplicateAlert = true
        }
    }
}

private struct ShortcutRow: View {
    let shortcut: AppShortcut
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: shortcut.appPath))
                .resizable()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityLabel("\(shortcut.name) icon")

            Text(shortcut.name)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            if let ks = KeyboardShortcuts.getShortcut(for: shortcut.keyboardShortcutName) {
                Text(ks.description)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(red: 0.04, green: 0.52, blue: 1.0)) // #0A84FF
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.19)) // #0A84FF30
                    )
            } else {
                Text("Not set")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.31)) // #4A4A50
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.13) : .clear)
        )
        .contentShape(Rectangle())
    }
}
