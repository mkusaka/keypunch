import KeypunchKeyboardShortcuts
import SwiftUI

struct EditCard: View {
    let shortcut: AppShortcut
    let store: ShortcutStore
    @Binding var isRecording: Bool
    var focus: FocusState<PanelFocus?>.Binding
    let onDelete: () -> Void
    let onCancelEdit: () -> Void
    let onRecordingCancelled: () -> Void
    @State private var conflictError: String?

    private var currentShortcut: KeyboardShortcutsClient.Shortcut? {
        KeyboardShortcutsClient.getShortcut(for: shortcut.keyboardShortcutName)
    }

    private var hasShortcut: Bool {
        currentShortcut != nil
    }

    private var focusTargetsInCard: [PanelFocus] {
        let id = shortcut.id
        var targets: [PanelFocus] = [.shortcutBadge(id)]
        if hasShortcut {
            targets.append(.shortcutEditButton(id))
            targets.append(.dangerButton(id))
        }
        targets.append(.deleteButton(id))
        targets.append(.cancelEdit(id))
        return targets
    }

    var body: some View {
        cardContent
            .onChange(of: isRecording) { _, newValue in
                if !newValue {
                    DispatchQueue.main.async {
                        focus.wrappedValue = .shortcutBadge(shortcut.id)
                    }
                }
            }
            .onKeyPress(phases: .down) { press in
                guard !isRecording else { return .ignored }
                if press.key == .tab, !press.modifiers.contains(.shift) {
                    advanceFocusWithinCard(reverse: false)
                    return .handled
                }
                if press.key == .tab, press.modifiers.contains(.shift) {
                    advanceFocusWithinCard(reverse: true)
                    return .handled
                }
                if press.key == KeyEquivalent(Character("\u{19}")) {
                    advanceFocusWithinCard(reverse: true)
                    return .handled
                }
                return .ignored
            }
            .alert(
                "Shortcut Conflict",
                isPresented: Binding(
                    get: { conflictError != nil },
                    set: { if !$0 { conflictError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(
                    "This shortcut is already used by another app. The shortcut has been reset."
                )
            }
    }

    // MARK: - Card Layout

    private var cardContent: some View {
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
            editShortcutButton
            unsetShortcutButton
            deleteAppButton
            cancelEditButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isRecording
                        ? Color.orange.opacity(0.04)
                        : Color.accentColor.opacity(0.08)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isRecording
                        ? Color.orange.opacity(0.2)
                        : Color.accentColor.opacity(0.2),
                    lineWidth: 1
                )
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

    // MARK: - Tab Loop

    private func advanceFocusWithinCard(reverse: Bool = false) {
        let targets = focusTargetsInCard
        guard !targets.isEmpty else { return }

        let currentIndex = targets.firstIndex(where: { $0 == focus.wrappedValue })
        let nextIndex = if let current = currentIndex {
            if reverse {
                (current - 1 + targets.count) % targets.count
            } else {
                (current + 1) % targets.count
            }
        } else {
            reverse ? targets.count - 1 : 0
        }
        focus.wrappedValue = targets[nextIndex]
    }

    // MARK: - Shortcut Badge

    @ViewBuilder
    private var shortcutBadgeArea: some View {
        if isRecording {
            RecordingBadge(
                shortcut: shortcut,
                store: store,
                isRecording: $isRecording,
                onConflict: { conflictError = $0 },
                onRecordingCancelled: onRecordingCancelled
            )
        } else if let ks = currentShortcut {
            SetBadgeButton(
                shortcut: shortcut,
                store: store,
                ks: ks,
                focus: focus
            )
        } else {
            NotSetBadgeButton(
                shortcut: shortcut,
                isRecording: $isRecording,
                focus: focus
            )
        }
    }

    // MARK: - Edit Button

    @ViewBuilder
    private var editShortcutButton: some View {
        if hasShortcut, !isRecording {
            EditShortcutButton(
                shortcut: shortcut,
                isRecording: $isRecording,
                focus: focus
            )
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var unsetShortcutButton: some View {
        if hasShortcut {
            CardActionButton(
                icon: "arrow.counterclockwise",
                color: .orange,
                focusTarget: .dangerButton(shortcut.id),
                identifier: "unset-shortcut",
                label: "Unset shortcut for \(shortcut.name)",
                hint: "Removes the keyboard shortcut binding",
                helpText: "Unset shortcut",
                focus: focus
            ) {
                store.unsetShortcut(for: shortcut)
                focus.wrappedValue = .shortcutBadge(shortcut.id)
            }
            .opacity(isRecording ? 0.3 : 1.0)
            .disabled(isRecording)
        }
    }

    private var deleteAppButton: some View {
        CardActionButton(
            icon: "trash",
            color: .red,
            focusTarget: .deleteButton(shortcut.id),
            identifier: "delete-app",
            label: "Delete \(shortcut.name)",
            hint: "Opens a confirmation dialog to remove this app",
            helpText: "Delete app",
            focus: focus,
            action: onDelete
        )
        .opacity(isRecording ? 0.3 : 1.0)
        .disabled(isRecording)
    }

    private var cancelEditButton: some View {
        CardActionButton(
            icon: "xmark",
            color: .accentColor,
            focusTarget: .cancelEdit(shortcut.id),
            identifier: "cancel-edit",
            label: "Cancel editing",
            helpText: "Cancel editing",
            focus: focus,
            action: onCancelEdit
        )
    }
}
