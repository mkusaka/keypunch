import KeyboardShortcuts
import SwiftUI
import UniformTypeIdentifiers

struct SettingsPanelView: View {
    var store: ShortcutStore
    var showAllForTesting: Bool = false

    @State private var editingShortcutID: UUID?
    @State private var hoveredShortcut: AppShortcut?

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
                } else if let id = editingShortcutID {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        editingShortcutID = nil
                    }
                    focus = .row(id)
                }
            }
    }

    // MARK: - Content

    private var isDialogShowing: Bool {
        shortcutToDelete != nil || showDuplicateAlert
    }

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
            .focusEffectDisabled()
            .focused($focus, equals: .row(shortcut.id))
            .onKeyPress(.return) {
                store.launchApp(for: shortcut)
                return .handled
            }

            // Edit button — separate focus target
            EditPencilButton(
                isHighlighted: isHighlighted,
                isFocused: editBtnFocused
            ) {
                enterEditMode(for: shortcut)
            }
            .focusable()
            .focusEffectDisabled()
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
        let shortcutDesc: String = if let ks = KeyboardShortcuts.getShortcut(for: shortcut.keyboardShortcutName) {
            shortcut.isEnabled ? "Shortcut: \(ks.description)" : "Shortcut: \(ks.description), disabled"
        } else {
            "No shortcut set"
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
        let isFocused = focus == .addApp

        return Button {
            addShortcut()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14))
                Text("Add App")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isFocused ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isFocused ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.2),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .focusable()
        .focusEffectDisabled()
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
        let nextPosition: Int = switch direction {
        case .down:
            (currentPosition + 1) % totalPositions
        case .up:
            (currentPosition - 1 + totalPositions) % totalPositions
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
                        .focusEffectDisabled()
                        .focused($focus, equals: .dialogCancel)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    focus == .dialogCancel ? Color.accentColor.opacity(0.6) : .clear,
                                    lineWidth: 1.5
                                )
                        )
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
                        .focusEffectDisabled()
                        .focused($focus, equals: .dialogRemove)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(focus == .dialogRemove ? Color.red.opacity(0.6) : .clear, lineWidth: 1.5)
                        )
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
                .focusEffectDisabled()
                .focused($focus, equals: .dialogOK)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(focus == .dialogOK ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1.5)
                )
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
        case let .duplicate(name):
            duplicateAppName = name
            showDuplicateAlert = true
        }
    }
}
