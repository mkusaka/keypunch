//
//  KeypunchApp.swift
//  Keypunch
//
//  Created by Masatomo Kusaka on 2026/03/13.
//

import SwiftUI

@main
struct KeypunchApp: App {
    var body: some Scene {
        MenuBarExtra("Keypunch", systemImage: "keyboard") {
            Button("Quit Keypunch") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
