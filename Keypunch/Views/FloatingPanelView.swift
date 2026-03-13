import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers

enum PanelTab: Equatable {
    case launch
    case edit
}

struct FloatingPanelView: View {
    var store: ShortcutStore
    var showAllForTesting: Bool = false

    @State private var activeTab: PanelTab = .launch
    @State private var hoveredShortcut: AppShortcut?
    @State private var shortcutToDelete: AppShortcut?
    @State private var showDuplicateAlert = false
    @State private var duplicateAppName = ""

    private var displayedShortcuts: [AppShortcut] {
        _ = store.shortcutKeysVersion
        return store.shortcuts
    }

    var body: some View {
        mainPanel
            .overlay {
                if shortcutToDelete != nil {
                    deleteConfirmationOverlay
                }
            }
            .alert("Duplicate Application", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(duplicateAppName) has already been added.")
        }
    }

    // MARK: - Main Panel

    private var mainPanel: some View {
        VStack(spacing: 0) {
            panelHeader
            dividerLine

            if activeTab == .launch {
                launchContent
            } else {
                editContent
            }
        }
        .frame(width: 340, height: 380)
        .background(Color(red: 0.086, green: 0.086, blue: 0.10)) // #16161A
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 40, y: 8)
        .shadow(color: Color(red: 0.39, green: 0.40, blue: 0.95).opacity(0.08), radius: 80)
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack(spacing: 0) {
            Text("Keypunch")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .tracking(-0.3)

            Spacer()

            HStack(spacing: 4) {
                tabButton("Launch", tab: .launch)
                tabButton("Edit", tab: .edit)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private func tabButton(_ title: String, tab: PanelTab) -> some View {
        let isSelected = activeTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                activeTab = tab
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .white : Color(red: 0.29, green: 0.29, blue: 0.31))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    isSelected
                        ? RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.07))
                        : nil
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared

    private var dividerLine: some View {
        Rectangle()
            .fill(Color(red: 0.16, green: 0.16, blue: 0.18)) // #2A2A2E
            .frame(height: 1)
    }

    // MARK: - Launch Mode

    private var launchContent: some View {
        ScrollView {
            VStack(spacing: 6) {
                if displayedShortcuts.isEmpty {
                    Text("No shortcuts configured")
                        .foregroundStyle(Color(white: 0.42))
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                }

                ForEach(displayedShortcuts) { shortcut in
                    LaunchRow(
                        shortcut: shortcut,
                        isHovered: hoveredShortcut?.id == shortcut.id
                    )
                    .onHover { isHovered in
                        hoveredShortcut = isHovered ? shortcut : nil
                    }
                    .onTapGesture {
                        store.launchApp(for: shortcut)
                    }
                }
            }
            .padding(8)
        }
    }

    // MARK: - Edit Mode

    private var editContent: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(store.shortcuts) { shortcut in
                    EditCard(
                        shortcut: shortcut,
                        store: store,
                        onDelete: {
                            shortcutToDelete = shortcut
                        }
                    )
                }

                addAppButton
            }
            .padding(8)
        }
    }

    private var addAppButton: some View {
        Button(action: addShortcut) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14))
                Text("Add App")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Color(white: 0.42)) // #6B6B70
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(red: 0.16, green: 0.16, blue: 0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Delete Confirmation

    private var deleteConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            if let shortcut = shortcutToDelete {
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(red: 0.91, green: 0.35, blue: 0.31).opacity(0.08))
                            .frame(width: 48, height: 48)
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(red: 0.91, green: 0.35, blue: 0.31))
                    }

                    Text("Remove \(shortcut.name)?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .tracking(-0.3)

                    Text("This will remove the shortcut and\nits key binding. This can't be undone.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(white: 0.42))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(width: 260)

                    HStack(spacing: 8) {
                        Button {
                            shortcutToDelete = nil
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.03))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.removeShortcut(shortcut)
                            shortcutToDelete = nil
                        } label: {
                            Text("Remove")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(red: 0.91, green: 0.35, blue: 0.31))
                                )
                                .shadow(color: Color(red: 0.91, green: 0.35, blue: 0.31).opacity(0.25), radius: 12, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.12, green: 0.12, blue: 0.13))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.56), radius: 48, y: 16)
                .padding(24)
            }
        }
    }

    // MARK: - Actions

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

// MARK: - Launch Row

private struct LaunchRow: View {
    let shortcut: AppShortcut
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: shortcut.appPath))
                .resizable()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .accessibilityLabel("\(shortcut.name) icon")

            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.name)
                    .font(.system(size: 13, weight: isHovered ? .semibold : .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(shortcut.appDirectory)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.31))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            shortcutBadge
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isHovered
                    ? Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.06)
                    : Color(red: 0.10, green: 0.10, blue: 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isHovered
                    ? Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.3)
                    : Color.white.opacity(0.06), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var shortcutBadge: some View {
        if let ks = KeyboardShortcuts.getShortcut(for: shortcut.keyboardShortcutName) {
            if shortcut.isEnabled {
                // Set & Active
                Text(ks.description)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.04, green: 0.52, blue: 1.0))
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.19))
                    )
            } else {
                // Disabled
                Text(ks.description)
                    .font(.system(size: 11, weight: .medium))
                    .strikethrough()
                    .foregroundStyle(Color(white: 0.42))
                    .padding(.horizontal, 8)
                    .frame(height: 22)
            }
        } else {
            // Not set
            Text("Not set")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.31))
        }
    }
}

