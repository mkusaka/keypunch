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
    @FocusState private var focus: PanelFocus?
    @State private var tabMonitor: Any?

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
            guard newValue != nil else { return }
            focus = .dialogCancel
        }
        .onChange(of: showDuplicateAlert) { _, isShowing in
            guard isShowing else { return }
            focus = .dialogOK
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
        .onKeyPress(phases: .down) { press in
            guard !isDialogShowing, editingShortcutID == nil else { return .ignored }
            if press.key == .tab {
                moveFocus(direction: press.modifiers.contains(.shift) ? .up : .down)
                return .handled
            }
            if press.key == KeyEquivalent(Character("\u{19}")) {
                moveFocus(direction: .up)
                return .handled
            }
            return .ignored
        }
        .onAppear {
            updateTabMonitor()
        }
        .onDisappear {
            removeTabMonitor()
        }
        .onChange(of: editingShortcutID) { _, _ in
            updateTabMonitor()
        }
        .onChange(of: isRecordingShortcut) { _, _ in
            updateTabMonitor()
        }
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
            showDuplicateAlert: $showDuplicateAlert
        )
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

    private func updateTabMonitor() {
        removeTabMonitor()

        guard editingShortcutID != nil, !isDialogShowing, !isRecordingShortcut else {
            return
        }

        let focusBinding = $focus
        let shortcuts = displayedShortcuts
        let targetShortcutID = editingShortcutID

        tabMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let targetShortcutID else { return event }
            guard event.keyCode == 48 else { return event }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !flags.contains(.command),
                  !flags.contains(.control),
                  !flags.contains(.option),
                  !flags.contains(.function),
                  !flags.contains(.capsLock),
                  !flags.contains(.numericPad)
            else {
                return event
            }

            guard let targetShortcut = shortcuts.first(where: { $0.id == targetShortcutID }) else {
                return event
            }

            var targets: [PanelFocus] = [.shortcutBadge(targetShortcutID)]
            if KeyboardShortcutsClient.getShortcut(for: targetShortcut.keyboardShortcutName) != nil {
                targets.append(.shortcutEditButton(targetShortcutID))
                targets.append(.dangerButton(targetShortcutID))
            }
            targets.append(.deleteButton(targetShortcutID))
            targets.append(.cancelEdit(targetShortcutID))
            guard !targets.isEmpty else { return event }

            let reverse = flags.contains(.shift)
            let currentIndex = targets.firstIndex(where: { $0 == focusBinding.wrappedValue })
            let nextIndex = if let current = currentIndex {
                reverse ? (current - 1 + targets.count) % targets.count : (current + 1) % targets.count
            } else {
                reverse ? targets.count - 1 : 0
            }

            withAnimation(.easeInOut(duration: 0.15)) {
                focusBinding.wrappedValue = targets[nextIndex]
            }
            return nil
        }
    }

    private func removeTabMonitor() {
        if let monitor = tabMonitor {
            NSEvent.removeMonitor(monitor)
            tabMonitor = nil
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
