import KeypunchKeyboardShortcuts
import SwiftUI

struct RecordingBadge: View {
    let shortcut: AppShortcut
    let store: ShortcutStore
    @Binding var isRecording: Bool
    var focus: FocusState<PanelFocus?>.Binding
    let onConflict: (String) -> Void
    let onRecordingCancelled: () -> Void

    private var isFocused: Bool {
        focus.wrappedValue == .shortcutBadge(shortcut.id)
    }

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                Text("Record")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.orange)
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.orange.opacity(0.125))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isFocused ? Color.orange.opacity(0.6) : Color.orange.opacity(0.25),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .focusable()
        .focusEffectDisabled()
        .focused(focus, equals: .shortcutBadge(shortcut.id))
        .onKeyPress(.return) {
            .handled
        }
        .background(
            ShortcutCaptureRepresentable(
                name: shortcut.keyboardShortcutName,
                isCaptureActive: isFocused,
                onShortcutSet: { newShortcut in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isRecording = false
                    }
                    if store.isShortcutConflicting(newShortcut, excluding: shortcut.keyboardShortcutName) {
                        KeyboardShortcutsClient.reset(shortcut.keyboardShortcutName)
                        onConflict("Conflict")
                    }
                },
                onRecordingEnd: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isRecording = false
                    }
                    onRecordingCancelled()
                }
            )
            .frame(width: 0, height: 0)
            .opacity(0)
        )
        .accessibilityIdentifier("recording-badge")
        .accessibilityLabel("Recording shortcut. Press a key combination or Escape to cancel.")
    }
}
