import SwiftUI

struct FloatingTriggerView: View {
    var store: ShortcutStore
    var isActive: Bool
    var onShowPanel: () -> Void = {}
    var onQuit: () -> Void = {}
    var onHideTrigger: () -> Void = {}
    var onToggleLoginItem: () -> Void = {}
    var isLoginItemEnabled: Bool = false

    private var iconColor: Color {
        isActive ? Color(white: 0.98) : Color(white: 0.42) // #FAFAF9 / #6B6B70
    }

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onShowPanel) {
                Image(systemName: "keyboard")
                    .foregroundStyle(iconColor)
                    .font(.system(size: 16, weight: .regular))
            }
            .buttonStyle(.plain)
            .help("Show Keypunch")
            .accessibilityIdentifier("trigger-button")

            Button(action: onQuit) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(iconColor)
                    .font(.system(size: 14, weight: .regular))
            }
            .buttonStyle(.plain)
            .help("Quit App")

            Button(action: onHideTrigger) {
                Image(systemName: "eye.slash")
                    .foregroundStyle(iconColor)
                    .font(.system(size: 14, weight: .regular))
            }
            .buttonStyle(.plain)
            .help("Hide Trigger")

            Button(action: onToggleLoginItem) {
                Image(systemName: "power")
                    .foregroundStyle(iconColor)
                    .font(.system(size: 14, weight: .regular))
            }
            .buttonStyle(.plain)
            .help(isLoginItemEnabled ? "Disable Start at Login" : "Enable Start at Login")
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
    }
}
