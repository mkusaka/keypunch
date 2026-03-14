import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers

struct FloatingPanelView: View {
    var store: ShortcutStore
    var showAllForTesting: Bool = false
    var onDrag: ((DragGesture.Value) -> Void)?
    var onDragEnd: (() -> Void)?

    @State private var editingShortcutID: UUID?
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
            panelContent
        }
        .frame(width: 300, height: 360)
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
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(coordinateSpace: .global)
                .onChanged { value in
                    onDrag?(value)
                }
                .onEnded { _ in
                    onDragEnd?()
                }
        )
    }

    // MARK: - Shared

    private var dividerLine: some View {
        Rectangle()
            .fill(Color(red: 0.16, green: 0.16, blue: 0.18)) // #2A2A2E
            .frame(height: 1)
    }

    // MARK: - Unified Content

    private var panelContent: some View {
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
                            onEdit: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    editingShortcutID = shortcut.id
                                }
                            }
                        )
                        .id("\(shortcut.id)-launch-\(store.shortcutKeysVersion)")
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
                        .frame(width: 240)

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

// MARK: - Launch Row (compact mode)

private struct LaunchRow: View {
    let shortcut: AppShortcut
    let isHovered: Bool
    var onEdit: (() -> Void)?

    private static let blueColor = Color(red: 0.04, green: 0.52, blue: 1.0) // #0A84FF

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: shortcut.appPath))
                .resizable()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7))
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

            // Edit pencil button
            Button {
                onEdit?()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundStyle(isHovered ? Color.white.opacity(0.6) : Color(white: 0.3))
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(isHovered ? 0.08 : 0.03))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("edit-shortcut")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered
                    ? Self.blueColor.opacity(0.08)
                    : Color(red: 0.10, green: 0.10, blue: 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered
                    ? Self.blueColor.opacity(0.2)
                    : Color.white.opacity(0.04), lineWidth: 1)
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
                    .foregroundStyle(Self.blueColor)
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Self.blueColor.opacity(0.15))
                    )
            } else {
                // Disabled
                Text(ks.description)
                    .font(.system(size: 11, weight: .medium))
                    .strikethrough()
                    .foregroundStyle(Color(white: 0.42))
                    .padding(.horizontal, 6)
                    .frame(height: 20)
            }
        } else {
            // Not set
            Text("Not set")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.31))
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

    private static let blueColor = Color(red: 0.04, green: 0.52, blue: 1.0)    // #0A84FF
    private static let amberColor = Color(red: 1.0, green: 0.71, blue: 0.28)   // #FFB547
    private static let grayColor = Color(white: 0.42)                           // #6B6B70
    private static let dangerColor = Color(red: 0.91, green: 0.35, blue: 0.31) // #E85A4F
    private static let dimTextColor = Color(red: 0.29, green: 0.29, blue: 0.31) // #4A4A50

    private var currentShortcut: KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.getShortcut(for: shortcut.keyboardShortcutName)
    }

    private var hasShortcut: Bool {
        currentShortcut != nil
    }

    var body: some View {
        HStack(spacing: 8) {
            // App icon
            Image(nsImage: NSWorkspace.shared.icon(forFile: shortcut.appPath))
                .resizable()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .accessibilityLabel("\(shortcut.name) icon")

            // Name + path
            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(shortcut.appDirectory)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Self.dimTextColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Shortcut badge area
            shortcutBadgeArea

            // X exit edit mode
            cancelEditButton

            // Danger trigger → dropdown with Unset / Delete
            dangerTriggerButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isRecording
                    ? Color(red: 0.12, green: 0.11, blue: 0.10) // slightly warm tint
                    : Color(red: 0.10, green: 0.10, blue: 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isRecording
                    ? Self.amberColor.opacity(0.19) // #FFB54730
                    : Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(
            color: isRecording ? Self.amberColor.opacity(0.12) : .clear,
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
                .foregroundStyle(Color(white: 0.42))
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
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

    // State 1: Not Set — gray "Not set" + pen icon
    private var notSetBadge: some View {
        HStack(spacing: 5) {
            Text("Not set")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Self.dimTextColor)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isRecording = true
                }
            } label: {
                Image(systemName: "pencil.line")
                    .font(.system(size: 10))
                    .foregroundStyle(Self.dimTextColor)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("record-shortcut")
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // State 2: Recording — amber dot + "Record" + X cancel
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
                    .fill(Self.amberColor)
                    .frame(width: 6, height: 6)
                Text("Record")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Self.amberColor)

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isRecording = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Self.amberColor)
                        .frame(width: 16, height: 16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Self.amberColor.opacity(0.19))
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
                .fill(Self.amberColor.opacity(0.125))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Self.amberColor.opacity(0.25), lineWidth: 1)
        )
    }

    // State 3: Set — key combo (click to toggle) + pen icon (click to record)
    private func setBadge(_ ks: KeyboardShortcuts.Shortcut) -> some View {
        let isEnabled = shortcut.isEnabled
        let badgeColor = isEnabled ? Self.blueColor : Self.grayColor

        return HStack(spacing: 5) {
            // Shortcut text: click to toggle enable/disable
            Button {
                store.toggleEnabled(for: shortcut)
            } label: {
                Text(ks.description)
                    .font(.system(size: 11, weight: .semibold))
                    .strikethrough(!isEnabled)
                    .foregroundStyle(badgeColor)
            }
            .buttonStyle(.plain)

            // Pen icon: click to start recording
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isRecording = true
                }
            } label: {
                Image(systemName: "pencil.line")
                    .font(.system(size: 10))
                    .foregroundStyle(badgeColor)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("record-shortcut")
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isEnabled
                    ? Self.blueColor.opacity(0.125)
                    : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isEnabled
                    ? Self.blueColor.opacity(0.25)
                    : Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // Danger trigger button → opens action dropdown
    @State private var showActionDropdown = false

    private var dangerTriggerButton: some View {
        Button {
            showActionDropdown.toggle()
        } label: {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 11))
                .foregroundStyle(Self.dangerColor)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Self.dangerColor.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Self.dangerColor.opacity(0.37), lineWidth: 1)
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

    // Dropdown content: icon-only buttons with hover tooltips
    private var actionDropdownContent: some View {
        HStack(spacing: 4) {
            if hasShortcut {
                // Unset shortcut
                Button {
                    showActionDropdown = false
                    store.unsetShortcut(for: shortcut)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16))
                        .foregroundStyle(Self.amberColor)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Self.amberColor.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Self.amberColor.opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Unset shortcut")
                .accessibilityIdentifier("unset-shortcut")
            }

            // Delete app
            Button {
                showActionDropdown = false
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundStyle(Self.dangerColor)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Self.dangerColor.opacity(0.09))
                    )
            }
            .buttonStyle(.plain)
            .help("Delete App")
            .accessibilityIdentifier("delete-app")
        }
        .padding(4)
    }
}

