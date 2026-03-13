//
//  KeypunchTests.swift
//  KeypunchTests
//
//  Created by Masatomo Kusaka on 2026/03/13.
//

import Testing
import Foundation
@testable import Keypunch

// MARK: - AppShortcut Tests

struct AppShortcutTests {

    @Test func initWithDefaults() {
        let shortcut = AppShortcut(
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/System/Applications/Calculator.app"
        )

        #expect(shortcut.name == "Calculator")
        #expect(shortcut.bundleIdentifier == "com.apple.calculator")
        #expect(shortcut.appPath == "/System/Applications/Calculator.app")
        #expect(shortcut.shortcutName.hasPrefix("appShortcut_"))
        #expect(shortcut.appURL.path().contains("Calculator.app"))
    }

    @Test func initWithCustomShortcutName() {
        let shortcut = AppShortcut(
            name: "Safari",
            bundleIdentifier: "com.apple.Safari",
            appPath: "/Applications/Safari.app",
            shortcutName: "customName"
        )

        #expect(shortcut.shortcutName == "customName")
    }

    @Test func initWithNilBundleIdentifier() {
        let shortcut = AppShortcut(
            name: "MyApp",
            bundleIdentifier: nil,
            appPath: "/Applications/MyApp.app"
        )

        #expect(shortcut.bundleIdentifier == nil)
    }

    @Test func isEnabledDefaultsToTrue() {
        let shortcut = AppShortcut(
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/System/Applications/Calculator.app"
        )

        #expect(shortcut.isEnabled == true)
    }

    @Test func isEnabledCanBeSetToFalse() {
        let shortcut = AppShortcut(
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/System/Applications/Calculator.app",
            isEnabled: false
        )

        #expect(shortcut.isEnabled == false)
    }

    @Test func codableRoundTrip() throws {
        let original = AppShortcut(
            id: UUID(),
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/System/Applications/Calculator.app",
            shortcutName: "testShortcut"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppShortcut.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.bundleIdentifier == original.bundleIdentifier)
        #expect(decoded.appPath == original.appPath)
        #expect(decoded.shortcutName == original.shortcutName)
        #expect(decoded.isEnabled == original.isEnabled)
    }

    @Test func codableBackwardCompatibility() throws {
        // Simulate old JSON without isEnabled field
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "name": "Calculator",
            "bundleIdentifier": "com.apple.calculator",
            "appPath": "/System/Applications/Calculator.app",
            "shortcutName": "testShortcut"
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppShortcut.self, from: data)

        #expect(decoded.isEnabled == true, "isEnabled should default to true for old data")
    }

    @Test func codableRoundTripArray() throws {
        let shortcuts = [
            AppShortcut(name: "App1", bundleIdentifier: "com.test.app1", appPath: "/Applications/App1.app"),
            AppShortcut(name: "App2", bundleIdentifier: nil, appPath: "/Applications/App2.app"),
        ]

        let data = try JSONEncoder().encode(shortcuts)
        let decoded = try JSONDecoder().decode([AppShortcut].self, from: data)

        #expect(decoded.count == 2)
        #expect(decoded[0].name == "App1")
        #expect(decoded[1].name == "App2")
        #expect(decoded[1].bundleIdentifier == nil)
    }

    @Test func hashableConformance() {
        let id = UUID()
        let a = AppShortcut(id: id, name: "App", bundleIdentifier: nil, appPath: "/Apps/A.app", shortcutName: "s1")
        let b = AppShortcut(id: id, name: "App", bundleIdentifier: nil, appPath: "/Apps/A.app", shortcutName: "s1")

        #expect(a == b)

        var set = Set<AppShortcut>()
        set.insert(a)
        set.insert(b)
        #expect(set.count == 1)
    }

    @Test func uniqueIdsOnCreation() {
        let a = AppShortcut(name: "App", bundleIdentifier: nil, appPath: "/a.app")
        let b = AppShortcut(name: "App", bundleIdentifier: nil, appPath: "/a.app")

        #expect(a.id != b.id)
        #expect(a.shortcutName != b.shortcutName)
    }
}

// MARK: - ShortcutStore Tests

@Suite(.serialized)
struct ShortcutStoreTests {

    private func makeTestDefaults() -> UserDefaults {
        let suiteName = "com.mkusaka.KeypunchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @MainActor
    @Test func addShortcut() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        let shortcut = AppShortcut(name: "Calculator", bundleIdentifier: "com.apple.calculator", appPath: "/System/Applications/Calculator.app")
        store.addShortcut(shortcut)

        #expect(store.shortcuts.count == 1)
        #expect(store.shortcuts[0].name == "Calculator")
    }

