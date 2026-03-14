//
//  KeypunchApp.swift
//  Keypunch
//
//  Created by Masatomo Kusaka on 2026/03/13.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var widgetController: FloatingWidgetController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard NSClassFromString("XCTestCase") == nil else { return }
        guard let store = KeypunchApp.sharedStore else { return }

        let controller = FloatingWidgetController(
            store: store,
            isTestMode: KeypunchApp.sharedIsTestMode
        )
        controller.setup()
        self.widgetController = controller
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            widgetController?.showSettingsWindow()
        }
        return true
    }
}

@main
struct KeypunchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var store: ShortcutStore
    private let isTestMode: Bool

    static var sharedStore: ShortcutStore!
    static var sharedIsTestMode: Bool = false

    init() {
        let isResetForTesting = CommandLine.arguments.contains("-resetForTesting")
        let isSeedOnly = CommandLine.arguments.contains("-seedOnly")

        if isResetForTesting || isSeedOnly {
            UserDefaults.standard.removeObject(forKey: ShortcutStore.storageKey)
            UserDefaults.standard.removeObject(forKey: "triggerPositionX")
            UserDefaults.standard.removeObject(forKey: "triggerPositionY")
        }
        if let seedJSON = ProcessInfo.processInfo.environment["SEED_SHORTCUTS"],
           let data = seedJSON.data(using: .utf8) {
            UserDefaults.standard.set(data, forKey: ShortcutStore.storageKey)
        }

        isTestMode = isResetForTesting
        let storeInstance = ShortcutStore()
        _store = State(initialValue: storeInstance)

        KeypunchApp.sharedStore = storeInstance
        KeypunchApp.sharedIsTestMode = isResetForTesting
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
