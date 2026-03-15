import KeyboardShortcuts
import SwiftUI

struct SetBadge: View {
    let shortcut: AppShortcut
    let currentShortcut: KeyboardShortcuts.Shortcut
    let store: ShortcutStore
    @Binding var isRecording: Bool
    var focus: FocusState<PanelFocus?>.Binding

    private var isEnabled: Bool {
        shortcut.isEnabled
    }

    private var badgeFocused: Bool {
        focus.wrappedValue == .shortcutBadge(shortcut.id)
    }

    private var editBtnFocused: Bool {
        focus.wrappedValue == .shortcutEditButton(shortcut.id)
    }

    var body: some View {
        HStack(spacing: 5) {
            Button {
                store.toggleEnabled(for: shortcut)
            } label: {
                Text(currentShortcut.description)
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
                    .frame(width: 16, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(editBtnFocused ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1.5)
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
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isEnabled ? Color.accentColor.opacity(0.125) : Color.secondary.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    (badgeFocused || editBtnFocused) ? Color.accentColor.opacity(0.6)
                        : isEnabled ? Color.accentColor.opacity(0.25) : .clear,
                    lineWidth: (badgeFocused || editBtnFocused) ? 1.5 : 1
                )
        )
        .focusable()
        .focusEffectDisabled()
        .focused(focus, equals: .shortcutBadge(shortcut.id))
        .onKeyPress(.return) {
            withAnimation(.easeInOut(duration: 0.15)) {
                isRecording = true
            }
            return .handled
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Shortcut: \(currentShortcut.description)\(isEnabled ? "" : ", disabled")")
        .accessibilityHint("Press Enter to re-record shortcut")
    }
}