// MARK: - Shortcut Capture (plain NSView — avoids RecorderCocoa/NSSearchField ViewBridge issues)

/// Plain NSView that captures modifier+key combos as keyboard shortcuts.
/// Unlike RecorderCocoa (NSSearchField subclass), this does not use Remote View Services,
/// so it avoids ViewBridge disconnection errors in floating panels.
private class ShortcutCaptureView: NSView {
    var onCapture: ((KeyboardShortcuts.Shortcut) -> Void)?
    var onCancel: (() -> Void)?
    private var didComplete = false

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    private func complete() {
        guard !didComplete else { return }
        didComplete = true
        if let keyable = window as? KeyablePanel {
            keyable.allowBecomeKey = false
        }
    }

    override func keyDown(with event: NSEvent) {
        guard !didComplete else { return }

        // Escape cancels recording
        if event.keyCode == 53 {
            complete()
            onCancel?()
            return
        }

        // Build shortcut from event (requires at least one modifier key)
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

        // Auto-focus to start recording immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let window = view.window else { return }
            if let keyable = window as? KeyablePanel {
                keyable.allowBecomeKey = true
            }
            window.makeKey()
            window.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureView, context: Context) {}

    static func dismantleNSView(_ nsView: ShortcutCaptureView, coordinator: ()) {
        // Ensure KeyablePanel is reset when capture view is removed (e.g., cancel button)
        if let keyable = nsView.window as? KeyablePanel {
            keyable.allowBecomeKey = false
        }
    }
}
