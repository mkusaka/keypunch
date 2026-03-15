import SwiftUI

struct DuplicateAlertDialog: View {
    let appName: String
    var focus: FocusState<PanelFocus?>.Binding
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)

            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.orange.opacity(0.08))
                        .frame(width: 48, height: 48)
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 20))
                        .foregroundStyle(.orange)
                }

                Text("Duplicate Application")
                    .font(.system(size: 16, weight: .semibold))

                Text("\(appName) has already been added.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 240)

                Button {
                    onDismiss()
                } label: {
                    Text("OK")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(.borderedProminent)
                .focusable()
                .focusEffectDisabled()
                .focused(focus, equals: .dialogOK)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            focus.wrappedValue == .dialogOK ? Color.accentColor.opacity(0.6) : .clear,
                            lineWidth: 1.5
                        )
                )
                .onKeyPress(.return) {
                    onDismiss()
                    return .handled
                }
                .accessibilityIdentifier("dialog-ok")
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
            .accessibilityLabel("Duplicate application alert")
        }
        .accessibilityIdentifier("duplicate-alert-dialog")
    }
}
