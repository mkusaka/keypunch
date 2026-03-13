//
//  KeypunchApp.swift
//  Keypunch
//
//  Created by Masatomo Kusaka on 2026/03/13.
//

import SwiftUI

@main
struct KeypunchApp: App {
    @State private var store: ShortcutStore
    private let isTestMode: Bool

    init() {
        let isResetForTesting = CommandLine.arguments.contains("-resetForTesting")
        let isSeedOnly = CommandLine.arguments.contains("-seedOnly")

        if isResetForTesting || isSeedOnly {
            UserDefaults.standard.removeObject(forKey: ShortcutStore.storageKey)
        }
        if let seedJSON = ProcessInfo.processInfo.environment["SEED_SHORTCUTS"],
           let data = seedJSON.data(using: .utf8) {
            UserDefaults.standard.set(data, forKey: ShortcutStore.storageKey)
        }

        isTestMode = isResetForTesting
        _store = State(initialValue: ShortcutStore())
    }

    var body: some Scene {
        MenuBarExtra("Keypunch", systemImage: "keyboard") {
            MenuBarView(store: store, showAllForTesting: isTestMode)
        }

        Settings {
            SettingsView(store: store)
        }
    }
}
