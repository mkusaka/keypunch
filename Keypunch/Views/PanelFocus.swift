import Foundation

enum PanelFocus: Hashable {
    case row(UUID)
    case editButton(UUID)
    case addApp
    // Edit mode focus targets
    case shortcutBadge(UUID)
    case shortcutEditButton(UUID)
    case cancelEdit(UUID)
    case dangerButton(UUID)
    case deleteButton(UUID)
    // Dialog focus targets
    case dialogCancel
    case dialogRemove
    case dialogOK

    var appID: UUID? {
        switch self {
        case let .row(id), let .editButton(id),
             let .shortcutBadge(id), let .shortcutEditButton(id),
             let .cancelEdit(id), let .dangerButton(id),
             let .deleteButton(id):
            id
        case .addApp, .dialogCancel, .dialogRemove, .dialogOK:
            nil
        }
    }
}
