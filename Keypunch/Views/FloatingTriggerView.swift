import SwiftUI

struct FloatingTriggerView: View {
    var store: ShortcutStore
    var isActive: Bool
    var onTap: () -> Void = {}

    private static let dotColors: [Color] = [
        Color(red: 0.39, green: 0.40, blue: 0.95), // #6366F1
        Color(red: 0.20, green: 0.84, blue: 0.51), // #32D583
        Color(red: 0.91, green: 0.35, blue: 0.31), // #E85A4F
    ]

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: "keyboard")
                    .foregroundStyle(isActive ? .white : Color(white: 0.42))
                    .font(.system(size: 16))

                ForEach(store.shortcuts.prefix(3).indices, id: \.self) { i in
                    Circle()
                        .fill(Self.dotColors[i % Self.dotColors.count])
                        .frame(width: isActive ? 8 : 6, height: isActive ? 8 : 6)
                        .shadow(
                            color: isActive ? Self.dotColors[i % Self.dotColors.count].opacity(0.5) : .clear,
                            radius: 8
                        )
                }
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
        .buttonStyle(.plain)
        .accessibilityIdentifier("trigger-button")
    }
}
