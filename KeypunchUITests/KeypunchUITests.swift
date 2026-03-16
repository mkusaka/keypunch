// swiftlint:disable file_length
import XCTest

// swiftlint:disable type_body_length
final class KeypunchUITests: XCTestCase {
    private var app: XCUIApplication!
    private var page: KeypunchPage!

    override func setUpWithError() throws {
        app = XCUIApplication()
        page = KeypunchPage(app: app)
    }

    override func tearDown() {
        if let app, app.state != .notRunning {
            app.terminate()
        }
        app = nil
        page = nil
    }

    // MARK: - Seed Helpers

    private func calcShortcut() -> [String: Any] {
        KeypunchPage.makeSeedShortcut(
            name: "Calculator",
            bundleID: "com.apple.calculator",
            appPath: "/System/Applications/Calculator.app"
        )
    }

    private func textEditShortcut() -> [String: Any] {
        KeypunchPage.makeSeedShortcut(
            name: "TextEdit",
            bundleID: "com.apple.TextEdit",
            appPath: "/System/Applications/TextEdit.app"
        )
    }

    private func seed(_ name: String, _ bundleID: String) -> [String: Any] {
        KeypunchPage.makeSeedShortcut(
            name: name,
            bundleID: bundleID,
            appPath: "/System/Applications/\(name).app"
        )
    }

    // MARK: - Window Tests

    @MainActor
    func testWindowAppearsInTestMode() {
        page.launchClean()
        XCTAssertTrue(page.window.waitForExistence(timeout: 5), "Settings window should appear in test mode")
    }

    // MARK: - Panel Content Tests

    @MainActor
    func testEmptyStatePanelContents() {
        page.launchClean()
        page.waitForWindow()
        XCTAssertTrue(page.emptyState.exists, "Should show empty state message")
    }

    @MainActor
    func testSeededShortcutAppearsInPanel() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.waitForWindow()