    @MainActor
    @Test func removeShortcut() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        let shortcut = AppShortcut(name: "Calculator", bundleIdentifier: "com.apple.calculator", appPath: "/System/Applications/Calculator.app")
        store.addShortcut(shortcut)
        #expect(store.shortcuts.count == 1)

        store.removeShortcut(shortcut)
        #expect(store.shortcuts.isEmpty)
    }

    @MainActor
    @Test func removeShortcutsAtOffsets() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        let s1 = AppShortcut(name: "App1", bundleIdentifier: nil, appPath: "/a1.app")
        let s2 = AppShortcut(name: "App2", bundleIdentifier: nil, appPath: "/a2.app")
        let s3 = AppShortcut(name: "App3", bundleIdentifier: nil, appPath: "/a3.app")
        store.addShortcut(s1)
        store.addShortcut(s2)
        store.addShortcut(s3)

        store.removeShortcuts(at: IndexSet([0, 2]))
        #expect(store.shortcuts.count == 1)
        #expect(store.shortcuts[0].name == "App2")
    }

    @MainActor
    @Test func updateShortcut() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        var shortcut = AppShortcut(name: "Calculator", bundleIdentifier: "com.apple.calculator", appPath: "/System/Applications/Calculator.app")
        store.addShortcut(shortcut)

        shortcut.name = "Calc"
        store.updateShortcut(shortcut)

        #expect(store.shortcuts.count == 1)
        #expect(store.shortcuts[0].name == "Calc")
    }

    @MainActor
    @Test func updateNonexistentShortcutIsNoop() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        let shortcut = AppShortcut(name: "Ghost", bundleIdentifier: nil, appPath: "/ghost.app")
        store.updateShortcut(shortcut)

        #expect(store.shortcuts.isEmpty)
    }

    @MainActor
    @Test func persistenceAcrossInstances() {
        let defaults = makeTestDefaults()

        let store1 = ShortcutStore(defaults: defaults)
        let shortcut = AppShortcut(name: "Calculator", bundleIdentifier: "com.apple.calculator", appPath: "/System/Applications/Calculator.app")
        store1.addShortcut(shortcut)
        #expect(store1.shortcuts.count == 1)

        let store2 = ShortcutStore(defaults: defaults)
        #expect(store2.shortcuts.count == 1)
        #expect(store2.shortcuts[0].id == shortcut.id)
        #expect(store2.shortcuts[0].name == "Calculator")
    }

    @MainActor
    @Test func emptyStoreOnFreshDefaults() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        #expect(store.shortcuts.isEmpty)
    }

    @MainActor
    @Test func containsAppByPath() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        let shortcut = AppShortcut(
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/System/Applications/Calculator.app"
        )
        store.addShortcut(shortcut)

        #expect(store.containsApp(path: "/System/Applications/Calculator.app") == true)
        #expect(store.containsApp(path: "/Applications/Safari.app") == false)
    }

    @MainActor
    @Test func containsAppByBundleIdentifier() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        let shortcut = AppShortcut(
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/System/Applications/Calculator.app"
        )
        store.addShortcut(shortcut)

        #expect(store.containsApp(bundleIdentifier: "com.apple.calculator") == true)
        #expect(store.containsApp(bundleIdentifier: "com.apple.Safari") == false)
    }

    @MainActor
    @Test func toggleEnabled() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        let shortcut = AppShortcut(name: "Calculator", bundleIdentifier: "com.apple.calculator", appPath: "/System/Applications/Calculator.app")
        store.addShortcut(shortcut)

        #expect(store.shortcuts[0].isEnabled == true)

        store.toggleEnabled(for: shortcut)
        #expect(store.shortcuts[0].isEnabled == false)

        store.toggleEnabled(for: store.shortcuts[0])
        #expect(store.shortcuts[0].isEnabled == true)
    }

    @MainActor
    @Test func toggleEnabledPersists() {
        let defaults = makeTestDefaults()

        let store1 = ShortcutStore(defaults: defaults)
        let shortcut = AppShortcut(name: "Calculator", bundleIdentifier: "com.apple.calculator", appPath: "/System/Applications/Calculator.app")
        store1.addShortcut(shortcut)
        store1.toggleEnabled(for: shortcut)

        let store2 = ShortcutStore(defaults: defaults)
        #expect(store2.shortcuts[0].isEnabled == false)
    }

    @MainActor
    @Test func containsAppByBundleIdentifierWithNilBundleIDs() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        let shortcut = AppShortcut(
            name: "CustomApp",
            bundleIdentifier: nil,
            appPath: "/Applications/CustomApp.app"
        )
        store.addShortcut(shortcut)

        #expect(store.containsApp(bundleIdentifier: "com.example.app") == false)
    }
}
