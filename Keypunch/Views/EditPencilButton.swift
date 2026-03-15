import SwiftUI

struct EditPencilButton: View {
    let isHighlighted: Bool
    let isFocused: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 11))
                .foregroundStyle((isHighlighted || isHovered || isFocused) ? .secondary : .quaternary)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? AnyShapeStyle(Color.accentColor.opacity(0.12)) :
                            AnyShapeStyle(.quaternary.opacity(0.3)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isFocused ? Color.accentColor.opacity(0.6) : isHovered ? Color.accentColor
                                .opacity(0.3) : .clear,
                            lineWidth: isFocused ? 1.5 : 1
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