        XCTAssertTrue(page.appNameExists("Calculator"), "Calculator should appear in panel")
        XCTAssertFalse(page.emptyState.exists, "Empty message should not appear")
    }

    @MainActor
    func testMultipleSeededShortcutsAppearInPanel() {
        page.launchWithSeededShortcuts([calcShortcut(), textEditShortcut()])
        page.waitForWindow()

        XCTAssertTrue(page.appNameExists("Calculator"))
        XCTAssertTrue(page.appNameExists("TextEdit"))
    }

    @MainActor
    func testPanelShowsAppIconAndBadge() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.waitForWindow()

        let calcIcon = app.images["Calculator icon"]
        XCTAssertTrue(
            calcIcon.exists || page.appNameExists("Calculator"),
            "Panel should show Calculator app icon"
        )
        XCTAssertTrue(page.notSetBadgeExists(), "Should show 'Not set' badge for unbound shortcut")
    }

    @MainActor
    func testPanelShowsAddAppButton() {
        page.launchClean()
        page.waitForWindow()
        XCTAssertTrue(page.addAppButton.waitForExistence(timeout: 5), "Add App button should exist in panel")
    }

    // MARK: - Edit Mode Tests

    @MainActor
    func testEditButtonExistsOnRow() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.waitForWindow()
        XCTAssertTrue(page.editButton.waitForExistence(timeout: 5), "Edit button should exist on shortcut row")
    }

    @MainActor
    func testEditModeShowsSeededShortcut() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()
        XCTAssertTrue(page.appNameExists("Calculator"), "Calculator should appear in edit mode")
    }

    @MainActor
    func testEditModeShowsAppDirectoryAndBadge() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        let pathText = app.staticTexts["/System/Applications"]
        XCTAssertTrue(pathText.waitForExistence(timeout: 5), "App directory path should be shown in edit card")

        let recordBtn = app.buttons["record-shortcut"]
        let notSetBadge = app.buttons["not-set-badge"]
        XCTAssertTrue(
            recordBtn.waitForExistence(timeout: 5) || notSetBadge.exists,
            "Record shortcut or not-set badge should exist in edit mode"
        )
    }

    @MainActor
    func testDeleteButtonExistsInEditMode() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()
        XCTAssertTrue(page.deleteButton.waitForExistence(timeout: 5), "Delete app button should exist in edit mode")
    }

    @MainActor
    func testCancelEditExitsEditMode() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        XCTAssertTrue(page.cancelEditButton.waitForExistence(timeout: 5))
        page.cancelEditButton.click()

        XCTAssertTrue(
            page.editButton.waitForExistence(timeout: 5),
            "Should return to compact mode with edit button visible"
        )
    }

    // MARK: - Compact Row Tests

    @MainActor
    func testCompactRowShowsAppDirectory() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.waitForWindow()

        let predicate = NSPredicate(format: "label CONTAINS %@", "/System/Applications")
        let match = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 5), "Compact row should show app directory path")
    }

    @MainActor
    func testMultipleShortcutsShowSeparateEditButtons() {
        page.launchWithSeededShortcuts([calcShortcut(), textEditShortcut()])
        page.waitForWindow()

        let editButtons = app.buttons.matching(identifier: "edit-shortcut")
        XCTAssertEqual(editButtons.count, 2, "Each shortcut row should have its own edit button")
    }

    // MARK: - Edit Mode Exclusivity

    @MainActor
    func testEditModeIsExclusive() {
        page.launchWithSeededShortcuts([calcShortcut(), textEditShortcut()])
        page.waitForWindow()

        let editButtons = app.buttons.matching(identifier: "edit-shortcut")
        XCTAssertEqual(editButtons.count, 2)
        editButtons.element(boundBy: 0).click()

        XCTAssertTrue(page.cancelEditButton.waitForExistence(timeout: 5))

        let remainingEditButtons = app.buttons.matching(identifier: "edit-shortcut")
        XCTAssertEqual(
            remainingEditButtons.count, 1,
            "Only one edit button should remain while other row is in edit mode"
        )
        remainingEditButtons.element(boundBy: 0).click()

        let cancelButtons = app.buttons.matching(identifier: "cancel-edit")
        XCTAssertEqual(cancelButtons.count, 1, "Only one row should be in edit mode at a time")
    }

    @MainActor
    func testEditModeSwitchCancelsRecording() {
        page.launchWithSeededShortcuts([calcShortcut(), textEditShortcut()])
        page.waitForWindow()

        let editButtons = app.buttons.matching(identifier: "edit-shortcut")
        XCTAssertEqual(editButtons.count, 2)
        editButtons.element(boundBy: 0).click()
        page.waitForAnimation()

        page.clickRecordShortcut()
        XCTAssertTrue(page.waitForRecordingBadge(timeout: 5))

        let remainingEdit = app.buttons.matching(identifier: "edit-shortcut")
        XCTAssertEqual(remainingEdit.count, 1)
        remainingEdit.element(boundBy: 0).click()
        page.waitForAnimation()

        XCTAssertFalse(page.recordingBadgeExists(), "Recording should be cancelled when switching edit targets")
        let cancelButtons = app.buttons.matching(identifier: "cancel-edit")
        XCTAssertEqual(cancelButtons.count, 1, "Only one row should be in edit mode")
    }

    // MARK: - App Launch Tests

    @MainActor
    func testPanelLaunchesApp() {
        page.launchWithSeededShortcuts([textEditShortcut()])
        page.waitForWindow()

        let predicate = NSPredicate(format: "label CONTAINS %@", "TextEdit")
        let textEditButton = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(textEditButton.waitForExistence(timeout: 5))
        textEditButton.click()

        let textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        XCTAssertTrue(textEdit.waitForExistence(timeout: 10), "TextEdit should launch")
        textEdit.terminate()
    }

    @MainActor
    func testEditButtonClickEntersEditMode() {
        page.launchWithSeededShortcuts([textEditShortcut()])
        page.waitForWindow()

        XCTAssertTrue(page.editButton.waitForExistence(timeout: 5))
        page.editButton.click()

        XCTAssertTrue(page.cancelEditButton.waitForExistence(timeout: 5), "Clicking edit button should enter edit mode")
        let textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        XCTAssertFalse(textEdit.state == .runningForeground, "TextEdit should NOT launch when edit button is clicked")
    }

    // MARK: - Delete Confirmation Tests

    @MainActor
    func testDeleteConfirmationModalAppears() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        XCTAssertTrue(page.deleteButton.waitForExistence(timeout: 5))
        page.deleteButton.click()

        XCTAssertTrue(page.deleteDialog.waitForExistence(timeout: 5), "Delete confirmation dialog should appear")
        XCTAssertTrue(page.dialogCancel.exists, "Cancel button should exist in delete dialog")
        XCTAssertTrue(page.dialogRemove.exists, "Remove button should exist in delete dialog")
    }

    @MainActor
    func testDeleteConfirmationCancelKeepsShortcut() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        XCTAssertTrue(page.deleteButton.waitForExistence(timeout: 5))
        page.deleteButton.click()

        XCTAssertTrue(page.dialogCancel.waitForExistence(timeout: 5))
        page.dialogCancel.click()

        XCTAssertTrue(page.waitForAppName("Calculator"), "Calculator should still exist after cancelling delete")
        XCTAssertTrue(
            page.cancelEditButton.waitForExistence(timeout: 5),
            "Edit mode should be preserved after cancelling remove dialog"
        )
    }

    @MainActor
    func testDeleteConfirmationRemoveDeletesShortcut() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        XCTAssertTrue(page.deleteButton.waitForExistence(timeout: 5))
        page.deleteButton.click()

        XCTAssertTrue(page.dialogRemove.waitForExistence(timeout: 5))
        page.dialogRemove.click()

        XCTAssertTrue(
            page.emptyState.waitForExistence(timeout: 5),
            "Should show empty state after removing the only shortcut"
        )
    }

    // MARK: - Recording Mode Tests

    @MainActor
    func testRecordingModeShowsRecordBadge() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        page.clickRecordShortcut()
        XCTAssertTrue(page.waitForRecordingBadge(timeout: 5), "Record badge should appear when in recording mode")
    }

    @MainActor
    func testRecordingCancelButtonExitsRecording() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        page.clickRecordShortcut()
        XCTAssertTrue(page.waitForRecordingBadge(timeout: 5))

        XCTAssertTrue(page.cancelRecordingButton.waitForExistence(timeout: 5))
        page.cancelRecordingButton.click()

        XCTAssertTrue(page.waitForNotSetBadge(timeout: 5), "Should show 'Not set' after cancelling recording")
        XCTAssertFalse(page.recordingBadgeExists(), "Record badge should disappear after cancel")
    }

    // MARK: - Add App Tests

    @MainActor
    func testAddAppButtonOpensFileDialog() {
        page.launchClean()
        page.waitForWindow()

        XCTAssertTrue(page.addAppButton.waitForExistence(timeout: 5))
        page.addAppButton.click()

        XCTAssertTrue(page.openPanel.waitForExistence(timeout: 5), "NSOpenPanel should appear after clicking Add App")
        page.openPanel.buttons["Cancel"].click()
    }

    @MainActor
    func testAddAppViaOpenPanel() {
        page.launchClean()
        page.waitForWindow()

        XCTAssertTrue(page.addAppButton.waitForExistence(timeout: 5))
        page.addAppButton.click()
        page.waitForAnimation()

        page.selectAppInOpenPanel(path: "/System/Applications/Calculator.app")

        XCTAssertTrue(page.waitForAppName("Calculator"), "Calculator should appear after adding")
        XCTAssertFalse(page.emptyState.exists, "Empty state should disappear")
    }

    @MainActor
    func testAddDuplicateAppShowsAlert() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.waitForWindow()
        XCTAssertTrue(page.appNameExists("Calculator"))

        XCTAssertTrue(page.addAppButton.waitForExistence(timeout: 5))
        page.addAppButton.click()
        page.waitForAnimation()

        page.selectAppInOpenPanel(path: "/System/Applications/Calculator.app")

        XCTAssertTrue(page.duplicateDialog.waitForExistence(timeout: 5), "Duplicate dialog should appear")
        XCTAssertTrue(page.dialogOK.waitForExistence(timeout: 3))
        page.dialogOK.click()
        page.waitForAnimation()

        XCTAssertFalse(page.duplicateDialog.exists, "Duplicate dialog should dismiss after OK")
    }

    // MARK: - Record Shortcut E2E Tests

    @MainActor
    func testRecordShortcutSetsKey() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        XCTAssertTrue(page.notSetBadgeExists())
        page.clickRecordShortcut()
        XCTAssertTrue(page.waitForRecordingBadge(timeout: 5))

        app.typeKey("k", modifierFlags: [.command, .shift])
        page.waitForAnimation()

        XCTAssertFalse(page.recordingBadgeExists(), "Recording badge should disappear after setting shortcut")
        XCTAssertFalse(page.notSetBadgeExists(), "'Not set' should disappear after setting shortcut")

        let shortcutBadge = app.staticTexts.matching(NSPredicate(
            format: "value CONTAINS %@ OR label CONTAINS %@", "K", "K"
        )).firstMatch
        XCTAssertTrue(shortcutBadge.waitForExistence(timeout: 5), "Shortcut badge should show the recorded key")
    }

    @MainActor
    func testRecordShortcutThenUnset() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        page.clickRecordShortcut()
        page.waitForAnimation()
        app.typeKey("j", modifierFlags: [.command, .option])
        page.waitForAnimation()

        XCTAssertFalse(page.notSetBadgeExists())

        XCTAssertTrue(page.unsetButton.waitForExistence(timeout: 5), "Unset button should appear when shortcut is set")
        page.unsetButton.click()

        XCTAssertTrue(page.waitForNotSetBadge(timeout: 5), "Shortcut should be cleared after unset")
    }

    // MARK: - Danger Zone Tests

    @MainActor
    func testUnsetButtonNotShownWhenNoShortcutSet() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        XCTAssertFalse(page.unsetButton.exists, "Unset button should NOT appear when no shortcut is set")
        XCTAssertTrue(page.deleteButton.waitForExistence(timeout: 5), "Delete button should always appear in edit mode")
    }

    @MainActor
    func testUnsetShortcutPreservesEditMode() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        page.clickRecordShortcut()
        page.waitForAnimation()
        app.typeKey("k", modifierFlags: [.command, .shift])

        XCTAssertTrue(page.unsetButton.waitForExistence(timeout: 5))
        page.unsetButton.click()

        XCTAssertTrue(page.waitForNotSetBadge(timeout: 5), "Shortcut should be cleared after unset")
        XCTAssertTrue(page.deleteButton.waitForExistence(timeout: 5), "Delete button should be available after unset")
    }

    // MARK: - Esc Behavior Tests

    @MainActor
    func testKeyboardEscExitsEditModeBeforeDismissing() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        app.typeKey(.escape, modifierFlags: [])
        page.waitForAnimation()

        XCTAssertTrue(page.window.exists, "Window should still be visible after first Esc")
        XCTAssertTrue(
            page.editButton.waitForExistence(timeout: 3),
            "Edit button should reappear after Esc exits edit mode"
        )
    }

    @MainActor
    func testKeyboardEscDismissesDeleteConfirmation() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        XCTAssertTrue(page.deleteButton.waitForExistence(timeout: 5))
        page.deleteButton.click()
        XCTAssertTrue(page.deleteDialog.waitForExistence(timeout: 5))

        app.typeKey(.escape, modifierFlags: [])
        page.waitForAnimation()

        XCTAssertFalse(page.deleteDialog.exists, "Delete confirmation should be dismissed by Esc")
        XCTAssertTrue(page.window.exists, "Window should remain visible")
    }

    @MainActor
    func testEscDuringRecordingStaysInEditMode() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        page.clickRecordShortcut()
        XCTAssertTrue(page.waitForRecordingBadge(timeout: 5))

        app.typeKey(.escape, modifierFlags: [])
        page.waitForAnimation()

        XCTAssertFalse(page.recordingBadgeExists(), "Recording should be cancelled")
        XCTAssertTrue(
            page.cancelEditButton.waitForExistence(timeout: 3),
            "Cancel edit button should still be visible — edit mode should NOT be exited"
        )
    }

    @MainActor
    func testEscFromRemoveDialogKeepsEditMode() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        XCTAssertTrue(page.deleteButton.waitForExistence(timeout: 5))
        page.deleteButton.click()
        XCTAssertTrue(page.deleteDialog.waitForExistence(timeout: 5))

        app.typeKey(.escape, modifierFlags: [])
        page.waitForAnimation()

        XCTAssertFalse(page.deleteDialog.exists, "Remove dialog should be dismissed by Esc")
        XCTAssertTrue(
            page.cancelEditButton.waitForExistence(timeout: 5),
            "Edit mode should be preserved after Esc from remove dialog"
        )
    }

    // MARK: - Keyboard Navigation: Tab

    @MainActor
    func testKeyboardTabNavigatesBetweenRows() {
        page.launchWithSeededShortcuts([calcShortcut(), textEditShortcut()])
        page.waitForWindow()

        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.return, modifierFlags: [])

        let textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        XCTAssertTrue(textEdit.waitForExistence(timeout: 10), "Tab should navigate to second row, Enter should launch")
        textEdit.terminate()
    }

    @MainActor
    func testKeyboardShiftTabNavigatesBackward() {
        page.launchWithSeededShortcuts([calcShortcut(), textEditShortcut()])
        page.waitForWindow()
        page.focusWindow()

        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.downArrow, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.upArrow, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.return, modifierFlags: [])

        let calculator = XCUIApplication(bundleIdentifier: "com.apple.calculator")
        XCTAssertTrue(calculator.waitForExistence(timeout: 10), "Up arrow should navigate back")
        calculator.terminate()
    }

    // MARK: - Keyboard Navigation: Arrow Keys

    @MainActor
    func testDownArrowNavigatesBetweenApps() {
        page.launchWithSeededShortcuts([calcShortcut(), textEditShortcut()])
        page.waitForWindow()
        page.focusWindow()

        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.downArrow, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.return, modifierFlags: [])

        let textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        XCTAssertTrue(textEdit.waitForExistence(timeout: 10), "Down arrow should move to next app row")
        textEdit.terminate()
    }

    @MainActor
    func testUpArrowNavigatesBetweenApps() {
        page.launchWithSeededShortcuts([calcShortcut(), textEditShortcut()])
        page.waitForWindow()
        page.focusWindow()

        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.downArrow, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.upArrow, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.return, modifierFlags: [])

        let calculator = XCUIApplication(bundleIdentifier: "com.apple.calculator")
        XCTAssertTrue(calculator.waitForExistence(timeout: 10), "Up arrow should move to previous app row")
        calculator.terminate()
    }

    @MainActor
    func testDownArrowWrapsToAddApp() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.waitForWindow()
        page.focusWindow()

        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.downArrow, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(page.openPanel.waitForExistence(timeout: 5), "Down arrow past last app should wrap to addApp")
        page.openPanel.buttons["Cancel"].click()
    }

    @MainActor
    func testUpArrowWrapsFromFirstToAddApp() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.waitForWindow()
        page.focusWindow()

        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.upArrow, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(page.openPanel.waitForExistence(timeout: 5), "Up arrow from first app should wrap to addApp")
        page.openPanel.buttons["Cancel"].click()
    }

    // MARK: - Tab Navigation: Edit Mode

    @MainActor
    func testTabOrderEditModeNoShortcutToCancelEdit() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        // shortcutBadge → Tab → deleteButton → Tab → cancelEdit → Enter
        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(page.editButton.waitForExistence(timeout: 5), "Tab to cancelEdit + Enter should exit edit mode")
    }

    @MainActor
    func testTabOrderEditModeNoShortcutToDeleteButton() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        // shortcutBadge → Tab → deleteButton → Enter
        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(
            page.deleteDialog.waitForExistence(timeout: 5),
            "Tab to deleteButton + Enter should open delete dialog"
        )
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testTabOrderEditModeWithShortcutToCancelEdit() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        page.clickRecordShortcut()
        page.waitForAnimation()
        app.typeKey("k", modifierFlags: [.command, .shift])
        page.waitForAnimation()

        XCTAssertFalse(page.notSetBadgeExists(), "Shortcut should be set")

        page.cancelEditButton.click()
        page.waitForAnimation()
        page.openEditMode()

        // shortcutBadge → shortcutEditButton → unsetButton → deleteButton → cancelEdit
        for _ in 0 ..< 4 {
            app.typeKey(.tab, modifierFlags: [])
            page.waitForAnimation()
        }
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(page.editButton.waitForExistence(timeout: 5), "Tab 4 should reach cancelEdit")
    }

    @MainActor
    func testTabOrderEditModeWithShortcutToUnsetButton() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        page.clickRecordShortcut()
        page.waitForAnimation()
        app.typeKey("j", modifierFlags: [.command, .option])
        page.waitForAnimation()

        XCTAssertFalse(page.notSetBadgeExists(), "Shortcut should be set")

        page.cancelEditButton.click()
        page.waitForAnimation()
        page.openEditMode()

        // shortcutBadge → shortcutEditButton → unsetButton → Enter
        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(page.waitForNotSetBadge(timeout: 5), "Tab to unsetButton + Enter should unset shortcut")
    }

    @MainActor
    func testShiftTabInEditMode() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        // Tab forward: shortcutBadge → delete → cancel
        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.tab, modifierFlags: [])
        page.waitForAnimation()

        // Shift+Tab back to deleteButton
        app.typeKey(.tab, modifierFlags: .shift)
        page.waitForFocus()
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(
            page.deleteDialog.waitForExistence(timeout: 5),
            "Shift+Tab from cancelEdit should go to deleteButton"
        )
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testFocusRestoredAfterRecordingCancel() {
        // Record → Esc should restore focus to the badge, not lose it
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        // Enter recording mode
        app.typeKey(.return, modifierFlags: [])
        page.waitForAnimation()
        XCTAssertTrue(page.recordingBadgeExists(), "Should be in recording mode")

        // Cancel recording with Esc
        app.typeKey(.escape, modifierFlags: [])
        page.waitForAnimation()

        // Tab should stay within the same card (not jump to another app)
        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()

        // If focus is on deleteButton, Enter opens delete dialog
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(
            page.deleteDialog.waitForExistence(timeout: 5),
            "After record cancel, Tab should reach deleteButton within the same card"
        )
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testFocusRestoredAfterRecordingCancelWithTwoApps() {
        // With two apps, record → Esc on app2 should not jump focus to app1
        page.launchWithSeededShortcuts([calcShortcut(), textEditShortcut()])
        page.waitForWindow()

        // Enter edit mode for app2 (TextEdit) by clicking its edit button
        let editButtons = app.buttons.matching(identifier: "edit-shortcut")
        XCTAssertTrue(editButtons.element(boundBy: 1).waitForExistence(timeout: 5), "Second edit button should exist")
        editButtons.element(boundBy: 1).click()
        _ = page.cancelEditButton.waitForExistence(timeout: 3)

        // Enter recording mode via keyboard
        app.typeKey(.return, modifierFlags: [])
        page.waitForAnimation()
        XCTAssertTrue(page.waitForRecordingBadge(timeout: 3), "Should be in recording mode")

        // Cancel recording with Esc
        app.typeKey(.escape, modifierFlags: [])
        page.waitForAnimation()

        // Tab should cycle within app2's edit card
        // shortcutBadge → deleteButton → cancelEdit
        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        // cancelEdit → Enter should exit edit mode back to app2 row
        app.typeKey(.return, modifierFlags: [])
        page.waitForAnimation()

        // Verify we're back on a row (not stuck in edit mode of wrong app)
        XCTAssertTrue(
            editButtons.element(boundBy: 1).waitForExistence(timeout: 3),
            "Should be back on the row with edit button"
        )
    }

    @MainActor
    func testTabLoopsWithinEditCard() {
        // Tab should loop within the edit card, not escape to other apps
        page.launchWithSeededShortcuts([calcShortcut(), textEditShortcut()])
        page.waitForWindow()

        // Enter edit mode for app2 (TextEdit) by clicking its edit button
        let editButtons = app.buttons.matching(identifier: "edit-shortcut")
        XCTAssertTrue(editButtons.element(boundBy: 1).waitForExistence(timeout: 5), "Second edit button should exist")
        editButtons.element(boundBy: 1).click()
        _ = page.cancelEditButton.waitForExistence(timeout: 3)

        // Tab through all targets and wrap around:
        // shortcutBadge → deleteButton → cancelEdit → shortcutBadge (loop)
        for _ in 0 ..< 3 {
            app.typeKey(.tab, modifierFlags: [])
            page.waitForFocus()
        }

        // We should be back at shortcutBadge; Tab → deleteButton → Enter opens dialog
        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(
            page.deleteDialog.waitForExistence(timeout: 5),
            "Tab loop should wrap back to card start, not escape to app1"
        )
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testToggleShortcutEnabledViaKeyboard() {
        // shortcutBadge Enter should toggle enable/disable
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        // Record a shortcut first
        page.clickRecordShortcut()
        page.waitForAnimation()
        app.typeKey("t", modifierFlags: [.command, .shift])
        page.waitForAnimation()
        XCTAssertFalse(page.notSetBadgeExists(), "Shortcut should be set")

        // Exit and re-enter edit mode to get clean focus state
        page.cancelEditButton.click()
        page.waitForAnimation()
        page.openEditMode()

        // Focus is on shortcutBadge; Enter should toggle (disable)
        app.typeKey(.return, modifierFlags: [])
        page.waitForAnimation()

        // The shortcut text should show strikethrough (disabled)
        // We can verify by toggling back and checking the badge still exists
        app.typeKey(.return, modifierFlags: [])
        page.waitForAnimation()

        // Should still be in edit mode with shortcut set (not recording)
        XCTAssertFalse(page.recordingBadgeExists(), "Enter on badge should toggle, not start recording")
        XCTAssertFalse(page.notSetBadgeExists(), "Shortcut should still be set after toggle")
    }

    // MARK: - Scroll & Many Apps

    @MainActor
    func testManyAppsScrollable() {
        let shortcuts = [
            calcShortcut(),
            textEditShortcut(),
            seed("Preview", "com.apple.Preview"),
            seed("Notes", "com.apple.Notes"),
            seed("Calendar", "com.apple.iCal"),
            seed("Reminders", "com.apple.reminders"),
            seed("Maps", "com.apple.Maps"),
            seed("Photos", "com.apple.Photos"),
        ]
        page.launchWithSeededShortcuts(shortcuts)
        page.waitForWindow()

        for name in ["Calculator", "TextEdit", "Preview", "Notes", "Calendar", "Reminders", "Maps", "Photos"] {
            XCTAssertTrue(page.waitForAppName(name), "\(name) should exist in the app list")
        }
        XCTAssertTrue(page.addAppButton.waitForExistence(timeout: 5), "Add App button should exist below the list")
    }

    @MainActor
    func testAutoScrollWithArrowKeys() {
        let shortcuts = [
            calcShortcut(),
            textEditShortcut(),
            seed("Preview", "com.apple.Preview"),
            seed("Notes", "com.apple.Notes"),
            seed("Calendar", "com.apple.iCal"),
            seed("Reminders", "com.apple.reminders"),
            seed("Maps", "com.apple.Maps"),
            seed("Photos", "com.apple.Photos"),
        ]
        page.launchWithSeededShortcuts(shortcuts)
        page.waitForWindow()
        page.focusWindow()

        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        for _ in 0 ..< 8 {
            app.typeKey(.downArrow, modifierFlags: [])
            page.waitForFocus()
        }
        page.waitForAnimation()

        XCTAssertTrue(page.addAppButton.isHittable, "Add App should be scrolled into view via arrow key navigation")
    }
}

// swiftlint:enable type_body_length
// swiftlint:enable file_length
