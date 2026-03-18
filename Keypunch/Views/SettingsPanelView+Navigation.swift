import AppKit
import KeypunchKeyboardShortcuts

// MARK: - Focus Navigation

extension SettingsPanelView {
    enum FocusDirection { case up, down }
    enum HorizontalFocusDirection { case left, right }

    func moveHorizontalFocus(
        direction: HorizontalFocusDirection,
        focus: inout PanelFocus?,
        shortcuts: [AppShortcut],
        editingShortcutID: UUID?
    ) {
        guard let current = focus else { return }

        if let editID = editingShortcutID {
            guard let targetShortcut = shortcuts.first(where: { $0.id == editID }) else { return }
            var targets: [PanelFocus] = [.shortcutBadge(editID)]
            if KeyboardShortcutsClient.getShortcut(for: targetShortcut.keyboardShortcutName) != nil {
                targets.append(.shortcutEditButton(editID))
                targets.append(.dangerButton(editID))
            }
            targets.append(.deleteButton(editID))
            targets.append(.cancelEdit(editID))

            guard let idx = targets.firstIndex(of: current) else { return }
            let nextIndex = switch direction {
            case .right: (idx + 1) % targets.count
            case .left: (idx - 1 + targets.count) % targets.count
            }
            focus = targets[nextIndex]
        } else {
            switch current {
            case let .row(id):
                if direction == .right { focus = .editButton(id) }
            case let .editButton(id):
                if direction == .left { focus = .row(id) }
            default:
                break
            }
        }
    }

    func moveFocus(
        direction: FocusDirection,
        includeEditButtons: Bool = false,
        focus: inout PanelFocus?,
        shortcuts: [AppShortcut],
        editingShortcutID: UUID?
    ) {
        guard let current = focus else {
            switch direction {
            case .down:
                if let first = shortcuts.first {
                    focus = editingShortcutID == first.id ? .shortcutBadge(first.id) : .row(first.id)
                } else {
                    focus = .addApp
                }
            case .up:
                focus = .addApp
            }
            return
        }

        if includeEditButtons, editingShortcutID == nil {
            let targets = Self.tabTargets(for: shortcuts)
            let currentIndex = targets.firstIndex(of: current)
            let nextIndex = if let idx = currentIndex {
                switch direction {
                case .down: (idx + 1) % targets.count
                case .up: (idx - 1 + targets.count) % targets.count
                }
            } else {
                direction == .down ? 0 : targets.count - 1
            }
            focus = targets[nextIndex]
            return
        }

        let currentPosition = Self.rowPosition(of: current, in: shortcuts)
        guard let currentPosition else {
            focus = shortcuts.first.map { .row($0.id) } ?? .addApp
            return
        }

        let totalPositions = shortcuts.count + 1
        let nextPosition = switch direction {
        case .down: (currentPosition + 1) % totalPositions
        case .up: (currentPosition - 1 + totalPositions) % totalPositions
        }

        if nextPosition == shortcuts.count {
            focus = .addApp
        } else {
            let target = shortcuts[nextPosition]
            focus = editingShortcutID == target.id ? .shortcutBadge(target.id) : .row(target.id)
        }
    }

    // MARK: - Helpers

    private static func tabTargets(for shortcuts: [AppShortcut]) -> [PanelFocus] {
        var targets: [PanelFocus] = []
        for shortcut in shortcuts {
            targets.append(.row(shortcut.id))
            targets.append(.editButton(shortcut.id))
        }
        targets.append(.addApp)
        return targets
    }

    private static func rowPosition(of focus: PanelFocus, in shortcuts: [AppShortcut]) -> Int? {
        if let appID = focus.appID, let idx = shortcuts.firstIndex(where: { $0.id == appID }) {
            return idx
        } else if focus == .addApp {
            return shortcuts.count
        }
        return nil
    }
}
