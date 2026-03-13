//
//  KeypunchApp.swift
//  Keypunch
//
//  Created by Masatomo Kusaka on 2026/03/13.
//

import SwiftUI

@main
struct KeypunchApp: App {
    @State private var store = ShortcutStore()

    var body: some Scene {
        MenuBarExtra("Keypunch", systemImage: "keyboard") {
            MenuBarView(store: store)
        }

        Settings {
            SettingsView(store: store)
        }
    }
}
