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

    /// Opens the panel and enters edit mode for the first shortcut row.
    /// Requires at least one seeded shortcut to be present.
    private func openEditMode() {
        openPanel()
        let editButton = app.buttons["edit-shortcut"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3), "Edit button should exist on a shortcut row")
        editButton.click()
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

    // MARK: - Edit Mode Tests

    @MainActor
    func testEditButtonExistsOnRow() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openPanel()

        let editButton = app.buttons["edit-shortcut"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Edit button should exist on shortcut row")
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
    func testPanelShowsAddAppButton() throws {
        launchClean()
        openPanel()

        XCTAssertTrue(app.staticTexts["Add App"].exists || app.buttons["Add App"].exists,
                      "Add App button should exist in panel")
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

    @MainActor
    func testCancelEditExitsEditMode() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // Cancel edit button should exist
        let cancelButton = app.buttons["cancel-edit"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5),
                      "Cancel edit button should exist in edit mode")
        cancelButton.click()
        sleep(1)

        // After canceling, the edit button should be visible again (back to compact row)
        let editButton = app.buttons["edit-shortcut"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5),
                      "Should return to compact mode with edit button visible")
    }

    @MainActor
    func testEditModeShowsCancelEditButton() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        let cancelButton = app.buttons["cancel-edit"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5),
                      "Cancel edit (X) button should exist in edit mode")
    }

    // MARK: - Compact Row Tests

    @MainActor
    func testCompactRowShowsAppDirectory() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openPanel()

        let pathText = app.staticTexts["/System/Applications"]
        XCTAssertTrue(pathText.waitForExistence(timeout: 5),
                      "Compact row should show app directory path")
    }

    @MainActor
    func testMultipleShortcutsShowSeparateEditButtons() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
            makeSeedShortcut(name: "TextEdit", bundleID: "com.apple.TextEdit", appPath: "/System/Applications/TextEdit.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openPanel()

        let editButtons = app.buttons.matching(identifier: "edit-shortcut")
        XCTAssertEqual(editButtons.count, 2,
                       "Each shortcut row should have its own edit button")
    }

    // MARK: - Delete Confirmation Modal Tests

    @MainActor
    func testDeleteConfirmationModalAppears() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        let dangerButton = app.buttons["danger-trigger"]
        XCTAssertTrue(dangerButton.waitForExistence(timeout: 5))
        dangerButton.click()
        sleep(1)

        let deleteButton = app.buttons["delete-app"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.click()
        sleep(1)

        let removeText = app.staticTexts["Remove Calculator?"]
        XCTAssertTrue(removeText.waitForExistence(timeout: 5),
                      "Delete confirmation modal should show 'Remove Calculator?'")
    }

    @MainActor
    func testDeleteConfirmationCancelKeepsShortcut() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        let dangerButton = app.buttons["danger-trigger"]
        XCTAssertTrue(dangerButton.waitForExistence(timeout: 5))
        dangerButton.click()
        sleep(1)

        let deleteButton = app.buttons["delete-app"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.click()
        sleep(1)

        // Click Cancel in delete confirmation
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5),
                      "Cancel button should exist in delete confirmation modal")
        cancelButton.click()
        sleep(1)

        // Shortcut should still exist
        XCTAssertTrue(app.staticTexts["Calculator"].waitForExistence(timeout: 5),
                      "Calculator should still exist after cancelling delete")
    }

    @MainActor
    func testDeleteConfirmationRemoveDeletesShortcut() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        let dangerButton = app.buttons["danger-trigger"]
        XCTAssertTrue(dangerButton.waitForExistence(timeout: 5))
        dangerButton.click()
        sleep(1)

        let deleteButton = app.buttons["delete-app"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.click()
        sleep(1)

        // Click Remove in delete confirmation
        let removeButton = app.buttons["Remove"]
        XCTAssertTrue(removeButton.waitForExistence(timeout: 5),
                      "Remove button should exist in delete confirmation modal")
        removeButton.click()
        sleep(1)

        // Shortcut should be deleted, showing empty state
        XCTAssertTrue(app.staticTexts["No shortcuts configured"].waitForExistence(timeout: 5),
                      "Should show empty state after removing the only shortcut")
    }

    // MARK: - Recording Mode Tests

    @MainActor
    func testRecordingModeShowsRecordBadge() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        let recordButton = app.buttons["record-shortcut"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5))
        recordButton.click()
        sleep(1)

        XCTAssertTrue(app.staticTexts["Record"].waitForExistence(timeout: 5),
                      "Record badge should appear when in recording mode")
    }

    @MainActor
    func testRecordingCancelButtonExitsRecording() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        let recordButton = app.buttons["record-shortcut"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5))
        recordButton.click()
        sleep(1)

        XCTAssertTrue(app.staticTexts["Record"].waitForExistence(timeout: 5),
                      "Should be in recording mode")

        // Click cancel recording button (X inside amber badge)
        let cancelRecordingButton = app.buttons["Cancel recording"]
        XCTAssertTrue(cancelRecordingButton.waitForExistence(timeout: 5),
                      "Cancel recording button should exist")
        cancelRecordingButton.click()
        sleep(1)

        // "Record" badge should disappear, back to "Not set"
        XCTAssertFalse(app.staticTexts["Record"].exists,
                       "Record badge should disappear after cancel")
        XCTAssertTrue(app.staticTexts["Not set"].waitForExistence(timeout: 5),
                      "Should show 'Not set' after cancelling recording")
    }

    // MARK: - Danger Dropdown Conditional Tests

    @MainActor
    func testUnsetButtonNotShownWhenNoShortcutSet() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        let dangerButton = app.buttons["danger-trigger"]
        XCTAssertTrue(dangerButton.waitForExistence(timeout: 5))
        dangerButton.click()
        sleep(1)

        // Unset button should NOT appear when no shortcut key is bound
        let unsetButton = app.buttons["unset-shortcut"]
        XCTAssertFalse(unsetButton.exists,
                       "Unset button should NOT appear when no shortcut is set")

        // Delete button should still appear
        let deleteButton = app.buttons["delete-app"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5),
                      "Delete button should always appear in danger dropdown")
    }
}
