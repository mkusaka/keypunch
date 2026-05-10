import AppKit
import KeypunchKeyboardShortcuts
import SwiftUI

struct SettingsPanelView: View {
    var store: ShortcutStore

    @State private var editingShortcutID: UUID?
    @State private var hoveredShortcut: AppShortcut?

    @State private var shortcutToDelete: AppShortcut?
    @State private var showDuplicateAlert = false
    @State private var duplicateAppName = ""
    @State private var pendingAddedShortcutID: UUID?
    @FocusState private var focus: PanelFocus?
    @State private var tabMonitor: Any?
    @State private var arrowMonitor: Any?
    @State private var activationMonitor: Any?

    // Lifted from EditCard for Esc handling
    @State private var isRecordingShortcut = false
    @State private var justCancelledRecording = false

    private var displayedShortcuts: [AppShortcut] {
        _ = store.shortcutKeysVersion
        return store.shortcuts
    }

    var body: some View {
        ZStack {
            panelContent
                .allowsHitTesting(!isDialogShowing)
                .accessibilityHidden(isDialogShowing)

            if let shortcut = shortcutToDelete {
                DeleteConfirmationDialog(
                    shortcut: shortcut,
                    focus: $focus,
                    onCancel: { cancelDelete(for: shortcut) },
                    onConfirm: { confirmDelete(shortcut) }
                )
            }
            if showDuplicateAlert {
                DuplicateAlertDialog(
                    appName: duplicateAppName,
                    focus: $focus,
                    onDismiss: { showDuplicateAlert = false }
                )
            }
        }
        .onChange(of: shortcutToDelete) { _, newValue in
            if newValue != nil {
                focus = .dialogCancel
            }
            updateTabMonitor()
        }
        .onChange(of: showDuplicateAlert) { _, isShowing in
            if isShowing {
                focus = .dialogOK
            }
            updateTabMonitor()
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
            } else if focus != nil {
                focus = nil
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
                                CompactRow(
                                    shortcut: shortcut,
                                    store: store,
                                    isHovered: hoveredShortcut?.id == shortcut.id,
                                    focus: $focus,
                                    onLaunch: { store.launchApp(for: shortcut) },
                                    onEdit: { enterEditMode(for: shortcut) }
                                )
                                .onHover { isHovered in
                                    hoveredShortcut = isHovered ? shortcut : nil
                                }
                            }
                        }
                        .id(shortcut.id)
                        .draggable(shortcut.id.uuidString) {
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
            .onChange(of: displayedShortcuts.map(\.id)) { _, shortcutIDs in
                updateTabMonitor()
                updateArrowMonitor()
                guard let pendingAddedShortcutID, shortcutIDs.contains(pendingAddedShortcutID) else { return }
                focusAndScrollToAddedShortcut(pendingAddedShortcutID, proxy: proxy)
            }
        }
        .onKeyPress(.rightArrow) {
            guard !isDialogShowing else { return .ignored }
            applyMoveHorizontalFocus(.right)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            guard !isDialogShowing else { return .ignored }
            applyMoveHorizontalFocus(.left)
            return .handled
        }
        .onAppear {
            updateTabMonitor()
            updateArrowMonitor()
            updateActivationMonitor()
        }
        .onDisappear {
            removeTabMonitor()
            removeArrowMonitor()
            removeActivationMonitor()
        }
        .onChange(of: editingShortcutID) { _, _ in
            updateTabMonitor()
            updateArrowMonitor()
        }
        .onChange(of: isRecordingShortcut) { _, _ in
            updateTabMonitor()
        }
    }

    // MARK: - Focus Navigation Helpers

    private func applyMoveFocus(
        _ direction: FocusDirection,
        includeEditButtons: Bool = false
    ) {
        moveFocus(
            direction: direction,
            includeEditButtons: includeEditButtons,
            focus: &focus,
            shortcuts: displayedShortcuts,
            editingShortcutID: editingShortcutID
        )
    }

    private func applyMoveHorizontalFocus(_ direction: HorizontalFocusDirection) {
        moveHorizontalFocus(
            direction: direction,
            focus: &focus,
            shortcuts: displayedShortcuts,
            editingShortcutID: editingShortcutID
        )
    }

    private func enterEditMode(for shortcut: AppShortcut) {
        withAnimation(.easeInOut(duration: 0.15)) {
            isRecordingShortcut = false
            justCancelledRecording = false
            editingShortcutID = shortcut.id
        }
        focus = .shortcutBadge(shortcut.id)
    }

    // MARK: - Add App Button

    private var addAppButton: some View {
        AddAppButton(
            store: store,
            focus: $focus,
            duplicateAppName: $duplicateAppName,
            showDuplicateAlert: $showDuplicateAlert,
            onAddSuccess: focusAddedShortcut
        )
    }

    private func focusAddedShortcut(_ shortcut: AppShortcut) {
        pendingAddedShortcutID = shortcut.id
    }

    private func focusAndScrollToAddedShortcut(_ shortcutID: UUID, proxy: ScrollViewProxy) {
        Task { @MainActor in
            focus = .row(shortcutID)

            for _ in 0 ..< 3 {
                try? await Task.sleep(nanoseconds: 300_000_000)
                withAnimation(.easeInOut(duration: 0.15)) {
                    proxy.scrollTo(shortcutID, anchor: .top)
                }
            }
            pendingAddedShortcutID = nil
        }
    }

    private func updateTabMonitor() {
        removeTabMonitor()
        guard !isDialogShowing, !isRecordingShortcut else { return }
        tabMonitor = makeTabMonitor(
            focusBinding: $focus,
            shortcutsProvider: { store.shortcuts },
            targetShortcutIDProvider: { editingShortcutID }
        )
    }

    private func removeTabMonitor() {
        if let monitor = tabMonitor {
            NSEvent.removeMonitor(monitor)
            tabMonitor = nil
        }
    }

    private func updateArrowMonitor() {
        removeArrowMonitor()
        guard editingShortcutID == nil, !isDialogShowing else { return }
        arrowMonitor = makeArrowMonitor(
            focusBinding: $focus,
            shortcutsProvider: { store.shortcuts }
        )
    }

    private func removeArrowMonitor() {
        if let monitor = arrowMonitor {
            NSEvent.removeMonitor(monitor)
            arrowMonitor = nil
        }
    }

    private func updateActivationMonitor() {
        removeActivationMonitor()
        activationMonitor = makeActivationMonitor(
            focusBinding: $focus,
            shortcutsProvider: { store.shortcuts },
            onLaunch: { shortcut in
                store.launchApp(for: shortcut)
            },
            onEdit: { shortcut in
                enterEditMode(for: shortcut)
            }
        )
    }

    private func removeActivationMonitor() {
        if let monitor = activationMonitor {
            NSEvent.removeMonitor(monitor)
            activationMonitor = nil
        }
    }

    // MARK: - Delete Actions

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
        focus = nil
    }
}
