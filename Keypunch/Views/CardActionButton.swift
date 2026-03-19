import SwiftUI

struct CardActionButton: View {
    let icon: String
    let color: Color
    let focusTarget: PanelFocus
    let identifier: String
    let label: String
    var hint: String?
    let helpText: String
    var focus: FocusState<PanelFocus?>.Binding
    let action: () -> Void

    private var isFocused: Bool {
        focus.wrappedValue == focusTarget
    }

    private var isAccentColor: Bool {
        color == .accentColor
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: isAccentColor ? .medium : .regular))
                .foregroundStyle(foregroundStyle)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(backgroundStyle)
                )
        }
        .keypunchFocusRing(
            isFocused: isFocused,
            cornerRadius: 6,
            tone: focusTone
        )
        .buttonStyle(.plain)
        .focusable()
        .focusEffectDisabled()
        .focused(focus, equals: focusTarget)
        .onKeyPress(.return) { action(); return .handled }
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
        .help(helpText)
    }

    private var backgroundStyle: AnyShapeStyle {
        if isAccentColor {
            if isFocused {
                AnyShapeStyle(Color.primary.opacity(0.14))
            } else {
                AnyShapeStyle(.quaternary.opacity(0.3))
            }
        } else {
            AnyShapeStyle(color.opacity(isFocused ? 0.22 : color == .red ? 0.09 : 0.15))
        }
    }

    private var foregroundStyle: AnyShapeStyle {
        if isAccentColor {
            if isFocused {
                AnyShapeStyle(.primary)
            } else {
                AnyShapeStyle(.secondary)
            }
        } else {
            AnyShapeStyle(color)
        }
    }

    private var focusTone: KeypunchFocusTone {
        if color == .red {
            .destructive
        } else if color == .orange {
            .warning
        } else if isAccentColor {
            .neutral
        } else {
            .accent
        }
    }
}
