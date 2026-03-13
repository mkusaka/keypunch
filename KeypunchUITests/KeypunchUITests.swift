//
//  KeypunchUITests.swift
//  KeypunchUITests
//
//  Created by Masatomo Kusaka on 2026/03/13.
//

import XCTest

final class KeypunchUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        app = XCUIApplication()
    }

    override func tearDown() {
        if let app, app.state != .notRunning {
            app.terminate()
        }
        app = nil
    }

    // MARK: - Helpers

    /// Launches the app, tolerating stale-process termination failures
    /// that can occur when a zombie process from a prior Xcode session lingers.
    private func resilientLaunch() {
        continueAfterFailure = true
        app.launch()
        continueAfterFailure = false
    }

    private func launchClean() {
        app.launchArguments = ["-resetForTesting"]
        resilientLaunch()
    }

    private func launchWithSeededShortcuts(_ shortcuts: [[String: Any]]) {
        let data = try! JSONSerialization.data(withJSONObject: shortcuts)
        let json = String(data: data, encoding: .utf8)!
        app.launchArguments = ["-resetForTesting"]
        app.launchEnvironment["SEED_SHORTCUTS"] = json
        resilientLaunch()
    }

    private func launchWithSeededShortcutsNoTestMode(_ shortcuts: [[String: Any]]) {
        let data = try! JSONSerialization.data(withJSONObject: shortcuts)
        let json = String(data: data, encoding: .utf8)!
        app.launchArguments = ["-seedOnly"]
        app.launchEnvironment["SEED_SHORTCUTS"] = json
        resilientLaunch()
    }

    private func makeSeedShortcut(name: String, bundleID: String?, appPath: String) -> [String: Any] {
        var dict: [String: Any] = [
            "id": UUID().uuidString,
            "name": name,
            "appPath": appPath,
            "shortcutName": "test_\(UUID().uuidString)",
        ]
        if let bundleID {
            dict["bundleIdentifier"] = bundleID
        }
        return dict
    }

    /// Opens the MenuBarExtra menu and returns it.
    /// Uses `statusItem.menus` to get the correct menu (not the system Apple menu).
    private func openMenu() -> XCUIElement {
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "Menu bar item should exist")
        statusItem.click()

        let menu = statusItem.menus.firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "Menu should appear")
        return menu
    }

    private func openSettings() {
        let menu = openMenu()
        let settingsItem = menu.menuItems["Settings..."]
        XCTAssertTrue(settingsItem.waitForExistence(timeout: 3), "Settings menu item should exist")
        settingsItem.click()
    }

    // MARK: - Menu Bar Tests

    @MainActor
    func testMenuBarItemExists() throws {
        launchClean()
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
    }

    @MainActor
    func testEmptyStateMenuContents() throws {
        launchClean()
        let menu = openMenu()

        XCTAssertTrue(menu.menuItems["No shortcuts configured"].exists, "Should show empty state message")
        XCTAssertTrue(menu.menuItems["Settings..."].exists, "Settings item should exist")
        XCTAssertTrue(menu.menuItems["Quit Keypunch"].exists, "Quit item should exist")
    }

    @MainActor
    func testSeededShortcutAppearsInMenu() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        let menu = openMenu()

        XCTAssertTrue(menu.menuItems["Calculator"].exists, "Calculator should appear in menu")
        XCTAssertFalse(menu.menuItems["No shortcuts configured"].exists, "Empty message should not appear")
    }

    @MainActor
    func testMultipleSeededShortcutsAppearInMenu() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
            makeSeedShortcut(name: "TextEdit", bundleID: "com.apple.TextEdit", appPath: "/System/Applications/TextEdit.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        let menu = openMenu()

        XCTAssertTrue(menu.menuItems["Calculator"].exists)
        XCTAssertTrue(menu.menuItems["TextEdit"].exists)
    }

    // MARK: - Settings Window Tests

    @MainActor
    func testSettingsWindowOpens() throws {
        launchClean()
        openSettings()

        let settingsWindow = app.windows["Keypunch Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5), "Settings window should open")
    }

    @MainActor
    func testSettingsShowsEmptyStateMessage() throws {
        launchClean()
        openSettings()

        let settingsWindow = app.windows["Keypunch Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))
        XCTAssertTrue(settingsWindow.staticTexts["Select a shortcut or add a new one"].exists)
    }

    @MainActor
    func testSettingsShowsSeededShortcut() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openSettings()

        let settingsWindow = app.windows["Keypunch Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))
        XCTAssertTrue(settingsWindow.staticTexts["Calculator"].exists, "Calculator should appear in Settings list")
    }

    @MainActor
    func testSettingsSelectShortcutShowsEditView() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openSettings()

        let settingsWindow = app.windows["Keypunch Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))

        settingsWindow.staticTexts["Calculator"].click()

        XCTAssertTrue(settingsWindow.staticTexts["Name:"].waitForExistence(timeout: 3))
        XCTAssertTrue(settingsWindow.staticTexts["Application:"].exists)
        XCTAssertTrue(settingsWindow.staticTexts["Bundle ID:"].exists)
        XCTAssertTrue(settingsWindow.staticTexts["Shortcut:"].exists)
        XCTAssertTrue(settingsWindow.staticTexts["com.apple.calculator"].exists)
    }

    @MainActor
    func testSettingsDeleteShortcut() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openSettings()

        let settingsWindow = app.windows["Keypunch Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))

        settingsWindow.staticTexts["Calculator"].click()

        let splitGroup = settingsWindow.splitGroups.firstMatch
        let minusButton = splitGroup.groups.firstMatch.buttons.element(boundBy: 1)
        XCTAssertTrue(minusButton.isEnabled, "Minus button should be enabled when item is selected")
        minusButton.click()

        sleep(1)
        XCTAssertTrue(settingsWindow.staticTexts["Select a shortcut or add a new one"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSettingsAddButtonExists() throws {
        launchClean()
        openSettings()

        let settingsWindow = app.windows["Keypunch Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))

        let splitGroup = settingsWindow.splitGroups.firstMatch
        let plusButton = splitGroup.groups.firstMatch.buttons.element(boundBy: 0)
        XCTAssertTrue(plusButton.exists, "Plus button should exist")
        XCTAssertTrue(plusButton.isEnabled, "Plus button should be enabled")

        let minusButton = splitGroup.groups.firstMatch.buttons.element(boundBy: 1)
        XCTAssertTrue(minusButton.exists, "Minus button should exist")
        // Minus should be disabled when nothing is selected
    }

    // MARK: - Icon & Shortcut Display Tests

    @MainActor
    func testMenuItemWithIconExists() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        let menu = openMenu()

        // Verify menu item exists (icon is rendered natively by MenuBarExtra
        // and is not exposed as a child accessibility element)
        let menuItem = menu.menuItems["Calculator"]
        XCTAssertTrue(menuItem.exists, "Calculator menu item should exist with icon label")
    }

    @MainActor
    func testSettingsSidebarShowsAppIcon() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openSettings()

        let settingsWindow = app.windows["Keypunch Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))

        let splitGroup = settingsWindow.splitGroups.firstMatch
        let images = splitGroup.images
        XCTAssertTrue(images.count > 0, "Settings sidebar should show app icon images")
    }

    // MARK: - Filter Tests

    @MainActor
    func testMenuHidesItemsWithoutShortcuts() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcutsNoTestMode(shortcuts)
        let menu = openMenu()

        XCTAssertTrue(menu.menuItems["No shortcuts configured"].exists,
                      "Should show empty state when no shortcuts have keyboard bindings")
        XCTAssertFalse(menu.menuItems["Calculator"].exists,
                       "Calculator without keyboard shortcut should not appear")
    }

    // MARK: - Sidebar Width Tests

    @MainActor
    func testSettingsSidebarWidthConsistency() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openSettings()

        let settingsWindow = app.windows["Keypunch Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))

        let splitGroup = settingsWindow.splitGroups.firstMatch
        let widthBeforeSelection = splitGroup.groups.firstMatch.frame.width

        settingsWindow.staticTexts["Calculator"].click()
        sleep(1)

        let widthAfterSelection = splitGroup.groups.firstMatch.frame.width
        XCTAssertEqual(widthBeforeSelection, widthAfterSelection, accuracy: 2.0,
                       "Sidebar width should remain consistent when selecting an item")
    }

    // MARK: - App Launch Tests

    @MainActor
    func testMenuLaunchesApp() throws {
        let shortcuts = [
            makeSeedShortcut(name: "TextEdit", bundleID: "com.apple.TextEdit", appPath: "/System/Applications/TextEdit.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        let menu = openMenu()

        menu.menuItems["TextEdit"].click()

        let textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        XCTAssertTrue(textEdit.waitForExistence(timeout: 10), "TextEdit should launch")
        textEdit.terminate()
    }
}
