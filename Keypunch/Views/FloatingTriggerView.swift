import SwiftUI

struct FloatingTriggerView: View {
    var store: ShortcutStore
    var isActive: Bool
    var onShowPanel: () -> Void = {}
    var onQuit: () -> Void = {}
    var onHideTrigger: () -> Void = {}
    var onToggleLoginItem: () -> Void = {}
    var isLoginItemEnabled: Bool = false

    @State private var hoveredIcon: String?
    @State private var tooltipText: String?
    @State private var tooltipWorkItem: DispatchWorkItem?

    private func iconColor(for id: String) -> Color {
        if hoveredIcon == id || isActive {
            return Color(white: 0.98)
        }
        return Color(white: 0.42)
    }

    private func isIconHovered(_ id: String) -> Bool {
        hoveredIcon == id
    }

    var body: some View {
        VStack(spacing: 12) {
            triggerButton(
                id: "keyboard",
                systemName: "keyboard",
                fontSize: 16,
                tooltip: "Show Keypunch",
                action: onShowPanel
            )
            .accessibilityIdentifier("trigger-button")

            triggerButton(
                id: "quit",
                systemName: "rectangle.portrait.and.arrow.right",
                fontSize: 14,
                tooltip: "Quit App",
                action: onQuit
            )

            triggerButton(
                id: "hide",
                systemName: "eye.slash",
                fontSize: 14,
                tooltip: "Hide Trigger",
                action: onHideTrigger
            )

            triggerButton(
                id: "power",
                systemName: "power",
                fontSize: 14,
                tooltip: isLoginItemEnabled ? "Disable Start at Login" : "Enable Start at Login",
                action: onToggleLoginItem
            )
        }
        .frame(width: 48, height: 160)
        .background(Color(red: 0.10, green: 0.10, blue: 0.12)) // #1A1A1E
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(isActive ? 0.15 : 0.09), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 4)
        .shadow(
            color: isActive ? Color(red: 0.39, green: 0.40, blue: 0.95).opacity(0.12) : .clear,
            radius: 40
        )
        .overlay(alignment: .leading) {
            if let text = tooltipText {
                Text(text)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .fixedSize()
                    .offset(x: -8)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .offset(x: 8)
                    .transition(.opacity.combined(with: .offset(x: -4)))
                    .animation(.easeInOut(duration: 0.15), value: tooltipText)
            }
        }
    }

    private func triggerButton(
        id: String,
        systemName: String,
        fontSize: CGFloat,
        tooltip: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(iconColor(for: id))
                .font(.system(size: fontSize, weight: .regular))
                .scaleEffect(isIconHovered(id) ? 1.2 : 1.0)
                .shadow(
                    color: isIconHovered(id) ? Color.white.opacity(0.3) : .clear,
                    radius: 8
                )
                .animation(.easeInOut(duration: 0.15), value: hoveredIcon)
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            if isHovered {
                hoveredIcon = id
                tooltipWorkItem?.cancel()
                let workItem = DispatchWorkItem { [id] in
                    if hoveredIcon == id {
                        withAnimation {
                            tooltipText = tooltip
                        }
                    }
                }
                tooltipWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
            } else {
                if hoveredIcon == id {
                    hoveredIcon = nil
                }
                tooltipWorkItem?.cancel()
                withAnimation {
                    tooltipText = nil
                }
            }
        }
    }
}
