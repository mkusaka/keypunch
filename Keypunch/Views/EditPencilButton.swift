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
                        .fill(isFocused
                            ? AnyShapeStyle(Color.accentColor.opacity(0.18))
                            : isHovered
                            ? AnyShapeStyle(Color.accentColor.opacity(0.12))
                            : AnyShapeStyle(.quaternary.opacity(0.3)))
                )
        }
        .keypunchFocusRing(
            isFocused: isFocused,
            cornerRadius: 6,
            tone: .accent
        )
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
