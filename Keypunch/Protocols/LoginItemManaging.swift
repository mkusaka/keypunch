import ServiceManagement

protocol LoginItemManaging {
    var isEnabled: Bool { get }
    func register() throws
    func unregister() throws
}

struct SMAppServiceLoginItemManager: LoginItemManaging {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}
