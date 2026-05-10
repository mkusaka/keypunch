import AppKit
import KeypunchKeyboardShortcuts
import SwiftUI

// MARK: - NSEvent Monitors for Tab Loop and Arrow Keys

extension SettingsPanelView {
    func makeTabMonitor(
        focusBinding: FocusState<PanelFocus?>.Binding,
        shortcutsProvider: @escaping @MainActor () -> [AppShortcut],
        targetShortcutIDProvider: @escaping @MainActor () -> UUID?
    ) -> Any? {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
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

            let handled = MainActor.assumeIsolated {
                let shortcuts = shortcutsProvider()
                let targets: [PanelFocus]
                if let targetShortcutID = targetShortcutIDProvider() {
                    guard let shortcut = shortcuts.first(where: { $0.id == targetShortcutID }) else {
                        return false
                    }

                    var editTargets: [PanelFocus] = [.shortcutBadge(targetShortcutID)]
                    if KeyboardShortcutsClient.getShortcut(for: shortcut.keyboardShortcutName) != nil {
                        editTargets.append(.shortcutEditButton(targetShortcutID))
                        editTargets.append(.dangerButton(targetShortcutID))
                    }
                    editTargets.append(.deleteButton(targetShortcutID))
                    editTargets.append(.cancelEdit(targetShortcutID))
                    targets = editTargets
                } else {
                    targets = Self.tabTargets(for: shortcuts)
                }
                guard !targets.isEmpty else { return false }

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
                return true
            }
            return handled ? nil : event
        }
    }

    func makeArrowMonitor(
        focusBinding: FocusState<PanelFocus?>.Binding,
        shortcutsProvider: @escaping @MainActor () -> [AppShortcut]
    ) -> Any? {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Down arrow = keyCode 125, Up arrow = keyCode 126
            guard event.keyCode == 125 || event.keyCode == 126 else { return event }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !flags.contains(.command),
                  !flags.contains(.control),
                  !flags.contains(.option)
            else { return event }

            let handled = MainActor.assumeIsolated {
                let shortcuts = shortcutsProvider()
                moveVerticalFocus(
                    down: event.keyCode == 125,
                    focusBinding: focusBinding,
                    shortcuts: shortcuts
                )
                return true
            }
            return handled ? nil : event
        }
    }

    func makeActivationMonitor(
        focusBinding: FocusState<PanelFocus?>.Binding,
        shortcutsProvider: @escaping @MainActor () -> [AppShortcut],
        onLaunch: @escaping @MainActor (AppShortcut) -> Void,
        onEdit: @escaping @MainActor (AppShortcut) -> Void
    ) -> Any? {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Return = keyCode 36, keypad Enter = keyCode 76
            guard event.keyCode == 36 || event.keyCode == 76 else { return event }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !flags.contains(.command),
                  !flags.contains(.control),
                  !flags.contains(.option)
            else { return event }

            let handled = MainActor.assumeIsolated {
                let shortcuts = shortcutsProvider()
                switch focusBinding.wrappedValue {
                case let .row(id):
                    guard let shortcut = shortcuts.first(where: { $0.id == id }) else { return false }
                    onLaunch(shortcut)
                    return true
                case let .editButton(id):
                    guard let shortcut = shortcuts.first(where: { $0.id == id }) else { return false }
                    onEdit(shortcut)
                    return true
                default:
                    return false
                }
            }
            return handled ? nil : event
        }
    }

    private func moveVerticalFocus(
        down: Bool,
        focusBinding: FocusState<PanelFocus?>.Binding,
        shortcuts: [AppShortcut]
    ) {
        guard let current = focusBinding.wrappedValue else {
            focusBinding.wrappedValue = down
                ? (shortcuts.first.map { .row($0.id) } ?? .addApp)
                : .addApp
            return
        }

        let currentPosition: Int? = if current == .addApp {
            shortcuts.count
        } else if let appID = current.appID {
            shortcuts.firstIndex { $0.id == appID }
        } else {
            nil
        }

        guard let currentPosition else {
            focusBinding.wrappedValue = shortcuts.first.map { .row($0.id) } ?? .addApp
            return
        }

        let totalPositions = shortcuts.count + 1
        let nextPosition = down
            ? (currentPosition + 1) % totalPositions
            : (currentPosition - 1 + totalPositions) % totalPositions

        focusBinding.wrappedValue = nextPosition == shortcuts.count
            ? .addApp
            : .row(shortcuts[nextPosition].id)
    }
}
