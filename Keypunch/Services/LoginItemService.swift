@MainActor
final class LoginItemService {
    private let manager: LoginItemManaging

    init(manager: LoginItemManaging = SMAppServiceLoginItemManager()) {
        self.manager = manager
    }

    var isEnabled: Bool {
        manager.isEnabled
    }

    func toggle() {
        do {
            if manager.isEnabled {
                try manager.unregister()
            } else {
                try manager.register()
            }
        } catch {
            print("Failed to toggle login item: \(error)")
        }
    }
}
