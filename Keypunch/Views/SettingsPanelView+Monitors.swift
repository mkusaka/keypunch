import AppKit
import KeypunchKeyboardShortcuts
import SwiftUI

// MARK: - NSEvent Monitors for Tab Loop and Arrow Keys

extension SettingsPanelView {
    func makeTabMonitor(
        focusBinding: FocusState<PanelFocus?>.Binding,
        shortcuts: [AppShortcut],
        targetShortcutID: UUID?
    ) -> Any? {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let targetShortcutID else { return event }
            guard event.keyCode == 48 else { return event }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !flags.contains(.command),
                  !flags.contains(.control),
                  !flags.contains(.option),
                  !flags.contains(.function),
                  !flags.contains(.capsLock),
                  !flags.contains(.numericPad)
            else {
                return event
            }

            guard let shortcut = shortcuts.first(where: { $0.id == targetShortcutID }) else {
                return event
            }

            var targets: [PanelFocus] = [.shortcutBadge(targetShortcutID)]
            if KeyboardShortcutsClient.getShortcut(for: shortcut.keyboardShortcutName) != nil {
                targets.append(.shortcutEditButton(targetShortcutID))
                targets.append(.dangerButton(targetShortcutID))
            }
            targets.append(.deleteButton(targetShortcutID))
            targets.append(.cancelEdit(targetShortcutID))
            guard !targets.isEmpty else { return event }

            let reverse = flags.contains(.shift)
            let currentIndex = targets.firstIndex(where: { $0 == focusBinding.wrappedValue })
            let nextIndex = if let current = currentIndex {
                reverse
                    ? (current - 1 + targets.count) % targets.count
                    : (current + 1) % targets.count
            } else {
                reverse ? targets.count - 1 : 0
            }

            withAnimation(.easeInOut(duration: 0.15)) {
                focusBinding.wrappedValue = targets[nextIndex]
            }
            return nil
        }
    }

    func makeArrowMonitor(
        focusBinding: FocusState<PanelFocus?>.Binding,
        shortcuts: [AppShortcut]
    ) -> Any? {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Down arrow = keyCode 125, Up arrow = keyCode 126
            guard event.keyCode == 125 || event.keyCode == 126 else { return event }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !flags.contains(.command),
                  !flags.contains(.control),
                  !flags.contains(.option)
            else { return event }

            if event.keyCode == 125 {
                if let first = shortcuts.first {
                    focusBinding.wrappedValue = .row(first.id)
                } else {
                    focusBinding.wrappedValue = .addApp
                }
            } else {
                focusBinding.wrappedValue = .addApp
            }
            return nil
        }
    }
}
