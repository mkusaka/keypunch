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
                    RoundedRectangle(cornerRadius: 6).fill(backgroundStyle)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isFocused ? color.opacity(0.6) : .clear,
                            lineWidth: 1.5
                        )
                )
        }
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
            AnyShapeStyle(.quaternary.opacity(0.3))
        } else {
            AnyShapeStyle(color.opacity(color == .red ? 0.09 : 0.15))
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
}
