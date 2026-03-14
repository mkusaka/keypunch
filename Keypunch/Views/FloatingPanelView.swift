import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers

struct SettingsPanelView: View {
    var store: ShortcutStore
    var showAllForTesting: Bool = false

    @State private var editingShortcutID: UUID?
    @State private var hoveredShortcut: AppShortcut?
    @State private var shortcutToDelete: AppShortcut?
    @State private var showDuplicateAlert = false
    @State private var duplicateAppName = ""
    @FocusState private var focusedRowID: UUID?

    private var displayedShortcuts: [AppShortcut] {
        _ = store.shortcutKeysVersion
        return store.shortcuts
    }

    var body: some View {
        panelContent
            .overlay {
                if shortcutToDelete != nil {
                    deleteConfirmationOverlay
                }
            }
            .onExitCommand {
                if shortcutToDelete != nil {
                    shortcutToDelete = nil
                } else if editingShortcutID != nil {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        editingShortcutID = nil
                    }
                }
            }
            .alert("Duplicate Application", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(duplicateAppName) has already been added.")
        }
    }

    // MARK: - Content

    private var panelContent: some View {
        ScrollView {
            VStack(spacing: 6) {
                if displayedShortcuts.isEmpty {
                    Text("No shortcuts configured")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                }

                ForEach(displayedShortcuts) { shortcut in
                    if editingShortcutID == shortcut.id {
                        EditCard(
                            shortcut: shortcut,
                            store: store,
                            onDelete: {
                                editingShortcutID = nil
                                shortcutToDelete = shortcut
                            },
                            onCancelEdit: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    editingShortcutID = nil
                                }
                            }
                        )
                        .id("\(shortcut.id)-edit-\(store.shortcutKeysVersion)")
                        .transition(.opacity)
                    } else {
                        LaunchRow(
                            shortcut: shortcut,
                            isHovered: hoveredShortcut?.id == shortcut.id,
                            isFocused: focusedRowID == shortcut.id,
                            onEdit: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    editingShortcutID = shortcut.id
                                }
                            }
                        )
                        .id("\(shortcut.id)-launch-\(store.shortcutKeysVersion)")
                        .focusable()
                        .focused($focusedRowID, equals: shortcut.id)
                        .onKeyPress(.return) {
                            store.launchApp(for: shortcut)
                            return .handled
                        }
                        .onHover { isHovered in
                            hoveredShortcut = isHovered ? shortcut : nil
                        }
                        .onTapGesture {
                            store.launchApp(for: shortcut)
                        }
                    }
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
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityIdentifier("add-app-button")
    }

    // MARK: - Delete Confirmation

    private var deleteConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)

            if let shortcut = shortcutToDelete {
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.red.opacity(0.08))
                            .frame(width: 48, height: 48)
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                            .foregroundStyle(.red)
                    }

                    Text("Remove \(shortcut.name)?")
                        .font(.system(size: 16, weight: .semibold))

                    Text("This will remove the shortcut and\nits key binding. This can't be undone.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(width: 240)

                    HStack(spacing: 8) {
                        Button {
                            shortcutToDelete = nil
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            store.removeShortcut(shortcut)
                            shortcutToDelete = nil
                        } label: {
                            Text("Remove")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                )
                .padding(24)
            }
        }
    }

    // MARK: - Actions

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
        case .success:
            break
        case .duplicate(let name):
            duplicateAppName = name
            showDuplicateAlert = true
        }
    }
}

// MARK: - Launch Row (compact mode)

private struct LaunchRow: View {
    let shortcut: AppShortcut
    let isHovered: Bool
    var isFocused: Bool = false
    var onEdit: (() -> Void)?

