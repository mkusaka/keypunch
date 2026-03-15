import SwiftUI

struct AddAppButton: View {
    let store: ShortcutStore
    var focus: FocusState<PanelFocus?>.Binding
    @Binding var duplicateAppName: String
    @Binding var showDuplicateAlert: Bool
    var picker: AppFilePicking = NSOpenPanelAppPicker()

    private var isFocused: Bool {
        focus.wrappedValue == .addApp
    }

    var body: some View {
        Button {
            addShortcut()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14))
                Text("Add App")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isFocused ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isFocused ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.2),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .focusable()
        .focusEffectDisabled()
        .focused(focus, equals: .addApp)
        .onKeyPress(.return) {
            addShortcut()
            return .handled
        }
        .accessibilityIdentifier("add-app-button")
        .accessibilityLabel("Add App")
        .accessibilityHint("Opens a file picker to add an application")
        .help("Add application")
    }

    private func addShortcut() {
        guard let url = picker.pickApplication() else { return }

        switch store.addShortcutFromURL(url) {
        case .success:
            break
        case let .duplicate(name):
            duplicateAppName = name
            showDuplicateAlert = true
        }
    }
}
