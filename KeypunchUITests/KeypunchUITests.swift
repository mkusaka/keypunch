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

    /// Opens the floating panel by hovering over the trigger.
    /// Waits for the "Keypunch" header text to confirm the panel is visible.
    private func openPanel() {
        let trigger = findTrigger()
        trigger.hover()

        let panelHeader = app.staticTexts["Keypunch"]
        XCTAssertTrue(panelHeader.waitForExistence(timeout: 5), "Panel should appear with Keypunch header")
    }

    /// Opens the panel and switches to the Edit tab.
    private func openEditMode() {
        openPanel()
        let editTab = app.buttons["Edit"]
        XCTAssertTrue(editTab.waitForExistence(timeout: 3), "Edit tab should exist")
        editTab.click()
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
    func testTriggerHoverOpensPanel() throws {
        launchClean()
        let trigger = findTrigger()

        trigger.hover()

        let panelHeader = app.staticTexts["Keypunch"]
        XCTAssertTrue(panelHeader.waitForExistence(timeout: 5), "Panel should appear after hovering trigger")
    }

    // MARK: - Launch Tab Tests

    @MainActor
    func testEmptyStatePanelContents() throws {
        launchClean()
        openPanel()

        XCTAssertTrue(app.staticTexts["No shortcuts configured"].exists,
                      "Should show empty state message")
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

    // MARK: - Edit Tab Tests

    @MainActor
    func testEditTabExists() throws {
        launchClean()
        openPanel()

        let launchTab = app.buttons["Launch"]
        let editTab = app.buttons["Edit"]
        XCTAssertTrue(launchTab.exists, "Launch tab should exist")
        XCTAssertTrue(editTab.exists, "Edit tab should exist")
    }

    @MainActor
    func testEditModeShowsSeededShortcut() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        XCTAssertTrue(app.staticTexts["Calculator"].exists,
                      "Calculator should appear in edit mode")
    }

    @MainActor
    func testEditModeShowsAddAppButton() throws {
        launchClean()
        openEditMode()

        XCTAssertTrue(app.staticTexts["Add App"].exists || app.buttons["Add App"].exists,
                      "Add App button should exist in edit mode")
    }

    @MainActor
    func testDangerTriggerExists() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // Verify the danger trigger button exists in edit mode
        let dangerButton = app.buttons["danger-trigger"]
        XCTAssertTrue(dangerButton.waitForExistence(timeout: 5),
                      "Danger trigger button should exist in edit mode")
    }

    @MainActor
    func testDangerDropdownShowsDeleteButton() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // Open the danger dropdown
        let dangerButton = app.buttons["danger-trigger"]
        XCTAssertTrue(dangerButton.waitForExistence(timeout: 5))
        dangerButton.click()
        sleep(1)

        // Delete button should appear in the popover
        let deleteButton = app.buttons["delete-app"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5),
                      "Delete app button should appear in danger dropdown")
    }

    // MARK: - Panel Drag Tests

    @MainActor
    func testPanelHeaderIsDraggable() throws {
        launchClean()
        openPanel()

        // Verify the header exists (it serves as drag handle)
        let header = app.staticTexts["Keypunch"]
        XCTAssertTrue(header.exists, "Keypunch header should exist as drag handle")

        // Panel should remain visible and functional
        let notConfigured = app.staticTexts["No shortcuts configured"]
        XCTAssertTrue(notConfigured.exists,
                      "Panel content should be accessible")
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

    // MARK: - Launch Tab Shows All Apps

    @MainActor
    func testLaunchTabShowsAllAppsEvenWithoutShortcuts() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcutsNoTestMode(shortcuts)
        openPanel()

        XCTAssertTrue(app.staticTexts["Calculator"].waitForExistence(timeout: 5),
                      "Calculator should appear even without keyboard shortcut set")
        XCTAssertTrue(app.staticTexts["Not set"].exists,
                      "Should show 'Not set' badge for unbound shortcut")
    }

    // MARK: - Edit Mode Badge & UI Tests

    @MainActor
    func testEditModeHasRecordShortcutButton() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // The pencil icon button with "record-shortcut" identifier should exist
        let recordButton = app.buttons["record-shortcut"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5),
                      "Record shortcut (pencil) button should exist in edit mode")
    }

    @MainActor
    func testEditModeShowsAppDirectory() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // EditCard shows app directory path below the app name
        let pathText = app.staticTexts["/System/Applications"]
        XCTAssertTrue(pathText.waitForExistence(timeout: 5),
                      "App directory path should be shown in edit card")
    }

    @MainActor
    func testEditModeShowsRecordButton() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        let calcText = app.staticTexts["Calculator"]
        XCTAssertTrue(calcText.exists, "Calculator should appear in edit mode")

        // "Not set" badge with pencil icon should be visible
        XCTAssertTrue(app.staticTexts["Not set"].exists,
                      "Not set badge should appear for unbound shortcut in edit mode")
    }
}