// MARK: - Edit Card

private struct EditCard: View {
    let shortcut: AppShortcut
    let store: ShortcutStore
    let onDelete: () -> Void
    @State private var conflictError: String?
    @State private var isRecording = false

    private static let blueColor = Color(red: 0.04, green: 0.52, blue: 1.0)    // #0A84FF
    private static let amberColor = Color(red: 1.0, green: 0.71, blue: 0.28)   // #FFB547
    private static let grayColor = Color(white: 0.42)                           // #6B6B70

    private var hasShortcut: Bool {
        KeyboardShortcuts.getShortcut(for: shortcut.keyboardShortcutName) != nil
    }

    var body: some View {
        HStack(spacing: 10) {
            // App icon
            Image(nsImage: NSWorkspace.shared.icon(forFile: shortcut.appPath))
                .resizable()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .accessibilityLabel("\(shortcut.name) icon")

            // Name + path
            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(shortcut.appDirectory)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.31))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Enable/disable toggle
            if hasShortcut {
                Button {
                    store.toggleEnabled(for: shortcut)
                } label: {
                    Image(systemName: shortcut.isEnabled ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(shortcut.isEnabled
                            ? Color(red: 0.20, green: 0.84, blue: 0.51)
                            : Color(white: 0.42))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(shortcut.isEnabled ? "Disable shortcut" : "Enable shortcut")
                .accessibilityIdentifier("toggle-enabled")
            }

            // Shortcut badge area
            shortcutBadgeArea

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.91, green: 0.35, blue: 0.31))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.91, green: 0.35, blue: 0.31).opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Shortcut Badge Area

    @ViewBuilder
    private var shortcutBadgeArea: some View {
        if isRecording {
            // Recording state: amber badge with RecorderCocoa behind
            ZStack {
                AutoFocusRecorder(
                    name: shortcut.keyboardShortcutName,
                    onChange: { newShortcut in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isRecording = false
                        }
                        if let newShortcut, store.isShortcutConflicting(newShortcut, excluding: shortcut.keyboardShortcutName) {
                            KeyboardShortcuts.reset(shortcut.keyboardShortcutName)
                            conflictError = "Conflict"
                        } else {
                            conflictError = nil
                        }
                    },
                    onRecordingEnd: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isRecording = false
                        }
                    }
                )
                .frame(width: 80, height: 28)
                .opacity(0.01)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Self.amberColor)
                        .frame(width: 6, height: 6)
                    Text("Record")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Self.amberColor)
                }
                .allowsHitTesting(false)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Self.amberColor.opacity(0.125))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Self.amberColor.opacity(0.25), lineWidth: 1)
            )
        } else if let ks = KeyboardShortcuts.getShortcut(for: shortcut.keyboardShortcutName) {
            // Shortcut set: blue (enabled) or gray (disabled) badge
            let badgeColor = shortcut.isEnabled ? Self.blueColor : Self.grayColor
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isRecording = true
                }
            } label: {
                HStack(spacing: 5) {
                    Text(ks.description)
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "pencil.line")
                        .font(.system(size: 10))
                }
                .foregroundStyle(badgeColor)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(shortcut.isEnabled
                            ? Self.blueColor.opacity(0.125)
                            : Color.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(shortcut.isEnabled
                            ? Self.blueColor.opacity(0.25)
                            : Color.white.opacity(0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        } else {
            // No shortcut: amber "Record" button
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isRecording = true
                }
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Self.amberColor)
                        .frame(width: 6, height: 6)
                    Text("Record")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Self.amberColor)
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Self.amberColor.opacity(0.125))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Self.amberColor.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Auto Focus Recorder

private struct AutoFocusRecorder: NSViewRepresentable {
    let name: KeyboardShortcuts.Name
    let onChange: (KeyboardShortcuts.Shortcut?) -> Void
    let onRecordingEnd: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> KeyboardShortcuts.RecorderCocoa {
        let recorder = KeyboardShortcuts.RecorderCocoa(for: name, onChange: onChange)

        // Style to be visually minimal (prevents ViewBridge disconnect at small sizes)
        recorder.isBezeled = false
        recorder.isBordered = false
        recorder.drawsBackground = false
        recorder.focusRingType = .none

        // Auto-focus to start recording immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let window = recorder.window else { return }
            // Temporarily enable key ability for the panel so RecorderCocoa can become first responder
            if let keyable = window as? KeyablePanel {
                keyable.allowBecomeKey = true
            }
            window.makeKey()
            window.makeFirstResponder(recorder)
        }

        // Observe recording end (field lost focus / editing ended)
        context.coordinator.observation = NotificationCenter.default.addObserver(
            forName: NSControl.textDidEndEditingNotification,
            object: recorder,
            queue: .main
        ) { [weak recorder] _ in
            // Restore panel to non-key-capable state
            if let keyable = recorder?.window as? KeyablePanel {
                keyable.allowBecomeKey = false
            }
            onRecordingEnd()
        }

        return recorder
    }

    func updateNSView(_ nsView: KeyboardShortcuts.RecorderCocoa, context: Context) {}

    class Coordinator {
        var observation: NSObjectProtocol?
        deinit {
            if let observation { NotificationCenter.default.removeObserver(observation) }
        }
    }
}
