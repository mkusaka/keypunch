import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var widgetController: FloatingWidgetController?
    private var store: ShortcutStore?

    func applicationDidFinishLaunching(_: Notification) {
        guard NSClassFromString("XCTestCase") == nil else { return }

        let isResetForTesting = CommandLine.arguments.contains("-resetForTesting")
        let isSeedOnly = CommandLine.arguments.contains("-seedOnly")

        if isResetForTesting || isSeedOnly {
            UserDefaults.standard.removeObject(forKey: ShortcutStore.storageKey)
        }
        if let seedJSON = ProcessInfo.processInfo.environment["SEED_SHORTCUTS"],
           let data = seedJSON.data(using: .utf8)
        {
            UserDefaults.standard.set(data, forKey: ShortcutStore.storageKey)
        }

        let storeInstance = ShortcutStore()
        store = storeInstance

        let controller = FloatingWidgetController(
            store: storeInstance,
            isTestMode: isResetForTesting
        )
        controller.setup()
        widgetController = controller
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            widgetController?.showSettingsWindow()
        }
        return true
    }
}

@main
struct KeypunchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
