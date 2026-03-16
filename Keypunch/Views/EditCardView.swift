import KeyboardShortcuts
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

    private var currentShortcut: KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.getShortcut(for: shortcut.keyboardShortcutName)
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
            .onChange(of: focus.wrappedValue) { oldValue, newValue in
                guard !isRecording else { return }
                let targets = focusTargetsInCard
                // Only act when focus WAS inside this card and moved outside
                guard let old = oldValue, targets.contains(old) else { return }
                let stayedInCard = newValue.map { targets.contains($0) } ?? false
                if stayedInCard { return }

                // Focus escaped — redirect back into card
                guard let oldIndex = targets.firstIndex(of: old) else { return }
                if oldIndex == 0 {
                    // Escaped backward from first → wrap to last
                    focus.wrappedValue = targets[targets.count - 1]
                } else if oldIndex == targets.count - 1 {
                    // Escaped forward from last → wrap to first
                    focus.wrappedValue = targets[0]
                } else {
                    // Middle element somehow escaped → stay put
                    focus.wrappedValue = old
                }
            }
            .onKeyPress(phases: .down) { press in
                guard press.key == .tab, !isRecording else { return .ignored }
                advanceFocusWithinCard(reverse: press.modifiers.contains(.shift))
                return .handled
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
                Text("This shortcut is already used by another app. The shortcut has been reset.")
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

    // MARK: - Shortcut Badge (toggle only, no pencil)

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

    private func setBadge(_ ks: KeyboardShortcuts.Shortcut) -> some View {
        let isFocused = focus.wrappedValue == .shortcutBadge(shortcut.id)
        let isEnabled = shortcut.isEnabled

        return Button {
            store.toggleEnabled(for: shortcut)
        } label: {
            Text(ks.description)
                .font(.system(size: 11, weight: .semibold))
                .strikethrough(!isEnabled)
                .foregroundStyle(isEnabled ? Color.accentColor : .secondary)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isEnabled ? Color.accentColor.opacity(0.125) : Color.secondary.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isFocused ? Color.accentColor.opacity(0.6)
                                : isEnabled ? Color.accentColor.opacity(0.25) : .clear,
                            lineWidth: isFocused ? 1.5 : 1
                        )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
        .focusEffectDisabled()
        .focused(focus, equals: .shortcutBadge(shortcut.id))
        .onKeyPress(.return) {
            store.toggleEnabled(for: shortcut)
            return .handled
        }
        .accessibilityIdentifier("shortcut-badge")
        .accessibilityLabel("Shortcut: \(ks.description)\(isEnabled ? "" : ", disabled")")
        .accessibilityHint("Press Enter to toggle shortcut")
        .help(isEnabled ? "Disable shortcut" : "Enable shortcut")
    }

    // MARK: - Edit Button (standalone, between badge and reset)

    @ViewBuilder
    private var editShortcutButton: some View {
        if hasShortcut, !isRecording {
            let isFocused = focus.wrappedValue == .shortcutEditButton(shortcut.id)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isRecording = true
                }
            } label: {
                Image(systemName: "pencil.line")
                    .font(.system(size: 10))
                    .foregroundStyle(isFocused ? Color.accentColor : .secondary)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.quaternary.opacity(0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isFocused ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .focusable()
            .focusEffectDisabled()
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
    }

    // MARK: - Not Set Badge

    private var notSetBadge: some View {
        let isFocused = focus.wrappedValue == .shortcutBadge(shortcut.id)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isRecording = true
            }
        } label: {
            HStack(spacing: 5) {
                Text("Not set")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isFocused ? .secondary : .tertiary)
                Image(systemName: "pencil.line")
                    .font(.system(size: 10))
                    .foregroundStyle(isFocused ? .secondary : .tertiary)
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isFocused ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
        .focusEffectDisabled()
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
        RecordingBadge(
            shortcut: shortcut,
            store: store,
            isRecording: $isRecording,
            onConflict: { conflictError = $0 },
            onRecordingCancelled: onRecordingCancelled
        )
    }

    // MARK: - Unset Shortcut Button

    @ViewBuilder
    private var unsetShortcutButton: some View {
        if hasShortcut {
            let isFocused = focus.wrappedValue == .dangerButton(shortcut.id)

            Button {
                store.unsetShortcut(for: shortcut)
                focus.wrappedValue = .shortcutBadge(shortcut.id)
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.orange)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isFocused ? Color.orange.opacity(0.6) : .clear, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .focusable()
            .focusEffectDisabled()
            .focused(focus, equals: .dangerButton(shortcut.id))
            .onKeyPress(.return) {
                store.unsetShortcut(for: shortcut)
                focus.wrappedValue = .shortcutBadge(shortcut.id)
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

    // MARK: - Delete App Button

    private var deleteAppButton: some View {
        let isFocused = focus.wrappedValue == .deleteButton(shortcut.id)

        return Button {
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
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isFocused ? Color.red.opacity(0.6) : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .focusable()
        .focusEffectDisabled()
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

    // MARK: - Cancel Edit Button

    private var cancelEditButton: some View {
        let isFocused = focus.wrappedValue == .cancelEdit(shortcut.id)

        return Button {
            onCancelEdit()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isFocused ? .primary : .secondary)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isFocused ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .focusable()
        .focusEffectDisabled()
        .focused(focus, equals: .cancelEdit(shortcut.id))
        .onKeyPress(.return) {
            onCancelEdit()
            return .handled
        }
        .accessibilityIdentifier("cancel-edit")
        .accessibilityLabel("Cancel editing")
        .help("Cancel editing")
    }
}
