// swiftlint:disable file_length type_body_length
import AppKit
import Foundation
@testable import Keypunch
import KeypunchKeyboardShortcuts
import Testing

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
        let data = try #require(json.data(using: .utf8))
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

    @Test func appDirectoryComputed() {
        let shortcut = AppShortcut(
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/System/Applications/Calculator.app"
        )
        #expect(shortcut.appDirectory == "/System/Applications")
    }

    @Test func appDirectoryForNestedPath() {
        let shortcut = AppShortcut(
            name: "MyApp",
            bundleIdentifier: nil,
            appPath: "/Users/test/Desktop/Apps/MyApp.app"
        )
        #expect(shortcut.appDirectory == "/Users/test/Desktop/Apps")
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

        let shortcut = AppShortcut(
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/System/Applications/Calculator.app"
        )
        store.addShortcut(shortcut)

        #expect(store.shortcuts.count == 1)
        #expect(store.shortcuts[0].name == "Calculator")
    }

    @MainActor
    @Test func removeShortcut() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        let shortcut = AppShortcut(
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/System/Applications/Calculator.app"
        )
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
    @Test func moveShortcutsForward() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        let s1 = AppShortcut(name: "App1", bundleIdentifier: nil, appPath: "/a1.app")
        let s2 = AppShortcut(name: "App2", bundleIdentifier: nil, appPath: "/a2.app")
        let s3 = AppShortcut(name: "App3", bundleIdentifier: nil, appPath: "/a3.app")
        store.addShortcut(s1)
        store.addShortcut(s2)
        store.addShortcut(s3)

        // Move App1 after App3 (index 0 → destination 3)
        store.moveShortcuts(from: IndexSet(integer: 0), to: 3)
        #expect(store.shortcuts[0].name == "App2")
        #expect(store.shortcuts[1].name == "App3")
        #expect(store.shortcuts[2].name == "App1")
    }

    @MainActor
    @Test func moveShortcutsBackward() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        let s1 = AppShortcut(name: "App1", bundleIdentifier: nil, appPath: "/a1.app")
        let s2 = AppShortcut(name: "App2", bundleIdentifier: nil, appPath: "/a2.app")
        let s3 = AppShortcut(name: "App3", bundleIdentifier: nil, appPath: "/a3.app")
        store.addShortcut(s1)
        store.addShortcut(s2)
        store.addShortcut(s3)

        // Move App3 before App1 (index 2 → destination 0)
        store.moveShortcuts(from: IndexSet(integer: 2), to: 0)
        #expect(store.shortcuts[0].name == "App3")
        #expect(store.shortcuts[1].name == "App1")
        #expect(store.shortcuts[2].name == "App2")
    }

    @MainActor
    @Test func updateShortcut() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        var shortcut = AppShortcut(
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/System/Applications/Calculator.app"
        )
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
        let shortcut = AppShortcut(
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/System/Applications/Calculator.app"
        )
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

        let shortcut = AppShortcut(
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/System/Applications/Calculator.app"
        )
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
        let shortcut = AppShortcut(
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/System/Applications/Calculator.app"
        )
        store1.addShortcut(shortcut)
        store1.toggleEnabled(for: shortcut)

        let store2 = ShortcutStore(defaults: defaults)
        #expect(store2.shortcuts[0].isEnabled == false)
    }

    @MainActor
    @Test func unsetShortcutKeepsAppEntry() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        let shortcut = AppShortcut(
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/System/Applications/Calculator.app"
        )
        store.addShortcut(shortcut)

        store.unsetShortcut(for: shortcut)

        #expect(store.shortcuts.count == 1, "App entry should remain after unset")
        #expect(store.shortcuts[0].name == "Calculator")
    }

    @MainActor
    @Test func unsetShortcutIncrementsVersion() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        let shortcut = AppShortcut(
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/System/Applications/Calculator.app"
        )
        store.addShortcut(shortcut)

        let versionBefore = store.shortcutKeysVersion
        store.unsetShortcut(for: shortcut)

        #expect(
            store.shortcutKeysVersion == versionBefore + 1,
            "shortcutKeysVersion should increment after unset"
        )
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

    @MainActor
    @Test func addShortcutFromURLSuccess() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        let url = URL(filePath: "/System/Applications/Calculator.app")
        let result = store.addShortcutFromURL(url)

        switch result {
        case let .success(shortcut):
            #expect(shortcut.name == "Calculator")
            #expect(shortcut.appPath == "/System/Applications/Calculator.app")
            #expect(shortcut.bundleIdentifier == "com.apple.calculator")
            #expect(store.shortcuts.count == 1)
        case .duplicate:
            Issue.record("Should have succeeded, not duplicate")
        }
    }

    @MainActor
    @Test func addShortcutFromURLDuplicateByPath() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        let shortcut = AppShortcut(
            name: "Calculator",
            bundleIdentifier: nil,
            appPath: "/System/Applications/Calculator.app"
        )
        store.addShortcut(shortcut)

        let url = URL(filePath: "/System/Applications/Calculator.app")
        let result = store.addShortcutFromURL(url)

        switch result {
        case .success:
            Issue.record("Should have been detected as duplicate by path")
        case let .duplicate(name):
            #expect(name == "Calculator")
            #expect(store.shortcuts.count == 1)
        }
    }

    @MainActor
    @Test func addShortcutFromURLDuplicateByBundleID() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        let shortcut = AppShortcut(
            name: "Calc",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/some/other/path/Calculator.app"
        )
        store.addShortcut(shortcut)

        let url = URL(filePath: "/System/Applications/Calculator.app")
        let result = store.addShortcutFromURL(url)

        switch result {
        case .success:
            Issue.record("Should have been detected as duplicate by bundle ID")
        case let .duplicate(name):
            #expect(name == "Calculator")
            #expect(store.shortcuts.count == 1)
        }
    }

    @MainActor
    @Test func corruptDataLoadsEmpty() {
        let defaults = makeTestDefaults()
        defaults.set(Data("not valid json".utf8), forKey: ShortcutStore.storageKey)

        let store = ShortcutStore(defaults: defaults)
        #expect(store.shortcuts.isEmpty, "Corrupt data should result in empty store")
    }

    @MainActor
    @Test func toggleEnabledNonexistentIsNoop() {
        let defaults = makeTestDefaults()
        let store = ShortcutStore(defaults: defaults)

        let shortcut = AppShortcut(name: "Ghost", bundleIdentifier: nil, appPath: "/ghost.app")
        store.toggleEnabled(for: shortcut)

        #expect(store.shortcuts.isEmpty)
    }
}

