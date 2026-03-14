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
    case deleteButton(UUID)
    // Dialog focus targets
    case dialogCancel
    case dialogRemove
    case dialogOK

    var appID: UUID? {
        switch self {
        case .row(let id), .editButton(let id),
             .shortcutBadge(let id), .shortcutEditButton(let id),
             .cancelEdit(let id), .dangerButton(let id),
             .deleteButton(let id):
            return id
        case .addApp, .dialogCancel, .dialogRemove, .dialogOK:
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
                if showDuplicateAlert {
                    duplicateAlertOverlay
                }
            }
            .onExitCommand {
                if justCancelledRecording {
                    justCancelledRecording = false
                    return
                }
                if showDuplicateAlert {
                    showDuplicateAlert = false
                } else if let toDelete = shortcutToDelete {
                    shortcutToDelete = nil
                    focus = .deleteButton(toDelete.id)
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
    }

    // MARK: - Content

    private var isDialogShowing: Bool { shortcutToDelete != nil || showDuplicateAlert }

    private var panelContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 6) {
                    if displayedShortcuts.isEmpty {
                        Text("No shortcuts configured")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 16)
                            .accessibilityIdentifier("empty-state")
                    }

                    ForEach(displayedShortcuts) { shortcut in
                        let isEditing = editingShortcutID == shortcut.id
                        Group {
                            if isEditing {
                                EditCard(
                                    shortcut: shortcut,
                                    store: store,
                                    isRecording: $isRecordingShortcut,
                                    focus: $focus,
                                    onDelete: {
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
                        .id(shortcut.id)
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
                        .id("add-app")
                }
                .padding(8)
            }
            .onChange(of: focus) { _, newFocus in
                guard let newFocus else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    if let appID = newFocus.appID {
                        proxy.scrollTo(appID, anchor: .center)
                    } else if newFocus == .addApp {
                        proxy.scrollTo("add-app", anchor: .center)
                    }
                }
            }
        }
        .onKeyPress(.downArrow) {
            guard !isDialogShowing else { return .ignored }
            moveFocus(direction: .down)
            return .handled
        }
        .onKeyPress(.upArrow) {
            guard !isDialogShowing else { return .ignored }
            moveFocus(direction: .up)
            return .handled
        }
        .disabled(isDialogShowing)
    }

    // MARK: - Compact Row (app row + edit button)

    private func compactRow(shortcut: AppShortcut) -> some View {
        let isHovered = hoveredShortcut?.id == shortcut.id
        let rowFocused = focus == .row(shortcut.id)
        let editBtnFocused = focus == .editButton(shortcut.id)
        let isHighlighted = isHovered || rowFocused || editBtnFocused

        return HStack(spacing: 8) {
            // Launch button — covers icon, name, badge area
            Button {
                store.launchApp(for: shortcut)
            } label: {
                HStack(spacing: 8) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: shortcut.appPath))
                        .resizable()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 7))

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
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable()
            .focused($focus, equals: .row(shortcut.id))
            .onKeyPress(.return) {
                store.launchApp(for: shortcut)
                return .handled
            }

            // Edit button — separate focus target
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
            .accessibilityLabel("Edit \(shortcut.name)")
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
        .onHover { isHovered in
            hoveredShortcut = isHovered ? shortcut : nil
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(compactRowAccessibilityLabel(for: shortcut))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Press Enter to launch \(shortcut.name)")
        .id("\(shortcut.id)-launch-\(store.shortcutKeysVersion)")
    }

    private func compactRowAccessibilityLabel(for shortcut: AppShortcut) -> String {
        let shortcutDesc: String
        if let ks = KeyboardShortcuts.getShortcut(for: shortcut.keyboardShortcutName) {
            shortcutDesc = shortcut.isEnabled ? "Shortcut: \(ks.description)" : "Shortcut: \(ks.description), disabled"
        } else {
            shortcutDesc = "No shortcut set"
        }
        return "\(shortcut.name), \(shortcut.appDirectory), \(shortcutDesc)"
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
                .accessibilityIdentifier("not-set-badge")
        }
    }

    private func enterEditMode(for shortcut: AppShortcut) {
        withAnimation(.easeInOut(duration: 0.15)) {
            // Reset state from any previous edit
            isRecordingShortcut = false
            justCancelledRecording = false
            editingShortcutID = shortcut.id
        }
        focus = .shortcutBadge(shortcut.id)
    }

    // MARK: - Add App Button

    private var addAppButton: some View {
        Button {
            addShortcut()
        } label: {
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
        .focusable()
        .focused($focus, equals: .addApp)
        .onKeyPress(.return) {
            addShortcut()
            return .handled
        }
        .accessibilityIdentifier("add-app-button")
        .accessibilityLabel("Add App")
        .accessibilityHint("Opens a file picker to add an application")
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
                            cancelDelete(for: shortcut)
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                        }
                        .buttonStyle(.bordered)
                        .focusable()
                        .focused($focus, equals: .dialogCancel)
                        .onKeyPress(.return) {
                            cancelDelete(for: shortcut)
                            return .handled
                        }
                        .accessibilityIdentifier("dialog-cancel")
                        .accessibilityLabel("Cancel")
                        .accessibilityHint("Dismisses the dialog and keeps \(shortcut.name)")

                        Button(role: .destructive) {
                            confirmDelete(shortcut)
                        } label: {
                            Text("Remove")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .focusable()
                        .focused($focus, equals: .dialogRemove)
                        .onKeyPress(.return) {
                            confirmDelete(shortcut)
                            return .handled
                        }
                        .accessibilityIdentifier("dialog-remove")
                        .accessibilityLabel("Remove \(shortcut.name)")
                        .accessibilityHint("Permanently removes this app and its shortcut")
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
                .accessibilityAddTraits(.isModal)
                .accessibilityLabel("Remove \(shortcut.name) confirmation")
            }
        }
        .accessibilityIdentifier("delete-confirmation-dialog")
    }

    private var duplicateAlertOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)

            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.orange.opacity(0.08))
                        .frame(width: 48, height: 48)
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 20))
                        .foregroundStyle(.orange)
                }

                Text("Duplicate Application")
                    .font(.system(size: 16, weight: .semibold))

                Text("\(duplicateAppName) has already been added.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 240)

                Button {
                    showDuplicateAlert = false
                } label: {
                    Text("OK")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(.borderedProminent)
                .focusable()
                .focused($focus, equals: .dialogOK)
                .onKeyPress(.return) {
                    showDuplicateAlert = false
                    return .handled
                }
                .accessibilityIdentifier("dialog-ok")
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )
            .padding(24)
            .accessibilityAddTraits(.isModal)
            .accessibilityLabel("Duplicate application alert")
        }
        .accessibilityIdentifier("duplicate-alert-dialog")
    }

    private func cancelDelete(for shortcut: AppShortcut) {
        shortcutToDelete = nil
        focus = .deleteButton(shortcut.id)
    }

    private func confirmDelete(_ shortcut: AppShortcut) {
        store.removeShortcut(shortcut)
        shortcutToDelete = nil
        withAnimation(.easeInOut(duration: 0.15)) {
            editingShortcutID = nil
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
            unsetShortcutButton
            deleteAppButton
            cancelEditButton
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
        .accessibilityLabel("Cancel editing")
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
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isRecording = true
            }
        } label: {
            HStack(spacing: 5) {
                Text("Not set")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                Image(systemName: "pencil.line")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary.opacity(0.3))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
        .focused(focus, equals: .shortcutBadge(shortcut.id))
        .onKeyPress(.return) {
            withAnimation(.easeInOut(duration: 0.15)) {
                isRecording = true
            }
            return .handled
        }
        .accessibilityIdentifier("not-set-badge")
        .accessibilityLabel("Shortcut not set")
        .accessibilityHint("Press Enter to record a keyboard shortcut")
        .help("Record shortcut")
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
        .accessibilityIdentifier("recording-badge")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recording shortcut. Press a key combination or Escape to cancel.")
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
            .focusable()
            .focused(focus, equals: .shortcutEditButton(shortcut.id))
            .onKeyPress(.return) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isRecording = true
                }
                return .handled
            }
            .accessibilityIdentifier("record-shortcut")
            .accessibilityLabel("Re-record shortcut")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Shortcut: \(ks.description)\(isEnabled ? "" : ", disabled")")
        .accessibilityHint("Press Enter to re-record shortcut")
    }

    @ViewBuilder
    private var unsetShortcutButton: some View {
        if hasShortcut {
            Button {
                store.unsetShortcut(for: shortcut)
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.orange)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)
            .focusable()
            .focused(focus, equals: .dangerButton(shortcut.id))
            .onKeyPress(.return) {
                store.unsetShortcut(for: shortcut)
                return .handled
            }
            .accessibilityIdentifier("unset-shortcut")
            .accessibilityLabel("Unset shortcut for \(shortcut.name)")
            .accessibilityHint("Removes the keyboard shortcut binding")
            .help("Unset shortcut")
            .opacity(isRecording ? 0.3 : 1.0)
            .disabled(isRecording)
        }
    }

    private var deleteAppButton: some View {
        Button {
            onDelete()
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red.opacity(0.09))
                )
        }
        .buttonStyle(.plain)
        .focusable()
        .focused(focus, equals: .deleteButton(shortcut.id))
        .onKeyPress(.return) {
            onDelete()
            return .handled
        }
        .accessibilityIdentifier("delete-app")
        .accessibilityLabel("Delete \(shortcut.name)")
        .accessibilityHint("Opens a confirmation dialog to remove this app")
        .help("Delete app")
        .opacity(isRecording ? 0.3 : 1.0)
        .disabled(isRecording)
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
