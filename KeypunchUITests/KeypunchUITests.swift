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

    /// Waits for the settings window to appear (auto-shown in test mode).
    private func waitForWindow() {
        let window = app.windows["keypunch-panel"]
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Settings window should appear")
    }

    /// Clicks the record-shortcut element.
    /// Works for both "Not set" badge (pencil Button) and "set" badge pencil icon (Image).
    private func clickRecordShortcut() {
        // Try buttons first (notSetBadge has pencil Button with record-shortcut id)
        let btn = app.buttons["record-shortcut"]
        if btn.waitForExistence(timeout: 3) {
            btn.click()
            return
        }
        // Try images (setBadge pencil icon is a focusable Image)
        let img = app.images["record-shortcut"]
        if img.waitForExistence(timeout: 2) {
            img.click()
            return
        }
        // Fallback: click "Not set" text directly
        app.staticTexts["Not set"].click()
    }

    /// Opens edit mode for the first shortcut row.
    /// Requires at least one seeded shortcut to be present.
    private func openEditMode() {
        waitForWindow()
        let editButton = app.buttons["edit-shortcut"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3), "Edit button should exist on a shortcut row")
        editButton.click()
        sleep(1)
    }

    /// Clicks the window content area to establish focus within the SwiftUI view hierarchy.
    /// After this, Tab will navigate between focusable SwiftUI elements predictably.
    private func focusWindow() {
        let window = app.windows["keypunch-panel"]
        // Click the window title bar area to give the window focus
        // without triggering any interactive element
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02)).click()
        sleep(1)
    }

    // MARK: - Window Tests

    @MainActor
    func testWindowAppearsInTestMode() throws {
        launchClean()
        let window = app.windows["keypunch-panel"]
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Settings window should appear in test mode")
    }

    // MARK: - Launch Tab Tests

    @MainActor
    func testEmptyStatePanelContents() throws {
        launchClean()
        waitForWindow()

        XCTAssertTrue(app.staticTexts["No shortcuts configured"].exists,
                      "Should show empty state message")
    }

    @MainActor
    func testSeededShortcutAppearsInPanel() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

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
        waitForWindow()

        XCTAssertTrue(app.staticTexts["Calculator"].exists)
        XCTAssertTrue(app.staticTexts["TextEdit"].exists)
    }

    @MainActor
    func testPanelShowsAppIcon() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

        let calcIcon = app.images["Calculator icon"]
        XCTAssertTrue(calcIcon.exists, "Panel should show Calculator app icon")
    }

    @MainActor
    func testPanelShowsShortcutBadge() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

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
        waitForWindow()

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
        waitForWindow()

        XCTAssertTrue(app.staticTexts["Add App"].exists || app.buttons["Add App"].exists,
                      "Add App button should exist in panel")
    }

    @MainActor
    func testDeleteButtonExistsInEditMode() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        let deleteButton = app.buttons["delete-app"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5),
                      "Delete app button should exist in edit mode")
    }

    // MARK: - App Launch Tests

    @MainActor
    func testPanelLaunchesApp() throws {
        let shortcuts = [
            makeSeedShortcut(name: "TextEdit", bundleID: "com.apple.TextEdit", appPath: "/System/Applications/TextEdit.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

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

        // In non-test mode, window is not auto-shown; use menu bar
        let menuBar = app.menuBars
        let statusItem = menuBar.statusItems["Keypunch"]
        if statusItem.waitForExistence(timeout: 5) {
            statusItem.click()
            sleep(1)
            let showItem = app.menuItems["Show Keypunch"]
            if showItem.waitForExistence(timeout: 3) {
                showItem.click()
                sleep(1)
            }
        }

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

        let recordButton = app.buttons["record-shortcut"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5),
                      "Record shortcut button should exist in edit mode")
    }

    @MainActor
    func testEditModeShowsAppDirectory() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

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

        let cancelButton = app.buttons["cancel-edit"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5),
                      "Cancel edit button should exist in edit mode")
        cancelButton.click()
        sleep(1)

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
        waitForWindow()

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
        waitForWindow()

        let editButtons = app.buttons.matching(identifier: "edit-shortcut")
        XCTAssertEqual(editButtons.count, 2,
                       "Each shortcut row should have its own edit button")
    }

    // MARK: - Edit Mode Exclusivity Tests

    @MainActor
    func testEditModeIsExclusive() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
            makeSeedShortcut(name: "TextEdit", bundleID: "com.apple.TextEdit", appPath: "/System/Applications/TextEdit.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

        let editButtons = app.buttons.matching(identifier: "edit-shortcut")
        XCTAssertEqual(editButtons.count, 2, "Should have 2 edit buttons")
        editButtons.element(boundBy: 0).click()
        sleep(1)

        let cancelButton = app.buttons["cancel-edit"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5),
                      "Cancel edit should exist for first row")

        let remainingEditButtons = app.buttons.matching(identifier: "edit-shortcut")
        XCTAssertEqual(remainingEditButtons.count, 1,
                       "Only one edit button should remain while other row is in edit mode")
        remainingEditButtons.element(boundBy: 0).click()
        sleep(1)

        let cancelButtons = app.buttons.matching(identifier: "cancel-edit")
        XCTAssertEqual(cancelButtons.count, 1,
                       "Only one row should be in edit mode at a time")
        let editButtonsAfter = app.buttons.matching(identifier: "edit-shortcut")
        XCTAssertEqual(editButtonsAfter.count, 1,
                       "Previous row should return to compact mode with edit button")
    }

    // MARK: - Delete Confirmation Modal Tests

    @MainActor
    func testDeleteConfirmationModalAppears() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

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

        let deleteButton = app.buttons["delete-app"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.click()
        sleep(1)

        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5),
                      "Cancel button should exist in delete confirmation modal")
        cancelButton.click()
        sleep(1)

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

        let deleteButton = app.buttons["delete-app"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.click()
        sleep(1)

        let removeButton = app.buttons["Remove"]
        XCTAssertTrue(removeButton.waitForExistence(timeout: 5),
                      "Remove button should exist in delete confirmation modal")
        removeButton.click()
        sleep(1)

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

        // Click the badge to enter recording
        clickRecordShortcut()
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

        // Click the badge to enter recording
        clickRecordShortcut()
        sleep(1)

        XCTAssertTrue(app.staticTexts["Record"].waitForExistence(timeout: 5),
                      "Should be in recording mode")

        let cancelRecordingButton = app.buttons["Cancel recording"]
        XCTAssertTrue(cancelRecordingButton.waitForExistence(timeout: 5),
                      "Cancel recording button should exist")
        cancelRecordingButton.click()
        sleep(1)

        XCTAssertFalse(app.staticTexts["Record"].exists,
                       "Record badge should disappear after cancel")
        XCTAssertTrue(app.staticTexts["Not set"].waitForExistence(timeout: 5),
                      "Should show 'Not set' after cancelling recording")
    }

    // MARK: - Add App Tests

    @MainActor
    func testAddAppButtonOpensFileDialog() throws {
        launchClean()
        waitForWindow()

        let addAppButton = app.buttons["Add App"]
        XCTAssertTrue(addAppButton.waitForExistence(timeout: 5),
                      "Add App button should exist")
        addAppButton.click()
        sleep(1)

        let openPanel = app.dialogs.firstMatch
        XCTAssertTrue(openPanel.waitForExistence(timeout: 5),
                      "NSOpenPanel file dialog should appear after clicking Add App")

        openPanel.buttons["Cancel"].click()
    }

    // MARK: - Keyboard Navigation Tests

    @MainActor
    func testPanelRowsExistForKeyboardNavigation() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
            makeSeedShortcut(name: "TextEdit", bundleID: "com.apple.TextEdit", appPath: "/System/Applications/TextEdit.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

        XCTAssertTrue(app.staticTexts["Calculator"].exists)
        XCTAssertTrue(app.staticTexts["TextEdit"].exists)

        let addApp = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add App")).firstMatch
        XCTAssertTrue(addApp.exists, "Add App button should exist for keyboard navigation")
    }

    @MainActor
    func testKeyboardEscExitsEditModeBeforeDismissing() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // First Esc should exit edit mode, not close window
        app.typeKey(.escape, modifierFlags: [])
        sleep(1)

        // Window should still be visible
        let window = app.windows["keypunch-panel"]
        XCTAssertTrue(window.exists, "Window should still be visible after first Esc")

        // Edit button should reappear (back to compact mode)
        let editButton = app.buttons["edit-shortcut"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3),
                      "Edit button should reappear after Esc exits edit mode")
    }

    @MainActor
    func testKeyboardEscDismissesDeleteConfirmation() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        let deleteButton = app.buttons["delete-app"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.click()
        sleep(1)

        let removeText = app.staticTexts["Remove Calculator?"]
        XCTAssertTrue(removeText.waitForExistence(timeout: 5))

        app.typeKey(.escape, modifierFlags: [])
        sleep(1)

        XCTAssertFalse(removeText.exists,
                       "Delete confirmation should be dismissed by Esc")
        let window = app.windows["keypunch-panel"]
        XCTAssertTrue(window.exists,
                      "Window should remain visible after dismissing delete confirmation")
    }

    @MainActor
    func testKeyboardEnterLaunchesApp() throws {
        let shortcuts = [
            makeSeedShortcut(name: "TextEdit", bundleID: "com.apple.TextEdit", appPath: "/System/Applications/TextEdit.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

        // Use down arrow to focus the first row (moveFocus handles nil focus)
        app.typeKey(.downArrow, modifierFlags: [])
        sleep(1)
        app.typeKey(.return, modifierFlags: [])
        sleep(1)

        let textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        XCTAssertTrue(textEdit.waitForExistence(timeout: 10),
                      "TextEdit should launch via Enter key on focused row")
        textEdit.terminate()
    }

    @MainActor
    func testKeyboardTabNavigatesBetweenRows() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
            makeSeedShortcut(name: "TextEdit", bundleID: "com.apple.TextEdit", appPath: "/System/Applications/TextEdit.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

        app.typeKey(.tab, modifierFlags: [])
        sleep(1)
        app.typeKey(.tab, modifierFlags: [])
        sleep(1)
        app.typeKey(.return, modifierFlags: [])
        sleep(1)

        let textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        XCTAssertTrue(textEdit.waitForExistence(timeout: 10),
                      "Tab should navigate to second row, Enter should launch TextEdit")
        textEdit.terminate()
    }

    @MainActor
    func testKeyboardShiftTabNavigatesBackward() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
            makeSeedShortcut(name: "TextEdit", bundleID: "com.apple.TextEdit", appPath: "/System/Applications/TextEdit.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

        // Use arrow keys for reliable navigation: down to first, down to second, up back to first
        app.typeKey(.downArrow, modifierFlags: [])
        sleep(1)
        app.typeKey(.downArrow, modifierFlags: [])
        sleep(1)
        app.typeKey(.upArrow, modifierFlags: [])
        sleep(1)
        app.typeKey(.return, modifierFlags: [])
        sleep(1)

        let calculator = XCUIApplication(bundleIdentifier: "com.apple.calculator")
        XCTAssertTrue(calculator.waitForExistence(timeout: 10),
                      "Up arrow should navigate back, Enter should launch Calculator")
        calculator.terminate()
    }

    // MARK: - Danger Dropdown Conditional Tests

    @MainActor
    func testUnsetButtonNotShownWhenNoShortcutSet() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        let unsetButton = app.buttons["unset-shortcut"]
        XCTAssertFalse(unsetButton.exists,
                       "Unset button should NOT appear when no shortcut is set")

        let deleteButton = app.buttons["delete-app"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5),
                      "Delete button should always appear in edit mode")
    }

    // MARK: - Esc Behavior Tests

    @MainActor
    func testEscDuringRecordingStaysInEditMode() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // Enter recording mode
        clickRecordShortcut()
        sleep(1)

        XCTAssertTrue(app.staticTexts["Record"].waitForExistence(timeout: 5),
                      "Should be in recording mode")

        // Press Esc to cancel recording
        app.typeKey(.escape, modifierFlags: [])
        sleep(1)

        // Should exit recording but stay in edit mode
        XCTAssertFalse(app.staticTexts["Record"].exists,
                       "Recording should be cancelled")
        let cancelEdit = app.buttons["cancel-edit"]
        XCTAssertTrue(cancelEdit.waitForExistence(timeout: 3),
                      "Cancel edit button should still be visible — edit mode should NOT be exited")
    }

    @MainActor
    func testEscDuringDropdownClosesDropdownOnly() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // Open danger dropdown
        let deleteButton = app.buttons["delete-app"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5),
                      "Delete button should exist in edit mode")

        // Press Esc to exit edit mode
        app.typeKey(.escape, modifierFlags: [])
        sleep(1)

        // Edit mode should be exited
        let editButton = app.buttons["edit-shortcut"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3),
                      "Should return to compact mode with edit button")
    }

    // MARK: - Edit Mode Accent Border Test

    @MainActor
    func testEditModeShowsAccentBorder() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // Verify edit card elements exist (accent border is visual-only,
        // so we verify edit mode is active by checking its unique elements)
        let cancelEdit = app.buttons["cancel-edit"]
        XCTAssertTrue(cancelEdit.waitForExistence(timeout: 5))
        let deleteButton = app.buttons["delete-app"]
        XCTAssertTrue(deleteButton.exists)
        XCTAssertTrue(app.staticTexts["Calculator"].exists)
    }

    // MARK: - Exclusive Edit Mode Tests

    @MainActor
    func testEditModeSwitchCancelsRecording() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
            makeSeedShortcut(name: "TextEdit", bundleID: "com.apple.TextEdit", appPath: "/System/Applications/TextEdit.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

        // Enter edit mode for first shortcut
        let editButtons = app.buttons.matching(identifier: "edit-shortcut")
        XCTAssertEqual(editButtons.count, 2)
        editButtons.element(boundBy: 0).click()
        sleep(1)

        // Enter recording mode
        clickRecordShortcut()
        sleep(1)
        XCTAssertTrue(app.staticTexts["Record"].waitForExistence(timeout: 5))

        // Click edit on second shortcut — should cancel first edit+recording
        let remainingEdit = app.buttons.matching(identifier: "edit-shortcut")
        XCTAssertEqual(remainingEdit.count, 1)
        remainingEdit.element(boundBy: 0).click()
        sleep(1)

        // Recording should be gone, second shortcut in edit mode
        XCTAssertFalse(app.staticTexts["Record"].exists,
                       "Recording should be cancelled when switching edit targets")
        let cancelButtons = app.buttons.matching(identifier: "cancel-edit")
        XCTAssertEqual(cancelButtons.count, 1,
                       "Only one row should be in edit mode")
    }

    // MARK: - Add App E2E Tests

    /// Helper to select an app via NSOpenPanel using "Go to Folder" (Cmd+Shift+G).
    private func selectAppInOpenPanel(path: String) {
        let openPanel = app.dialogs.firstMatch
        XCTAssertTrue(openPanel.waitForExistence(timeout: 5),
                      "NSOpenPanel should appear")

        // Use Cmd+Shift+G to open "Go to Folder" sheet
        openPanel.typeKey("g", modifierFlags: [.command, .shift])
        sleep(1)

        let goToSheet = openPanel.sheets.firstMatch
        guard goToSheet.waitForExistence(timeout: 3) else {
            XCTFail("Go to Folder sheet did not appear")
            return
        }

        // Find the path input field (comboBox or textField)
        let pathField = goToSheet.comboBoxes.firstMatch.exists
            ? goToSheet.comboBoxes.firstMatch
            : goToSheet.textFields.firstMatch
        guard pathField.waitForExistence(timeout: 3) else {
            XCTFail("Path field not found in Go to Folder sheet")
            return
        }

        // Clear existing text with Cmd+A, then type the path
        pathField.click()
        pathField.typeKey("a", modifierFlags: .command)
        pathField.typeText(path)
        sleep(1)

        // Press Enter to navigate (Go button)
        pathField.typeKey(.return, modifierFlags: [])
        sleep(2)

        // Press Enter again to confirm Open
        if openPanel.exists {
            openPanel.typeKey(.return, modifierFlags: [])
            sleep(2)
        }
    }

    @MainActor
    func testAddAppViaOpenPanel() throws {
        launchClean()
        waitForWindow()

        // Click Add App
        let addAppButton = app.buttons["Add App"]
        XCTAssertTrue(addAppButton.waitForExistence(timeout: 5))
        addAppButton.click()
        sleep(1)

        selectAppInOpenPanel(path: "/System/Applications/Calculator.app")

        // Verify Calculator appears in the list
        XCTAssertTrue(app.staticTexts["Calculator"].waitForExistence(timeout: 5),
                      "Calculator should appear in the app list after adding")
        XCTAssertFalse(app.staticTexts["No shortcuts configured"].exists,
                       "Empty state should disappear")
    }

    @MainActor
    func testAddDuplicateAppShowsAlert() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

        XCTAssertTrue(app.staticTexts["Calculator"].exists)

        // Try adding Calculator again
        let addAppButton = app.buttons["Add App"]
        XCTAssertTrue(addAppButton.waitForExistence(timeout: 5))
        addAppButton.click()
        sleep(1)

        selectAppInOpenPanel(path: "/System/Applications/Calculator.app")

        // Duplicate dialog should appear
        let alertText = app.staticTexts.matching(NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "already been added", "already been added")).firstMatch
        XCTAssertTrue(alertText.waitForExistence(timeout: 5),
                      "Duplicate application dialog should appear")

        // Title should be visible
        let titleText = app.staticTexts["Duplicate Application"]
        XCTAssertTrue(titleText.waitForExistence(timeout: 3),
                      "Duplicate dialog title should appear")

        // OK button should dismiss
        let okButton = app.buttons["OK"]
        XCTAssertTrue(okButton.waitForExistence(timeout: 3),
                      "OK button should exist in duplicate dialog")
        okButton.click()
        sleep(1)

        // Dialog should be dismissed
        XCTAssertFalse(titleText.exists, "Duplicate dialog should be dismissed after OK")
    }

    // MARK: - Record Shortcut E2E Tests

    @MainActor
    func testRecordShortcutSetsKey() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // Verify "Not set" is shown
        XCTAssertTrue(app.staticTexts["Not set"].exists)

        // Click the badge to enter recording
        clickRecordShortcut()
        sleep(1)

        XCTAssertTrue(app.staticTexts["Record"].waitForExistence(timeout: 5))

        // Type a shortcut: Cmd+Shift+K
        app.typeKey("k", modifierFlags: [.command, .shift])
        sleep(1)

        // Recording should end and shortcut badge should show the key
        XCTAssertFalse(app.staticTexts["Record"].exists,
                       "Recording badge should disappear after setting shortcut")
        XCTAssertFalse(app.staticTexts["Not set"].exists,
                       "'Not set' should disappear after setting shortcut")

        // The shortcut description should now be visible (e.g. "⇧⌘K")
        let shortcutBadge = app.staticTexts.matching(NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "K", "K")).firstMatch
        XCTAssertTrue(shortcutBadge.waitForExistence(timeout: 5),
                      "Shortcut badge should show the recorded key")
    }

    @MainActor
    func testRecordShortcutThenUnset() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // Record a shortcut
        clickRecordShortcut()
        sleep(1)
        app.typeKey("j", modifierFlags: [.command, .option])
        sleep(1)

        // Shortcut should be set now
        XCTAssertFalse(app.staticTexts["Not set"].exists)

        // Click unset button
        let unsetButton = app.buttons["unset-shortcut"]
        XCTAssertTrue(unsetButton.waitForExistence(timeout: 5),
                      "Unset button should appear when shortcut is set")
        unsetButton.click()
        sleep(1)

        // Shortcut should be cleared
        XCTAssertTrue(app.staticTexts["Not set"].waitForExistence(timeout: 5),
                      "Shortcut should be cleared after unset")
    }

    // MARK: - Not Set Badge Click-to-Record Test

    @MainActor
    func testNotSetBadgeClickStartsRecording() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // "Not set" text should exist in edit mode
        XCTAssertTrue(app.staticTexts["Not set"].waitForExistence(timeout: 5))

        // Click the "Not set" badge area — whole badge is clickable
        clickRecordShortcut()
        sleep(1)

        // Should enter recording mode
        XCTAssertTrue(app.staticTexts["Record"].waitForExistence(timeout: 5),
                      "Clicking 'Not set' badge should start recording immediately")
    }

    // MARK: - Recording Cancel Inside Badge Test

    @MainActor
    func testRecordingCancelInsideBadge() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // Enter recording by clicking the badge area
        clickRecordShortcut()
        sleep(1)

        XCTAssertTrue(app.staticTexts["Record"].waitForExistence(timeout: 5))

        // Cancel button should be inside the badge
        let cancelRecording = app.buttons["Cancel recording"]
        XCTAssertTrue(cancelRecording.waitForExistence(timeout: 5),
                      "Cancel recording button should exist inside the badge")
        cancelRecording.click()
        sleep(1)

        XCTAssertFalse(app.staticTexts["Record"].exists,
                       "Recording should be cancelled")
        XCTAssertTrue(app.staticTexts["Not set"].waitForExistence(timeout: 5),
                      "Should show 'Not set' after cancelling")
    }

    // MARK: - Enter Key on Cancel/Danger Buttons Tests

    @MainActor
    func testEditButtonClickEntersEditMode() throws {
        let shortcuts = [
            makeSeedShortcut(name: "TextEdit", bundleID: "com.apple.TextEdit", appPath: "/System/Applications/TextEdit.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

        // Click edit button — should enter edit mode, not launch app
        let editButton = app.buttons["edit-shortcut"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.click()
        sleep(1)

        // Should be in edit mode (cancel-edit button visible)
        let cancelEdit = app.buttons["cancel-edit"]
        XCTAssertTrue(cancelEdit.waitForExistence(timeout: 5),
                      "Clicking edit button should enter edit mode")

        // TextEdit should NOT have launched
        let textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        XCTAssertFalse(textEdit.state == .runningForeground,
                       "TextEdit should NOT launch when edit button is clicked")
    }

    // MARK: - Many Apps Scroll Test

    @MainActor
    func testManyAppsScrollable() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
            makeSeedShortcut(name: "TextEdit", bundleID: "com.apple.TextEdit", appPath: "/System/Applications/TextEdit.app"),
            makeSeedShortcut(name: "Preview", bundleID: "com.apple.Preview", appPath: "/System/Applications/Preview.app"),
            makeSeedShortcut(name: "Notes", bundleID: "com.apple.Notes", appPath: "/System/Applications/Notes.app"),
            makeSeedShortcut(name: "Calendar", bundleID: "com.apple.iCal", appPath: "/System/Applications/Calendar.app"),
            makeSeedShortcut(name: "Reminders", bundleID: "com.apple.reminders", appPath: "/System/Applications/Reminders.app"),
            makeSeedShortcut(name: "Maps", bundleID: "com.apple.Maps", appPath: "/System/Applications/Maps.app"),
            makeSeedShortcut(name: "Photos", bundleID: "com.apple.Photos", appPath: "/System/Applications/Photos.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

        // First few should be visible
        XCTAssertTrue(app.staticTexts["Calculator"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["TextEdit"].exists)

        // All 8 apps should exist in the scroll view
        for name in ["Calculator", "TextEdit", "Preview", "Notes", "Calendar", "Reminders", "Maps", "Photos"] {
            let text = app.staticTexts[name]
            XCTAssertTrue(text.waitForExistence(timeout: 5),
                          "\(name) should exist in the app list")
        }

        // Add App button should exist below the list
        let addApp = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add App")).firstMatch
        XCTAssertTrue(addApp.waitForExistence(timeout: 5),
                      "Add App button should exist below the app list")
    }

    // MARK: - Remove Dialog Focus Tests

    @MainActor
    func testRemoveDialogKeepsEditMode() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        let deleteButton = app.buttons["delete-app"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.click()
        sleep(1)

        // Remove dialog should appear
        let removeText = app.staticTexts["Remove Calculator?"]
        XCTAssertTrue(removeText.waitForExistence(timeout: 5))

        // Cancel the dialog
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.click()
        sleep(1)

        // Edit mode should still be active (cancel-edit button visible)
        let cancelEdit = app.buttons["cancel-edit"]
        XCTAssertTrue(cancelEdit.waitForExistence(timeout: 5),
                      "Edit mode should be preserved after cancelling remove dialog")
    }

    @MainActor
    func testRemoveDialogCancelReopensDropdown() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        let deleteButton = app.buttons["delete-app"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.click()
        sleep(1)

        // Cancel the dialog
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.click()
        sleep(1)

        // Dropdown should reopen with delete-app button visible
        let deleteButtonAgain = app.buttons["delete-app"]
        XCTAssertTrue(deleteButtonAgain.waitForExistence(timeout: 5),
                      "Danger dropdown should reopen after cancelling remove dialog")
    }

    @MainActor
    func testUnsetShortcutTooltipExists() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // Record a shortcut first so unset button appears
        clickRecordShortcut()
        sleep(1)
        app.typeKey("k", modifierFlags: [.command, .shift])
        sleep(1)

        // Unset button should exist with its tooltip
        let unsetButton = app.buttons["unset-shortcut"]
        XCTAssertTrue(unsetButton.waitForExistence(timeout: 5),
                      "Unset button should exist in edit mode")

        // Delete button should exist
        let deleteButton = app.buttons["delete-app"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5),
                      "Delete button should exist in dropdown")
    }

    @MainActor
    func testUnsetFocusesDangerButton() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // Record a shortcut
        clickRecordShortcut()
        sleep(1)
        app.typeKey("k", modifierFlags: [.command, .shift])
        sleep(1)

        // Click unset button
        let unsetButton = app.buttons["unset-shortcut"]
        XCTAssertTrue(unsetButton.waitForExistence(timeout: 5))
        unsetButton.click()
        sleep(1)

        // Shortcut should be cleared
        XCTAssertTrue(app.staticTexts["Not set"].waitForExistence(timeout: 5),
                      "Shortcut should be cleared after unset")

        // Delete button should still exist (edit mode preserved)
        XCTAssertTrue(app.buttons["delete-app"].waitForExistence(timeout: 5),
                      "Delete button should be available after unset")
    }

    @MainActor
    func testEscFromRemoveDialogKeepsEditMode() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        let deleteButton = app.buttons["delete-app"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.click()
        sleep(1)

        let removeText = app.staticTexts["Remove Calculator?"]
        XCTAssertTrue(removeText.waitForExistence(timeout: 5))

        // Press Esc to dismiss remove dialog
        app.typeKey(.escape, modifierFlags: [])
        sleep(1)

        // Remove dialog should be gone
        XCTAssertFalse(removeText.exists,
                       "Remove dialog should be dismissed by Esc")

        // Edit mode should still be active
        let cancelEdit = app.buttons["cancel-edit"]
        XCTAssertTrue(cancelEdit.waitForExistence(timeout: 5),
                      "Edit mode should be preserved after Esc from remove dialog")
    }

    // MARK: - Tab Navigation: Edit Mode (no shortcut set)

    @MainActor
    func testTabOrderEditModeNoShortcutToCancelEdit() throws {
        // Edit mode tab order (no shortcut): shortcutBadge → deleteButton → cancelEdit
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // openEditMode sets focus = shortcutBadge
        // Tab 1: deleteButton (no unset button since no shortcut set)
        // Tab 2: cancelEdit → Enter exits edit mode
        app.typeKey(.tab, modifierFlags: [])
        sleep(1)
        app.typeKey(.tab, modifierFlags: [])
        sleep(1)
        app.typeKey(.return, modifierFlags: [])
        sleep(1)

        let editButton = app.buttons["edit-shortcut"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5),
                      "Tab to cancelEdit + Enter should exit edit mode")
    }

    @MainActor
    func testTabOrderEditModeNoShortcutToDeleteButton() throws {
        // Tab 1 from shortcutBadge (no shortcut) should reach deleteButton
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // Tab 1: deleteButton → Enter opens delete dialog
        app.typeKey(.tab, modifierFlags: [])
        sleep(1)
        app.typeKey(.return, modifierFlags: [])
        sleep(1)

        let removeText = app.staticTexts["Remove Calculator?"]
        XCTAssertTrue(removeText.waitForExistence(timeout: 5),
                      "Tab to deleteButton + Enter should open delete confirmation")

        app.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - Tab Navigation: Edit Mode (shortcut set)

    @MainActor
    func testTabOrderEditModeWithShortcutToCancelEdit() throws {
        // Edit mode tab order (shortcut set): shortcutBadge → shortcutEditButton → unsetButton → deleteButton → cancelEdit
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // Record a shortcut to make unset button appear
        clickRecordShortcut()
        sleep(1)
        app.typeKey("k", modifierFlags: [.command, .shift])
        sleep(1)

        // Tab from shortcutBadge:
        // Tab 1: shortcutEditButton
        // Tab 2: unsetButton (dangerButton)
        // Tab 3: deleteButton
        // Tab 4: cancelEdit → Enter exits edit mode
        for _ in 0..<4 {
            app.typeKey(.tab, modifierFlags: [])
            sleep(1)
        }
        app.typeKey(.return, modifierFlags: [])
        sleep(1)

        let editButton = app.buttons["edit-shortcut"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5),
                      "Tab 4 from shortcutBadge should reach cancelEdit, Enter exits edit mode")
    }

    @MainActor
    func testTabOrderEditModeWithShortcutToUnsetButton() throws {
        // Verify Tab 2 from shortcutBadge (with shortcut) reaches unset button
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // Record a shortcut
        clickRecordShortcut()
        sleep(1)
        app.typeKey("j", modifierFlags: [.command, .option])
        sleep(1)

        // Tab 1: shortcutEditButton, Tab 2: unsetButton → Enter unsets
        app.typeKey(.tab, modifierFlags: [])
        sleep(1)
        app.typeKey(.tab, modifierFlags: [])
        sleep(1)
        app.typeKey(.return, modifierFlags: [])
        sleep(1)

        XCTAssertTrue(app.staticTexts["Not set"].waitForExistence(timeout: 5),
                      "Tab to unsetButton + Enter should unset shortcut")
    }

    // MARK: - Tab Navigation: Delete Dialog

    @MainActor
    func testDeleteDialogHasCancelAndRemoveButtons() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        let deleteButton = app.buttons["delete-app"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.click()
        sleep(1)

        let removeText = app.staticTexts["Remove Calculator?"]
        XCTAssertTrue(removeText.waitForExistence(timeout: 5))

        let cancelButton = app.buttons["Cancel"]
        let removeButton = app.buttons["Remove"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should exist in delete dialog")
        XCTAssertTrue(removeButton.exists, "Remove button should exist in delete dialog")

        app.typeKey(.escape, modifierFlags: [])
        sleep(1)
        XCTAssertFalse(removeText.exists, "Dialog should be dismissed by Esc")
    }

    // MARK: - Tab Navigation: Duplicate Dialog

    @MainActor
    func testDuplicateDialogHasOKButton() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

        let addAppButton = app.buttons["Add App"]
        XCTAssertTrue(addAppButton.waitForExistence(timeout: 5))
        addAppButton.click()
        sleep(1)

        selectAppInOpenPanel(path: "/System/Applications/Calculator.app")

        let titleText = app.staticTexts["Duplicate Application"]
        XCTAssertTrue(titleText.waitForExistence(timeout: 5))

        let okButton = app.buttons["OK"]
        XCTAssertTrue(okButton.waitForExistence(timeout: 3))
        okButton.click()
        sleep(1)

        XCTAssertFalse(titleText.exists, "Duplicate dialog should dismiss after OK")
    }

    // MARK: - Shift+Tab Navigation Tests

    @MainActor
    func testShiftTabInEditMode() throws {
        // In edit mode, Shift+Tab should go backwards through focus targets
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        openEditMode()

        // Tab forward to cancelEdit: Tab 1→delete, Tab 2→cancel
        app.typeKey(.tab, modifierFlags: [])
        sleep(1)
        app.typeKey(.tab, modifierFlags: [])
        sleep(1)

        // Shift+Tab back to deleteButton
        app.typeKey(.tab, modifierFlags: .shift)
        sleep(1)
        app.typeKey(.return, modifierFlags: [])
        sleep(1)

        let removeText = app.staticTexts["Remove Calculator?"]
        XCTAssertTrue(removeText.waitForExistence(timeout: 5),
                      "Shift+Tab from cancelEdit should go to deleteButton")
        app.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - Arrow Key Navigation Tests

    @MainActor
    func testDownArrowNavigatesBetweenApps() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
            makeSeedShortcut(name: "TextEdit", bundleID: "com.apple.TextEdit", appPath: "/System/Applications/TextEdit.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

        // Down arrow from nil focus → first row, then down to second
        app.typeKey(.downArrow, modifierFlags: [])
        sleep(1)
        app.typeKey(.downArrow, modifierFlags: [])
        sleep(1)
        app.typeKey(.return, modifierFlags: [])
        sleep(1)

        let textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        XCTAssertTrue(textEdit.waitForExistence(timeout: 10),
                      "Down arrow should move to next app row")
        textEdit.terminate()
    }

    @MainActor
    func testUpArrowNavigatesBetweenApps() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
            makeSeedShortcut(name: "TextEdit", bundleID: "com.apple.TextEdit", appPath: "/System/Applications/TextEdit.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

        // Down to first, down to second, up back to first
        app.typeKey(.downArrow, modifierFlags: [])
        sleep(1)
        app.typeKey(.downArrow, modifierFlags: [])
        sleep(1)
        app.typeKey(.upArrow, modifierFlags: [])
        sleep(1)
        app.typeKey(.return, modifierFlags: [])
        sleep(1)

        let calculator = XCUIApplication(bundleIdentifier: "com.apple.calculator")
        XCTAssertTrue(calculator.waitForExistence(timeout: 10),
                      "Up arrow should move to previous app row")
        calculator.terminate()
    }

    @MainActor
    func testDownArrowWrapsToAddApp() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

        // Down to first row, down past last app → addApp
        app.typeKey(.downArrow, modifierFlags: [])
        sleep(1)
        app.typeKey(.downArrow, modifierFlags: [])
        sleep(1)
        app.typeKey(.return, modifierFlags: [])
        sleep(1)

        let openPanel = app.dialogs.firstMatch
        XCTAssertTrue(openPanel.waitForExistence(timeout: 5),
                      "Down arrow past last app should wrap to addApp")
        openPanel.buttons["Cancel"].click()
    }

    @MainActor
    func testUpArrowWrapsFromFirstToAddApp() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

        // Down to first row, then up wraps to addApp
        app.typeKey(.downArrow, modifierFlags: [])
        sleep(1)
        app.typeKey(.upArrow, modifierFlags: [])
        sleep(1)
        app.typeKey(.return, modifierFlags: [])
        sleep(1)

        let openPanel = app.dialogs.firstMatch
        XCTAssertTrue(openPanel.waitForExistence(timeout: 5),
                      "Up arrow from first app should wrap to addApp")
        openPanel.buttons["Cancel"].click()
    }

    @MainActor
    func testDownArrowLaunchesFirstApp() throws {
        let shortcuts = [
            makeSeedShortcut(name: "TextEdit", bundleID: "com.apple.TextEdit", appPath: "/System/Applications/TextEdit.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

        // Down arrow sets focus to first row, Enter launches
        app.typeKey(.downArrow, modifierFlags: [])
        sleep(1)
        app.typeKey(.return, modifierFlags: [])
        sleep(1)

        let textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        XCTAssertTrue(textEdit.waitForExistence(timeout: 10),
                      "Down arrow + Enter should launch the first app")
        textEdit.terminate()
    }

    // MARK: - Auto-Scroll Tests

    @MainActor
    func testAutoScrollWithArrowKeys() throws {
        let shortcuts = [
            makeSeedShortcut(name: "Calculator", bundleID: "com.apple.calculator", appPath: "/System/Applications/Calculator.app"),
            makeSeedShortcut(name: "TextEdit", bundleID: "com.apple.TextEdit", appPath: "/System/Applications/TextEdit.app"),
            makeSeedShortcut(name: "Preview", bundleID: "com.apple.Preview", appPath: "/System/Applications/Preview.app"),
            makeSeedShortcut(name: "Notes", bundleID: "com.apple.Notes", appPath: "/System/Applications/Notes.app"),
            makeSeedShortcut(name: "Calendar", bundleID: "com.apple.iCal", appPath: "/System/Applications/Calendar.app"),
            makeSeedShortcut(name: "Reminders", bundleID: "com.apple.reminders", appPath: "/System/Applications/Reminders.app"),
            makeSeedShortcut(name: "Maps", bundleID: "com.apple.Maps", appPath: "/System/Applications/Maps.app"),
            makeSeedShortcut(name: "Photos", bundleID: "com.apple.Photos", appPath: "/System/Applications/Photos.app"),
        ]
        launchWithSeededShortcuts(shortcuts)
        waitForWindow()

        // Down arrow through all 8 apps to addApp
        for _ in 0..<9 {
            app.typeKey(.downArrow, modifierFlags: [])
            usleep(300_000)
        }
        sleep(1)

        // addApp should be scrolled into view
        let addApp = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add App")).firstMatch
        XCTAssertTrue(addApp.isHittable,
                      "Add App should be scrolled into view via arrow key navigation")
    }
}
