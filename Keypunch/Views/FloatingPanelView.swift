import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers

// MARK: - Focus Management

private enum PanelFocus: Hashable {
    case row(UUID)
    case editButton(UUID)
    case addApp
    // Edit mode focus targets
    case shortcutBadge(UUID)
    case shortcutEditButton(UUID)
    case cancelEdit(UUID)
    case dangerButton(UUID)

    var appID: UUID? {
        switch self {
        case .row(let id), .editButton(let id),
             .shortcutBadge(let id), .shortcutEditButton(let id),
             .cancelEdit(let id), .dangerButton(let id):
            return id
        case .addApp:
            return nil
        }
    }
}

struct SettingsPanelView: View {
    var store: ShortcutStore
    var showAllForTesting: Bool = false

    @State private var editingShortcutID: UUID?
    @State private var hoveredShortcut: AppShortcut?
    @State private var draggedShortcutID: UUID?
    @State private var shortcutToDelete: AppShortcut?
    @State private var showDuplicateAlert = false
    @State private var duplicateAppName = ""
    @FocusState private var focus: PanelFocus?

    // Lifted from EditCard for Esc handling
    @State private var isRecordingShortcut = false
    @State private var showingActionDropdown = false
    @State private var justCancelledRecording = false

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
                if justCancelledRecording {
                    justCancelledRecording = false
                    return
                }
                if shortcutToDelete != nil {
                    shortcutToDelete = nil
                } else if showingActionDropdown {
                    showingActionDropdown = false
                } else if isRecordingShortcut {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isRecordingShortcut = false
                    }
                } else if editingShortcutID != nil {
                    let id = editingShortcutID!
                    withAnimation(.easeInOut(duration: 0.15)) {
                        editingShortcutID = nil
                    }
                    focus = .row(id)
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
                    let isEditing = editingShortcutID == shortcut.id
                    Group {
                        if isEditing {
                            EditCard(
                                shortcut: shortcut,
                                store: store,
                                isRecording: $isRecordingShortcut,
                                showActionDropdown: $showingActionDropdown,
                                focus: $focus,
                                onDelete: {
                                    editingShortcutID = nil
                                    shortcutToDelete = shortcut
                                },
                                onCancelEdit: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        editingShortcutID = nil
                                    }
                                    focus = .row(shortcut.id)
                                },
                                onRecordingCancelled: {
                                    justCancelledRecording = true
                                }
                            )
                            .id("\(shortcut.id)-edit-\(store.shortcutKeysVersion)")
                            .transition(.opacity)
                        } else {
                            compactRow(shortcut: shortcut)
                        }
                    }
                    .opacity(draggedShortcutID == shortcut.id ? 0.4 : 1.0)
                    .draggable(shortcut.id.uuidString) {
                        // Drag preview
                        Text(shortcut.name)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.regularMaterial)
                            )
                    }
                    .dropDestination(for: String.self) { items, _ in
                        guard let droppedIDString = items.first,
                              let droppedID = UUID(uuidString: droppedIDString),
                              droppedID != shortcut.id,
                              let fromIndex = store.shortcuts.firstIndex(where: { $0.id == droppedID }),
                              let toIndex = store.shortcuts.firstIndex(where: { $0.id == shortcut.id })
                        else { return false }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.moveShortcuts(
                                from: IndexSet(integer: fromIndex),
                                to: toIndex > fromIndex ? toIndex + 1 : toIndex
                            )
                        }
                        return true
                    } isTargeted: { isTargeted in
                        if isTargeted {
                            hoveredShortcut = shortcut
                        }
                    }
                }

                addAppButton
            }
            .padding(8)
        }
        .onKeyPress(.downArrow) {
            moveFocus(direction: .down)
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveFocus(direction: .up)
            return .handled
        }
    }

    // MARK: - Compact Row (app row + edit button)

    private func compactRow(shortcut: AppShortcut) -> some View {
        let isHovered = hoveredShortcut?.id == shortcut.id
        let rowFocused = focus == .row(shortcut.id)
        let editBtnFocused = focus == .editButton(shortcut.id)
        let isHighlighted = isHovered || rowFocused || editBtnFocused

        return HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: shortcut.appPath))
                .resizable()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .accessibilityLabel("\(shortcut.name) icon")

            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(shortcut.appDirectory)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            compactShortcutBadge(shortcut: shortcut)

            // Edit button — separate focus target, uses Button to consume tap
            Button {
                enterEditMode(for: shortcut)
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
            .focusable()
            .focused($focus, equals: .editButton(shortcut.id))
            .onKeyPress(.return) {
                enterEditMode(for: shortcut)
                return .handled
            }
            .accessibilityIdentifier("edit-shortcut")
            .help("Edit shortcut")
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
                .stroke((rowFocused || editBtnFocused) ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .focusable()
        .focused($focus, equals: .row(shortcut.id))
        .onKeyPress(.return) {
            guard focus == .row(shortcut.id) else { return .ignored }
            store.launchApp(for: shortcut)
            return .handled
        }
        .onTapGesture {
            store.launchApp(for: shortcut)
        }
        .onHover { isHovered in
            hoveredShortcut = isHovered ? shortcut : nil
        }
        .id("\(shortcut.id)-launch-\(store.shortcutKeysVersion)")
    }

    @ViewBuilder
    private func compactShortcutBadge(shortcut: AppShortcut) -> some View {
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

    private func enterEditMode(for shortcut: AppShortcut) {
        withAnimation(.easeInOut(duration: 0.15)) {
            // Reset state from any previous edit
            isRecordingShortcut = false
            showingActionDropdown = false
            justCancelledRecording = false
            editingShortcutID = shortcut.id
        }
        focus = .shortcutBadge(shortcut.id)
    }

    // MARK: - Add App Button

    private var addAppButton: some View {
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
        .focusable()
        .focused($focus, equals: .addApp)
        .onKeyPress(.return) {
            addShortcut()
            return .handled
        }
        .onTapGesture {
            addShortcut()
        }
        .accessibilityIdentifier("add-app-button")
        .accessibilityAddTraits(.isButton)
        .help("Add application")
    }

    // MARK: - Arrow Key Navigation

    private enum Direction { case up, down }

    private func moveFocus(direction: Direction) {
        let shortcuts = displayedShortcuts

        guard let current = focus else {
            if let first = shortcuts.first {
                focus = editingShortcutID == first.id ? .shortcutBadge(first.id) : .row(first.id)
            } else {
                focus = .addApp
            }
            return
        }

        // Arrow keys navigate by app (edit button focus = same app)
        let currentAppID = current.appID
        let currentPosition: Int
        if let appID = currentAppID, let idx = shortcuts.firstIndex(where: { $0.id == appID }) {
            currentPosition = idx
        } else if current == .addApp {
            currentPosition = shortcuts.count
        } else {
            focus = shortcuts.first.map { .row($0.id) } ?? .addApp
            return
        }

        let totalPositions = shortcuts.count + 1
        let nextPosition: Int
        switch direction {
        case .down:
            nextPosition = (currentPosition + 1) % totalPositions
        case .up:
            nextPosition = (currentPosition - 1 + totalPositions) % totalPositions
        }

        if nextPosition == shortcuts.count {
            focus = .addApp
        } else {
            let target = shortcuts[nextPosition]
            if editingShortcutID == target.id {
                focus = .shortcutBadge(target.id)
            } else {
                focus = .row(target.id)
            }
        }
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

// MARK: - Edit Card (expanded edit mode)

private struct EditCard: View {
    let shortcut: AppShortcut
    let store: ShortcutStore
    @Binding var isRecording: Bool
    @Binding var showActionDropdown: Bool
    var focus: FocusState<PanelFocus?>.Binding
    let onDelete: () -> Void
    let onCancelEdit: () -> Void
    let onRecordingCancelled: () -> Void
    @State private var conflictError: String?

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
                .fill(isRecording ? Color.orange.opacity(0.04) : Color.accentColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isRecording ? Color.orange.opacity(0.2) : Color.accentColor.opacity(0.2), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5)
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
        .focusable()
        .focused(focus, equals: .cancelEdit(shortcut.id))
        .onKeyPress(.return) {
            onCancelEdit()
            return .handled
        }
        .accessibilityIdentifier("cancel-edit")
        .help("Cancel editing")
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
            .help("Click to record shortcut")
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(0.3))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                isRecording = true
            }
        }
        .focusable()
        .focused(focus, equals: .shortcutBadge(shortcut.id))
        .onKeyPress(.return) {
            withAnimation(.easeInOut(duration: 0.15)) {
                isRecording = true
            }
            return .handled
        }
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
                    onRecordingCancelled()
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
                    onRecordingCancelled()
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
                .help("Cancel recording")
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
            .help(isEnabled ? "Disable shortcut" : "Enable shortcut")

            Image(systemName: "pencil.line")
                .font(.system(size: 10))
                .foregroundStyle(isEnabled ? Color.accentColor : .secondary)
                .focusable()
                .focused(focus, equals: .shortcutEditButton(shortcut.id))
                .onKeyPress(.return) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isRecording = true
                    }
                    return .handled
                }
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isRecording = true
                    }
                }
                .accessibilityIdentifier("record-shortcut")
                .help("Re-record shortcut")
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
        .focusable()
        .focused(focus, equals: .shortcutBadge(shortcut.id))
        .onKeyPress(.return) {
            withAnimation(.easeInOut(duration: 0.15)) {
                isRecording = true
            }
            return .handled
        }
    }

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
        .focusable()
        .focused(focus, equals: .dangerButton(shortcut.id))
        .onKeyPress(.return) {
            showActionDropdown.toggle()
            return .handled
        }
        .accessibilityIdentifier("danger-trigger")
        .help("Danger actions")
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
