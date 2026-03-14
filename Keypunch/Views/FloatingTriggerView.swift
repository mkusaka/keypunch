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

    @State private var hoveredIcon: String?
    @State private var isMenuExpanded = false
    @State private var tooltipWorkItem: DispatchWorkItem?

    private static let bgColor = Color(red: 0.10, green: 0.10, blue: 0.12)   // #1A1A1E
    private static let idleIconColor = Color(white: 0.42)                     // #6B6B70
    private static let activeIconColor = Color(white: 0.98)                   // #FAFAF9
    private static let dangerColor = Color(red: 0.91, green: 0.35, blue: 0.31) // #E85A4F
    private static let glowColor = Color(red: 0.39, green: 0.40, blue: 0.95)  // #6366F1

    var body: some View {
        VStack(spacing: 10) {
            // Keyboard trigger circle
            keyboardCircle

            // More button / expanded menu
            if isMenuExpanded {
                expandedMenu
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .top)))
            } else {
                ellipsisCircle
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .bottom)))
            }
        }
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

    // MARK: - Keyboard Circle

    private var keyboardCircle: some View {
        let isHovered = hoveredIcon == "keyboard"
        let showActive = isActive || isHovered

        return Button(action: onShowPanel) {
            Image(systemName: "keyboard")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(showActive ? Self.activeIconColor : Self.idleIconColor)
                .frame(width: 20, height: 20)
                .scaleEffect(isHovered ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: hoveredIcon)
        }
        .buttonStyle(.plain)
        .frame(width: 48, height: 48)
        .background(Self.bgColor)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(showActive ? 0.15 : 0.09), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 4)
        .shadow(
            color: showActive ? Self.glowColor.opacity(0.12) : .clear,
            radius: 40
        )
        .onHover { hovered in
            handleHover(id: "keyboard", tooltip: "Toggle Keypunch", isHovered: hovered)
        }
        .accessibilityIdentifier("trigger-button")
    }

    // MARK: - Ellipsis Circle (collapsed more button)

    private var ellipsisCircle: some View {
        let isHovered = hoveredIcon == "ellipsis"

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isMenuExpanded = true
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(isHovered ? Self.activeIconColor : Self.idleIconColor)
                .frame(width: 20, height: 20)
                .scaleEffect(isHovered ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: hoveredIcon)
        }
        .buttonStyle(.plain)
        .frame(width: 48, height: 48)
        .background(Self.bgColor)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 4)
        .onHover { hovered in
            if hovered {
                hoveredIcon = "ellipsis"
                withAnimation(.easeInOut(duration: 0.2)) {
                    isMenuExpanded = true
                }
            } else {
                if hoveredIcon == "ellipsis" { hoveredIcon = nil }
            }
        }
    }

    // MARK: - Expanded Menu

    private var expandedMenu: some View {
        VStack(spacing: 12) {
            menuIcon(
                id: "hide",
                systemName: "eye.slash",
                color: Self.activeIconColor,
                tooltip: "Hide Trigger",
                action: onHideTrigger
            )

            menuIcon(
                id: "power",
                systemName: isLoginItemEnabled ? "power.circle.fill" : "power",
                color: Self.activeIconColor,
                tooltip: isLoginItemEnabled ? "Disable Start at Login" : "Enable Start at Login",
                action: onToggleLoginItem
            )

            menuIcon(
                id: "quit",
                systemName: "rectangle.portrait.and.arrow.right",
                color: Self.dangerColor,
                tooltip: "Quit App",
                action: onQuit
            )
        }
        .padding(.vertical, 14)
        .frame(width: 48)
        .background(Self.bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 4)
        .shadow(color: Self.glowColor.opacity(0.12), radius: 40)
        .onHover { hovered in
            if !hovered {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isMenuExpanded = false
                }
                tooltipWorkItem?.cancel()
                onTooltipChanged?(nil)
            }
        }
    }

    // MARK: - Menu Icon Button

    private func menuIcon(
        id: String,
        systemName: String,
        color: Color,
        tooltip: String,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = hoveredIcon == id

        return Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(isHovered ? color : color.opacity(0.7))
                .frame(width: 18, height: 18)
                .scaleEffect(isHovered ? 1.2 : 1.0)
                .shadow(
                    color: isHovered ? color.opacity(0.3) : .clear,
                    radius: 8
                )
                .animation(.easeInOut(duration: 0.15), value: hoveredIcon)
        }
        .buttonStyle(.plain)
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
