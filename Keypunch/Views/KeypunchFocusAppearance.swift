import SwiftUI

enum KeypunchFocusTone {
    case accent
    case warning
    case destructive
    case neutral

    var outerRing: Color {
        switch self {
        case .accent:
            .accentColor.opacity(0.26)
        case .warning:
            .orange.opacity(0.3)
        case .destructive:
            .red.opacity(0.28)
        case .neutral:
            .primary.opacity(0.2)
        }
    }

    var innerRing: Color {
        switch self {
        case .accent:
            .accentColor.opacity(0.95)
        case .warning:
            .orange.opacity(0.95)
        case .destructive:
            .red.opacity(0.95)
        case .neutral:
            .primary.opacity(0.9)
        }
    }

    var glow: Color {
        switch self {
        case .accent:
            .accentColor.opacity(0.16)
        case .warning:
            .orange.opacity(0.18)
        case .destructive:
            .red.opacity(0.16)
        case .neutral:
            .primary.opacity(0.08)
        }
    }
}

private struct KeypunchFocusRing: ViewModifier {
    let isFocused: Bool
    let cornerRadius: CGFloat
    let tone: KeypunchFocusTone

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius + 2)
                    .stroke(isFocused ? tone.outerRing : .clear, lineWidth: 4)
                    .padding(-3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isFocused ? tone.innerRing : .clear, lineWidth: 2)
            )
            .shadow(color: isFocused ? tone.glow : .clear, radius: 10)
    }
}

extension View {
    func keypunchFocusRing(
        isFocused: Bool,
        cornerRadius: CGFloat,
        tone: KeypunchFocusTone
    ) -> some View {
        modifier(KeypunchFocusRing(
            isFocused: isFocused,
            cornerRadius: cornerRadius,
            tone: tone
        ))
    }
}
