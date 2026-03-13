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

    /// Finds the trigger button and returns it.
    private func findTrigger() -> XCUIElement {
        let triggerButton = app.buttons["trigger-button"]
        XCTAssertTrue(triggerButton.waitForExistence(timeout: 5), "Trigger button should exist")
        return triggerButton
    }

    /// Opens the floating panel by clicking the trigger.
    /// Waits for the "Keypunch" header text to confirm the panel is visible.
    private func openPanel() {
        let trigger = findTrigger()
        trigger.click()

        let panelHeader = app.staticTexts["Keypunch"]
        XCTAssertTrue(panelHeader.waitForExistence(timeout: 5), "Panel should appear with Keypunch header")
    }

    /// Opens the Settings window via the panel gear button.
    private func openSettings() {
        openPanel()
        let gearButton = app.buttons["settings-button"]
        XCTAssertTrue(gearButton.waitForExistence(timeout: 3), "Settings button should exist in panel")
        gearButton.click()
        sleep(2)
        app.activate()
        sleep(1)
    }

    // MARK: - Trigger Tests

    @MainActor
    func testTriggerExists() throws {
        launchClean()
        let triggerButton = app.buttons["trigger-button"]
        XCTAssertTrue(triggerButton.waitForExistence(timeout: 5), "Trigger button should exist")
    }

    @MainActor
    func testTriggerClickOpensPanel() throws {
        launchClean()
        let trigger = findTrigger()

        trigger.click()

        let panelHeader = app.staticTexts["Keypunch"]
        XCTAssertTrue(panelHeader.waitForExistence(timeout: 5), "Panel should appear after clicking trigger")
    }

    // MARK: - Panel Content Tests

    @MainActor
    func testEmptyStatePanelContents() throws {
        launchClean()
        openPanel()

        XCTAssertTrue(app.staticTexts["No shortcuts configured"].exists,
                      "Should show empty state message")
        let quitExists = app.staticTexts["Quit Keypunch"].exists || app.buttons["Quit Keypunch"].exists
        XCTAssertTrue(quitExists, "Quit button should exist")
    }

    @MainActor
    func testSeededShortcutAppearsInPanel() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openPanel()

        XCTAssertTrue(app.staticTexts["Calculator"].exists, "Calculator should appear in panel")
        XCTAssertFalse(app.staticTexts["No shortcuts configured"].exists,
                       "Empty message should not appear")
    }

    @MainActor
    func testMultipleSeededShortcutsAppearInPanel() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
            makeSeedShortcut(name: "TextEdit", bundleID: "com.apple.TextEdit", appPath: "/System/Applications/TextEdit.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openPanel()

        XCTAssertTrue(app.staticTexts["Calculator"].exists)
        XCTAssertTrue(app.staticTexts["TextEdit"].exists)
    }

    @MainActor
    func testPanelShowsAppIcon() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openPanel()

        let calcIcon = app.images["Calculator icon"]
        XCTAssertTrue(calcIcon.exists, "Panel should show Calculator app icon")
    }

    @MainActor
    func testPanelShowsShortcutBadge() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openPanel()

        // In test mode, all shortcuts are shown regardless of key binding.
        // Since no key is assigned in seed data, the "Not set" badge should appear.
        XCTAssertTrue(app.staticTexts["Not set"].exists,
                      "Should show 'Not set' badge for unbound shortcut")
    }

    @MainActor
    func testPanelQuitButton() throws {
        launchClean()
        openPanel()

        let quitExists = app.staticTexts["Quit Keypunch"].exists || app.buttons["Quit Keypunch"].exists
        XCTAssertTrue(quitExists, "Quit button should exist in panel footer")
    }

    // MARK: - Settings Tests

    @MainActor
    func testSettingsWindowOpens() throws {
        launchClean()
        openSettings()

        let settingsWindow = app.windows.firstMatch
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5),
                      "Settings window should open. windowCount=\(app.windows.count)")
    }

    @MainActor
    func testSettingsShowsSeededShortcut() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openSettings()

        let settingsWindow = app.windows.firstMatch
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))
        XCTAssertTrue(settingsWindow.staticTexts["Calculator"].exists,
                      "Calculator should appear in Settings list")
    }

    @MainActor
    func testSettingsDeleteShortcut() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openSettings()

        let settingsWindow = app.windows.firstMatch
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

        let settingsWindow = app.windows.firstMatch
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))

        let splitGroup = settingsWindow.splitGroups.firstMatch
        let plusButton = splitGroup.groups.firstMatch.buttons.element(boundBy: 0)
        XCTAssertTrue(plusButton.exists, "Plus button should exist")
        XCTAssertTrue(plusButton.isEnabled, "Plus button should be enabled")

        let minusButton = splitGroup.groups.firstMatch.buttons.element(boundBy: 1)
        XCTAssertTrue(minusButton.exists, "Minus button should exist")
    }

    @MainActor
    func testSettingsGlobalRecorderExists() throws {
        launchClean()
        openSettings()

        let settingsWindow = app.windows.firstMatch
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))

        XCTAssertTrue(settingsWindow.staticTexts["Toggle Keypunch"].exists,
                      "Toggle Keypunch recorder label should exist in settings sidebar")
    }

    // MARK: - App Launch Tests

    @MainActor
    func testPanelLaunchesApp() throws {
        let shortcuts = [
            makeSeedShortcut(name: "TextEdit", bundleID: "com.apple.TextEdit", appPath: "/System/Applications/TextEdit.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openPanel()

        app.staticTexts["TextEdit"].click()

        let textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        XCTAssertTrue(textEdit.waitForExistence(timeout: 10), "TextEdit should launch")
        textEdit.terminate()
    }

    // MARK: - Filter Tests

    @MainActor
    func testPanelHidesItemsWithoutShortcuts() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcutsNoTestMode(shortcuts)
        openPanel()

        XCTAssertTrue(app.staticTexts["No shortcuts configured"].exists,
                      "Should show empty state when no shortcuts have keyboard bindings")
        XCTAssertFalse(app.staticTexts["Calculator"].exists,
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

        let settingsWindow = app.windows.firstMatch
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))

        let splitGroup = settingsWindow.splitGroups.firstMatch
        let widthBeforeSelection = splitGroup.groups.firstMatch.frame.width

        settingsWindow.staticTexts["Calculator"].click()
        sleep(1)

        let widthAfterSelection = splitGroup.groups.firstMatch.frame.width
        XCTAssertEqual(widthBeforeSelection, widthAfterSelection, accuracy: 2.0,
                       "Sidebar width should remain consistent when selecting an item")
    }
}