// MARK: - Mock Implementations

final class MockAppLauncher: AppLaunching, @unchecked Sendable {
    var launchedURLs: [URL] = []
    var bundleToURL: [String: URL] = [:]

    func openApplication(
        at url: URL,
        configuration _: NSWorkspace.OpenConfiguration
    ) async throws -> NSRunningApplication {
        launchedURLs.append(url)
        return NSRunningApplication.current
    }

    func urlForApplication(withBundleIdentifier bundleIdentifier: String) -> URL? {
        bundleToURL[bundleIdentifier]
    }
}

final class MockShortcutRegistrar: ShortcutRegistering {
    var registeredNames: [KeyboardShortcutsClient.Name] = []
    var resetNames: [KeyboardShortcutsClient.Name] = []
    var onKeyUpCalls: [(name: KeyboardShortcutsClient.Name, hasAction: Bool)] = []
    var shortcutsByName: [KeyboardShortcutsClient.Name: KeyboardShortcutsClient.Shortcut] = [:]

    func onKeyUp(for name: KeyboardShortcutsClient.Name, action _: @escaping () -> Void) {
        // Detect if it's a "no-op" registration (disabled shortcut) by checking action identity
        // We can't easily distinguish, so just record the call
        registeredNames.append(name)
        onKeyUpCalls.append((name: name, hasAction: true))
    }

    func reset(_ name: KeyboardShortcutsClient.Name) {
        resetNames.append(name)
    }

    func getShortcut(for name: KeyboardShortcutsClient.Name) -> KeyboardShortcutsClient.Shortcut? {
        shortcutsByName[name]
    }
}

struct MockBundle: BundleProviding {
    var bundleIdentifier: String?
}

// MARK: - ShortcutStore Behavior Tests (with mocks)

