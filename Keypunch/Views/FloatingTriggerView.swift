import SwiftUI

struct FloatingTriggerView: View {
    var store: ShortcutStore
    var isActive: Bool
    var onShowPanel: () -> Void = {}
    var onQuit: () -> Void = {}
    var onHideTrigger: () -> Void = {}
    var onToggleLoginItem: () -> Void = {}
    var isLoginItemEnabled: Bool = false
    var onTooltipChanged: ((String?) -> Void)?
    var onDrag: ((CGSize) -> Void)?
    var onDragEnd: (() -> Void)?

    enum FocusField: Hashable {
        case keyboard, hide, power, quit
    }

    @State private var hoveredIcon: String?
    @State private var tooltipWorkItem: DispatchWorkItem?
    @FocusState private var focusedField: FocusField?

    private static let bgColor = Color(red: 0.10, green: 0.10, blue: 0.12)   // #1A1A1E
    private static let idleIconColor = Color(white: 0.42)                     // #6B6B70
    private static let activeIconColor = Color(white: 0.98)                   // #FAFAF9
    private static let dangerColor = Color(red: 0.91, green: 0.35, blue: 0.31) // #E85A4F
    private static let glowColor = Color(red: 0.39, green: 0.40, blue: 0.95)  // #6366F1
    private static let focusRingColor = Color(red: 0.39, green: 0.40, blue: 0.95) // #6366F1

    var body: some View {
        VStack(spacing: 12) {
            triggerIcon(
                id: "keyboard",
                focus: .keyboard,
                systemName: "keyboard",
                color: Self.activeIconColor,
                tooltip: "Toggle Keypunch",
                isHighlighted: isActive,
                action: onShowPanel
            )
            .accessibilityIdentifier("trigger-button")

            triggerIcon(
                id: "hide",
                focus: .hide,
                systemName: "eye.slash",
                color: Self.activeIconColor,
                tooltip: "Hide Trigger",
                action: onHideTrigger
            )
            .accessibilityIdentifier("menu-hide")

            triggerIcon(
                id: "power",
                focus: .power,
                systemName: isLoginItemEnabled ? "power.circle.fill" : "power",
                color: Self.activeIconColor,
                tooltip: isLoginItemEnabled ? "Disable Start at Login" : "Enable Start at Login",
                action: onToggleLoginItem
            )
            .accessibilityIdentifier("menu-power")

            triggerIcon(
                id: "quit",
                focus: .quit,
                systemName: "rectangle.portrait.and.arrow.right",
                color: Self.dangerColor,
                tooltip: "Quit App",
                action: onQuit
            )
            .accessibilityIdentifier("menu-quit")
        }
        .padding(.vertical, 14)
        .frame(width: 48)
        .background(Self.bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(isActive ? 0.15 : 0.09), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 4)
        .shadow(
            color: isActive ? Self.glowColor.opacity(0.12) : .clear,
            radius: 40
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    onDrag?(value.translation)
                }
                .onEnded { _ in
                    onDragEnd?()
                }
        )
    }

    // MARK: - Trigger Icon Button

    private func triggerIcon(
        id: String,
        focus: FocusField,
        systemName: String,
        color: Color,
        tooltip: String,
        isHighlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = hoveredIcon == id
        let isFocused = focusedField == focus
        let showActive = isHighlighted || isHovered || isFocused

        return Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(showActive ? color : color.opacity(0.7))
                .frame(width: 18, height: 18)
                .scaleEffect(isHovered ? 1.2 : 1.0)
                .shadow(
                    color: isHovered ? color.opacity(0.3) : .clear,
                    radius: 8
                )
                .animation(.easeInOut(duration: 0.15), value: hoveredIcon)
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focusedField, equals: focus)
        .onKeyPress(.return) {
            action()
            return .handled
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isFocused ? Self.focusRingColor.opacity(0.6) : .clear, lineWidth: 1.5)
                .padding(-2)
        )
        .onHover { hovered in
            handleHover(id: id, tooltip: tooltip, isHovered: hovered)
        }
    }

    // MARK: - Hover Helper

    private func handleHover(id: String, tooltip: String, isHovered: Bool) {
        if isHovered {
            hoveredIcon = id
            tooltipWorkItem?.cancel()
            let workItem = DispatchWorkItem { [id] in
                if hoveredIcon == id {
                    onTooltipChanged?(tooltip)
                }
            }
            tooltipWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        } else {
            if hoveredIcon == id {
                hoveredIcon = nil
            }
            tooltipWorkItem?.cancel()
            onTooltipChanged?(nil)
        }
    }
}
