import KeyboardShortcuts
import SwiftUI

struct SetBadge: View {
    let shortcut: AppShortcut
    let currentShortcut: KeyboardShortcuts.Shortcut
    let store: ShortcutStore
    var focus: FocusState<PanelFocus?>.Binding

    private var isEnabled: Bool {
        shortcut.isEnabled
    }

    private var isFocused: Bool {
        focus.wrappedValue == .shortcutBadge(shortcut.id)
    }

    var body: some View {
        Button {
            store.toggleEnabled(for: shortcut)
        } label: {
            Text(currentShortcut.description)
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
        .accessibilityLabel("Shortcut: \(currentShortcut.description)\(isEnabled ? "" : ", disabled")")
        .accessibilityHint("Press Enter to toggle shortcut")
        .help(isEnabled ? "Disable shortcut" : "Enable shortcut")
    }
}
