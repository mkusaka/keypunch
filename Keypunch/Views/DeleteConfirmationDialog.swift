import SwiftUI

struct DeleteConfirmationDialog: View {
    let shortcut: AppShortcut
    var focus: FocusState<PanelFocus?>.Binding
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)

            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.red.opacity(0.08))
                        .frame(width: 48, height: 48)
                    Image(systemName: "trash")
                        .font(.system(size: 20))
                        .foregroundStyle(.red)
                }

                Text("Remove \(shortcut.name)?")
                    .font(.system(size: 16, weight: .semibold))

                Text("This will remove the shortcut and\nits key binding. This can't be undone.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(width: 240)

                HStack(spacing: 8) {
                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .buttonStyle(.bordered)
                    .focusable()
                    .focusEffectDisabled()
                    .focused(focus, equals: .dialogCancel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                focus.wrappedValue == .dialogCancel ? Color.accentColor.opacity(0.6) : .clear,
                                lineWidth: 1.5
                            )
                    )
                    .onKeyPress(.return) {
                        onCancel()
                        return .handled
                    }
                    .onKeyPress(phases: .down) { press in
                        guard press.key == .tab else { return .ignored }
                        moveFocus(reverse: press.modifiers.contains(.shift))
                        return .handled
                    }
                    .accessibilityIdentifier("dialog-cancel")
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Dismisses the dialog and keeps \(shortcut.name)")

                    Button(role: .destructive) {
                        onConfirm()
                    } label: {
                        Text("Remove")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .focusable()
                    .focusEffectDisabled()
                    .focused(focus, equals: .dialogRemove)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                focus.wrappedValue == .dialogRemove ? Color.red.opacity(0.6) : .clear,
                                lineWidth: 1.5
                            )
                    )
                    .onKeyPress(.return) {
                        onConfirm()
                        return .handled
                    }
                    .onKeyPress(phases: .down) { press in
                        guard press.key == .tab else { return .ignored }
                        moveFocus(reverse: press.modifiers.contains(.shift))
                        return .handled
                    }
                    .accessibilityIdentifier("dialog-remove")
                    .accessibilityLabel("Remove \(shortcut.name)")
                    .accessibilityHint("Permanently removes this app and its shortcut")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )
            .padding(24)
            .accessibilityAddTraits(.isModal)
            .accessibilityLabel("Remove \(shortcut.name) confirmation")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("delete-confirmation-dialog")
    }

    private func moveFocus(reverse: Bool) {
        let targets: [PanelFocus] = [.dialogCancel, .dialogRemove]
        let currentIndex = targets.firstIndex(of: focus.wrappedValue ?? .dialogCancel) ?? 0
        let nextIndex = reverse
            ? (currentIndex - 1 + targets.count) % targets.count
            : (currentIndex + 1) % targets.count
        focus.wrappedValue = targets[nextIndex]
    }
}