@Suite(.serialized)
struct ShortcutStoreBehaviorTests {
    private func makeTestDefaults() -> UserDefaults {
        let suiteName = "com.mkusaka.KeypunchTests.behavior.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @MainActor
    @Test func launchAppResolvesByBundleIDWhenPathMatches() async throws {
        let launcher = MockAppLauncher()
        let resolvedURL = URL(filePath: "/Applications/Calculator.app")
        launcher.bundleToURL["com.apple.calculator"] = resolvedURL

        let store = ShortcutStore(
            defaults: makeTestDefaults(),
            workspace: launcher,
            registrar: MockShortcutRegistrar(),
            mainBundle: MockBundle(bundleIdentifier: "com.mkusaka.Keypunch")
        )

        let shortcut = AppShortcut(
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/Applications/Calculator.app"
        )
        store.launchApp(for: shortcut)

        // Wait for the Task inside launchApp to complete
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(launcher.launchedURLs.count == 1)
        #expect(launcher.launchedURLs[0] == resolvedURL)
    }

    @MainActor
    @Test func launchAppFallsBackToStoredPathWhenBundleResolvesToDifferentPath() async throws {
        let launcher = MockAppLauncher()
        launcher.bundleToURL["com.apple.calculator"] = URL(filePath: "/Applications/EvilCalc.app")

        let store = ShortcutStore(
            defaults: makeTestDefaults(),
            workspace: launcher,
            registrar: MockShortcutRegistrar(),
            mainBundle: MockBundle(bundleIdentifier: "com.mkusaka.Keypunch")
        )

        let shortcut = AppShortcut(
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/Applications/Calculator.app"
        )
        store.launchApp(for: shortcut)

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(launcher.launchedURLs.count == 1)
        #expect(launcher.launchedURLs[0] == URL(filePath: "/Applications/Calculator.app"))
    }

    @MainActor
    @Test func launchAppFallsBackToAppPath() async throws {
        let launcher = MockAppLauncher()
        // No bundleToURL mapping → should fall back to appPath

        let store = ShortcutStore(
            defaults: makeTestDefaults(),
            workspace: launcher,
            registrar: MockShortcutRegistrar(),
            mainBundle: MockBundle(bundleIdentifier: "com.mkusaka.Keypunch")
        )

        let shortcut = AppShortcut(
            name: "CustomApp",
            bundleIdentifier: "com.unknown.app",
            appPath: "/Applications/CustomApp.app"
        )
        store.launchApp(for: shortcut)

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(launcher.launchedURLs.count == 1)
        #expect(launcher.launchedURLs[0].path().contains("CustomApp.app"))
    }

    @MainActor
    @Test func launchAppFallsBackWhenNoBundleID() async throws {
        let launcher = MockAppLauncher()

        let store = ShortcutStore(
            defaults: makeTestDefaults(),
            workspace: launcher,
            registrar: MockShortcutRegistrar(),
            mainBundle: MockBundle(bundleIdentifier: "com.mkusaka.Keypunch")
        )

        let shortcut = AppShortcut(
            name: "NoBundle",
            bundleIdentifier: nil,
            appPath: "/Applications/NoBundle.app"
        )
        store.launchApp(for: shortcut)

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(launcher.launchedURLs.count == 1)
        #expect(launcher.launchedURLs[0].path().contains("NoBundle.app"))
    }

    @MainActor
    @Test func launchAppSelfActivation() async throws {
        let launcher = MockAppLauncher()

        let store = ShortcutStore(
            defaults: makeTestDefaults(),
            workspace: launcher,
            registrar: MockShortcutRegistrar(),
            mainBundle: MockBundle(bundleIdentifier: "com.mkusaka.Keypunch")
        )

        var selfActivated = false
        store.onSelfActivate = { selfActivated = true }

        let shortcut = AppShortcut(
            name: "Keypunch",
            bundleIdentifier: "com.mkusaka.Keypunch",
            appPath: "/Applications/Keypunch.app"
        )
        store.launchApp(for: shortcut)

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(selfActivated)
        #expect(launcher.launchedURLs.isEmpty, "Should not launch when self-activating")
    }

    @MainActor
    @Test func removeShortcutResetsBinding() {
        let registrar = MockShortcutRegistrar()
        let store = ShortcutStore(
            defaults: makeTestDefaults(),
            workspace: MockAppLauncher(),
            registrar: registrar,
            mainBundle: MockBundle(bundleIdentifier: "com.mkusaka.Keypunch")
        )

        let shortcut = AppShortcut(
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/System/Applications/Calculator.app"
        )
        store.addShortcut(shortcut)
        registrar.resetNames.removeAll()

        store.removeShortcut(shortcut)

        #expect(registrar.resetNames.contains(shortcut.keyboardShortcutName))
    }

    @MainActor
    @Test func toggleDisabledRegistersNoopHandler() {
        let registrar = MockShortcutRegistrar()
        let store = ShortcutStore(
            defaults: makeTestDefaults(),
            workspace: MockAppLauncher(),
            registrar: registrar,
            mainBundle: MockBundle(bundleIdentifier: "com.mkusaka.Keypunch")
        )

        let shortcut = AppShortcut(
            name: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            appPath: "/System/Applications/Calculator.app"
        )
        store.addShortcut(shortcut)
        let callCountBefore = registrar.onKeyUpCalls.count

        store.toggleEnabled(for: shortcut)

        #expect(store.shortcuts[0].isEnabled == false)
        #expect(registrar.onKeyUpCalls.count > callCountBefore, "Should register a noop handler when disabled")
    }

    @MainActor
    @Test func conflictDetectionFindsConflict() {
        let registrar = MockShortcutRegistrar()
        let store = ShortcutStore(
            defaults: makeTestDefaults(),
            workspace: MockAppLauncher(),
            registrar: registrar,
            mainBundle: MockBundle(bundleIdentifier: "com.mkusaka.Keypunch")
        )

        let s1 = AppShortcut(name: "App1", bundleIdentifier: nil, appPath: "/a1.app")
        let s2 = AppShortcut(name: "App2", bundleIdentifier: nil, appPath: "/a2.app")
        store.addShortcut(s1)
        store.addShortcut(s2)

        let conflictingShortcut = KeyboardShortcutsClient.Shortcut(.a, modifiers: .command)
        registrar.shortcutsByName[s1.keyboardShortcutName] = conflictingShortcut

        let isConflicting = store.isShortcutConflicting(conflictingShortcut, excluding: s2.keyboardShortcutName)
        #expect(isConflicting, "Should detect conflict with s1's shortcut")
    }

    @MainActor
    @Test func conflictDetectionNoConflictWhenExcluded() {
        let registrar = MockShortcutRegistrar()
        let store = ShortcutStore(
            defaults: makeTestDefaults(),
            workspace: MockAppLauncher(),
            registrar: registrar,
            mainBundle: MockBundle(bundleIdentifier: "com.mkusaka.Keypunch")
        )

        let s1 = AppShortcut(name: "App1", bundleIdentifier: nil, appPath: "/a1.app")
        store.addShortcut(s1)

        let shortcut = KeyboardShortcutsClient.Shortcut(.a, modifiers: .command)
        registrar.shortcutsByName[s1.keyboardShortcutName] = shortcut

        let isConflicting = store.isShortcutConflicting(shortcut, excluding: s1.keyboardShortcutName)
        #expect(!isConflicting, "Should not conflict with itself (excluded)")
    }

    @MainActor
    @Test func conflictDetectionNoConflictWhenDifferent() {
        let registrar = MockShortcutRegistrar()
        let store = ShortcutStore(
            defaults: makeTestDefaults(),
            workspace: MockAppLauncher(),
            registrar: registrar,
            mainBundle: MockBundle(bundleIdentifier: "com.mkusaka.Keypunch")
        )

        let s1 = AppShortcut(name: "App1", bundleIdentifier: nil, appPath: "/a1.app")
        let s2 = AppShortcut(name: "App2", bundleIdentifier: nil, appPath: "/a2.app")
        store.addShortcut(s1)
        store.addShortcut(s2)

        registrar.shortcutsByName[s1.keyboardShortcutName] = KeyboardShortcutsClient.Shortcut(.a, modifiers: .command)

        let differentShortcut = KeyboardShortcutsClient.Shortcut(.b, modifiers: .command)
        let isConflicting = store.isShortcutConflicting(differentShortcut, excluding: s2.keyboardShortcutName)
        #expect(!isConflicting, "Different shortcuts should not conflict")
    }

    @MainActor
    @Test func unsetShortcutCallsReset() {
        let registrar = MockShortcutRegistrar()
        let store = ShortcutStore(
            defaults: makeTestDefaults(),
            workspace: MockAppLauncher(),
            registrar: registrar,
            mainBundle: MockBundle(bundleIdentifier: "com.mkusaka.Keypunch")
        )

        let shortcut = AppShortcut(name: "App1", bundleIdentifier: nil, appPath: "/a1.app")
        store.addShortcut(shortcut)
        registrar.resetNames.removeAll()

        store.unsetShortcut(for: shortcut)

        #expect(registrar.resetNames.contains(shortcut.keyboardShortcutName))
    }
}

// swiftlint:enable file_length type_body_length
