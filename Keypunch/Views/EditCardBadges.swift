import KeypunchKeyboardShortcuts
import SwiftUI

struct SetBadgeButton: View {
    let shortcut: AppShortcut
    let store: ShortcutStore
    let ks: KeyboardShortcutsClient.Shortcut
    var focus: FocusState<PanelFocus?>.Binding

    private var isFocused: Bool {
        focus.wrappedValue == .shortcutBadge(shortcut.id)
    }

    var body: some View {
        Button {
            store.toggleEnabled(for: shortcut)
        } label: {
            Text(ks.description)
                .font(.system(size: 11, weight: .semibold))
                .strikethrough(!shortcut.isEnabled)
                .foregroundStyle(shortcut.isEnabled ? Color.accentColor : .secondary)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            shortcut.isEnabled
                                ? Color.accentColor.opacity(isFocused ? 0.2 : 0.125)
                                : Color.secondary.opacity(isFocused ? 0.16 : 0.1)
                        )
                )
                .contentShape(Rectangle())
        }
        .keypunchFocusRing(
            isFocused: isFocused,
            cornerRadius: 6,
            tone: shortcut.isEnabled ? .accent : .neutral
        )
        .buttonStyle(.plain)
        .focusable()
        .focusEffectDisabled()
        .focused(focus, equals: .shortcutBadge(shortcut.id))
        .onKeyPress(.return) {
            store.toggleEnabled(for: shortcut)
            return .handled
        }
        .accessibilityIdentifier("shortcut-badge")
        .accessibilityLabel(
            "Shortcut: \(ks.description)\(shortcut.isEnabled ? "" : ", disabled")"
        )
        .accessibilityHint("Press Enter to toggle shortcut")
        .help(shortcut.isEnabled ? "Disable shortcut" : "Enable shortcut")
    }
}

struct NotSetBadgeButton: View {
    let shortcut: AppShortcut
    @Binding var isRecording: Bool
    var focus: FocusState<PanelFocus?>.Binding

    private var isFocused: Bool {
        focus.wrappedValue == .shortcutBadge(shortcut.id)
    }

    var body: some View {
        Button {
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
                    .fill(notSetBackgroundStyle)
            )
            .contentShape(Rectangle())
        }
        .keypunchFocusRing(
            isFocused: isFocused,
            cornerRadius: 6,
            tone: .accent
        )
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
}

struct EditShortcutButton: View {
    let shortcut: AppShortcut
    @Binding var isRecording: Bool
    var focus: FocusState<PanelFocus?>.Binding

    private var isFocused: Bool {
        focus.wrappedValue == .shortcutEditButton(shortcut.id)
    }

    var body: some View {
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
                        .fill(editShortcutBackgroundStyle)
                )
        }
        .keypunchFocusRing(
            isFocused: isFocused,
            cornerRadius: 6,
            tone: .accent
        )
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

    private var editShortcutBackgroundStyle: AnyShapeStyle {
        if isFocused {
            AnyShapeStyle(Color.accentColor.opacity(0.16))
        } else {
            AnyShapeStyle(.quaternary.opacity(0.3))
        }
    }
}

private extension NotSetBadgeButton {
    var notSetBackgroundStyle: AnyShapeStyle {
        if isFocused {
            AnyShapeStyle(Color.accentColor.opacity(0.12))
        } else {
            AnyShapeStyle(.quaternary.opacity(0.3))
        }
    }
}
