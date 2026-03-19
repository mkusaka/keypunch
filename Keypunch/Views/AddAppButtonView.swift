import SwiftUI

struct AddAppButton: View {
    let store: ShortcutStore
    var focus: FocusState<PanelFocus?>.Binding
    @Binding var duplicateAppName: String
    @Binding var showDuplicateAlert: Bool
    var picker: AppFilePicking = NSOpenPanelAppPicker()
    var onAddSuccess: (AppShortcut) -> Void = { _ in }

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
                    .fill(isFocused ? Color.accentColor.opacity(0.12) : Color.clear)
            )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isFocused ? Color.accentColor.opacity(0.28) : Color.secondary.opacity(0.2),
                    lineWidth: 1
                )
        )
        .keypunchFocusRing(
            isFocused: isFocused,
            cornerRadius: 10,
            tone: .accent
        )
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
        case let .success(shortcut):
            onAddSuccess(shortcut)
        case let .duplicate(name):
            duplicateAppName = name
            showDuplicateAlert = true
        }
    }
}
