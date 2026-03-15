import KeyboardShortcuts
import SwiftUI

struct RecordingBadge: View {
    let shortcut: AppShortcut
    let store: ShortcutStore
    @Binding var isRecording: Bool
    let onConflict: (String) -> Void
    let onRecordingCancelled: () -> Void

    var body: some View {
        ZStack {
            ShortcutCaptureRepresentable(
                name: shortcut.keyboardShortcutName,
                onShortcutSet: { newShortcut in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isRecording = false
                    }
                    if store.isShortcutConflicting(newShortcut, excluding: shortcut.keyboardShortcutName) {
                        KeyboardShortcuts.reset(shortcut.keyboardShortcutName)
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
            .frame(width: 1, height: 1)
            .opacity(0)

            HStack(spacing: 5) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                Text("Record")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.orange)

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isRecording = false
                    }
                    onRecordingCancelled()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.orange)
                        .frame(width: 16, height: 16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.19))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel recording")
                .help("Cancel recording")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.125))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
        .accessibilityIdentifier("recording-badge")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recording shortcut. Press a key combination or Escape to cancel.")
    }
}
