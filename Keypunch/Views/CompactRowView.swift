import KeyboardShortcuts
import SwiftUI

struct CompactRow: View {
    let shortcut: AppShortcut
    let store: ShortcutStore
    let isHovered: Bool
    var focus: FocusState<PanelFocus?>.Binding
    let onLaunch: () -> Void
    let onEdit: () -> Void

    private var rowFocused: Bool {
        focus.wrappedValue == .row(shortcut.id)
    }

    private var editBtnFocused: Bool {
        focus.wrappedValue == .editButton(shortcut.id)
    }

    private var isHighlighted: Bool {
        isHovered || rowFocused || editBtnFocused
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                onLaunch()
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

                    compactShortcutBadge
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable()
            .focusEffectDisabled()
            .focused(focus, equals: .row(shortcut.id))
            .onKeyPress(.return) {
                onLaunch()
                return .handled
            }

            EditPencilButton(
                isHighlighted: isHighlighted,
                isFocused: editBtnFocused
            ) {
                onEdit()
            }
            .focusable()
            .focusEffectDisabled()
            .focused(focus, equals: .editButton(shortcut.id))
            .onKeyPress(.return) {
                onEdit()
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Press Enter to launch \(shortcut.name)")
        .id("\(shortcut.id)-launch-\(store.shortcutKeysVersion)")
    }

    // MARK: - Badge

    @ViewBuilder
    private var compactShortcutBadge: some View {
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

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let shortcutDesc: String = if let ks = KeyboardShortcuts.getShortcut(for: shortcut.keyboardShortcutName) {
            shortcut.isEnabled ? "Shortcut: \(ks.description)" : "Shortcut: \(ks.description), disabled"
        } else {
            "No shortcut set"
        }
        return "\(shortcut.name), \(shortcut.appDirectory), \(shortcutDesc)"
    }
}