    private var isHighlighted: Bool { isHovered || isFocused }

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: shortcut.appPath))
                .resizable()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .accessibilityLabel("\(shortcut.name) icon")

            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.name)
                    .font(.system(size: 13, weight: isHighlighted ? .semibold : .medium))
                    .lineLimit(1)
                Text(shortcut.appDirectory)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            shortcutBadge

            Button {
                onEdit?()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundStyle(isHighlighted ? .secondary : .quaternary)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.quaternary.opacity(0.3))
                    )
            }
            .buttonStyle(.plain)
            .focusable(false)
            .accessibilityIdentifier("edit-shortcut")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHighlighted ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHighlighted ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var shortcutBadge: some View {
        if let ks = KeyboardShortcuts.getShortcut(for: shortcut.keyboardShortcutName) {
            if shortcut.isEnabled {
                Text(ks.description)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.accentColor.opacity(0.15))
                    )
            } else {
                Text(ks.description)
                    .font(.system(size: 11, weight: .medium))
                    .strikethrough()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .frame(height: 20)
            }
        } else {
            Text("Not set")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Edit Card (expanded edit mode)

private struct EditCard: View {
    let shortcut: AppShortcut
    let store: ShortcutStore
    let onDelete: () -> Void
    let onCancelEdit: () -> Void
    @State private var conflictError: String?
    @State private var isRecording = false

    private var currentShortcut: KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.getShortcut(for: shortcut.keyboardShortcutName)
    }

    private var hasShortcut: Bool {
        currentShortcut != nil
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: shortcut.appPath))
                .resizable()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .accessibilityLabel("\(shortcut.name) icon")

            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(shortcut.appDirectory)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            shortcutBadgeArea
            cancelEditButton
            dangerTriggerButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isRecording ? Color.orange.opacity(0.04) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isRecording ? Color.orange.opacity(0.2) : Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .shadow(
            color: isRecording ? Color.orange.opacity(0.12) : .clear,
            radius: 20
        )
    }

    // MARK: - Cancel Edit Button

    private var cancelEditButton: some View {
        Button {
            onCancelEdit()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary.opacity(0.3))
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cancel-edit")
    }

    // MARK: - Shortcut Badge Area

    @ViewBuilder
    private var shortcutBadgeArea: some View {
        if isRecording {
            recordingBadge
        } else if let ks = currentShortcut {
            setBadge(ks)
        } else {
            notSetBadge
        }
    }

    private var notSetBadge: some View {
        HStack(spacing: 5) {
            Text("Not set")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isRecording = true
                }
            } label: {
                Image(systemName: "pencil.line")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("record-shortcut")
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(0.3))
        )
    }

    private var recordingBadge: some View {
        ZStack {
            ShortcutCaptureRepresentable(
                name: shortcut.keyboardShortcutName,
                onShortcutSet: { newShortcut in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isRecording = false
                    }
                    if store.isShortcutConflicting(newShortcut, excluding: shortcut.keyboardShortcutName) {
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
            .frame(width: 1, height: 1)
            .opacity(0)

            HStack(spacing: 5) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                Text("Record")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.orange)

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isRecording = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.orange)
                        .frame(width: 16, height: 16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.19))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel recording")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.125))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    private func setBadge(_ ks: KeyboardShortcuts.Shortcut) -> some View {
        let isEnabled = shortcut.isEnabled

        return HStack(spacing: 5) {
            Button {
                store.toggleEnabled(for: shortcut)
            } label: {
                Text(ks.description)
                    .font(.system(size: 11, weight: .semibold))
                    .strikethrough(!isEnabled)
                    .foregroundStyle(isEnabled ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isRecording = true
                }
            } label: {
                Image(systemName: "pencil.line")
                    .font(.system(size: 10))
                    .foregroundStyle(isEnabled ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("record-shortcut")
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isEnabled ? Color.accentColor.opacity(0.125) : Color.secondary.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isEnabled ? Color.accentColor.opacity(0.25) : .clear, lineWidth: 1)
        )
    }

    @State private var showActionDropdown = false

    private var dangerTriggerButton: some View {
        Button {
            showActionDropdown.toggle()
        } label: {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("danger-trigger")
        .opacity(isRecording ? 0.3 : 1.0)
        .disabled(isRecording)
        .popover(isPresented: $showActionDropdown, arrowEdge: .bottom) {
            actionDropdownContent
        }
    }

    private var actionDropdownContent: some View {
        HStack(spacing: 4) {
            if hasShortcut {
                Button {
                    showActionDropdown = false
                    store.unsetShortcut(for: shortcut)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.orange)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Unset shortcut")
                .accessibilityIdentifier("unset-shortcut")
            }

            Button {
                showActionDropdown = false
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundStyle(.red)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.09))
                    )
            }
            .buttonStyle(.plain)
            .help("Delete App")
            .accessibilityIdentifier("delete-app")
        }
        .padding(4)
    }
}

// MARK: - Shortcut Capture (plain NSView)

private class ShortcutCaptureView: NSView {
    var onCapture: ((KeyboardShortcuts.Shortcut) -> Void)?
    var onCancel: (() -> Void)?
    private var didComplete = false

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    private func complete() {
        guard !didComplete else { return }
        didComplete = true
    }

    override func keyDown(with event: NSEvent) {
        guard !didComplete else { return }

        if event.keyCode == 53 {
            complete()
            onCancel?()
            return
        }

        guard let shortcut = KeyboardShortcuts.Shortcut(event: event) else { return }
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty else { return }

        complete()
        onCapture?(shortcut)
    }

    override func resignFirstResponder() -> Bool {
        if !didComplete {
            complete()
            onCancel?()
        }
        return super.resignFirstResponder()
    }
}

private struct ShortcutCaptureRepresentable: NSViewRepresentable {
    let name: KeyboardShortcuts.Name
    let onShortcutSet: (KeyboardShortcuts.Shortcut) -> Void
    let onRecordingEnd: () -> Void

    func makeNSView(context: Context) -> ShortcutCaptureView {
        let view = ShortcutCaptureView()
        view.onCapture = { shortcut in
            KeyboardShortcuts.setShortcut(shortcut, for: name)
            onShortcutSet(shortcut)
        }
        view.onCancel = {
            onRecordingEnd()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let window = view.window else { return }
            window.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureView, context: Context) {}

    static func dismantleNSView(_ nsView: ShortcutCaptureView, coordinator: ()) {}
}
