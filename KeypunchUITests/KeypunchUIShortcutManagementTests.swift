import XCTest

final class KeypunchUIShortcutManagementTests: KeypunchUITestCase {
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
        app.typeKey(.return, modifierFlags: [])
        page.waitForAnimation()

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
        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.return, modifierFlags: [])
        page.waitForAnimation()

        XCTAssertTrue(
            page.emptyState.waitForExistence(timeout: 5),
            "Should show empty state after removing the only shortcut"
        )
    }

    @MainActor
    func testDeleteConfirmationRepeatedTabKeepsDialogOpen() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        XCTAssertTrue(page.deleteButton.waitForExistence(timeout: 5))
        page.deleteButton.click()
        XCTAssertTrue(page.deleteDialog.waitForExistence(timeout: 5))

        let calculator = XCUIApplication(bundleIdentifier: "com.apple.calculator")
        _ = calculator.terminate()
        page.waitForAnimation()

        for _ in 0 ..< 10 {
            app.typeKey(.tab, modifierFlags: [])
            page.waitForFocus()

            XCTAssertEqual(
                calculator.state,
                .notRunning,
                "Pressing tab inside delete confirmation should not launch Calculator"
            )
            XCTAssertTrue(page.deleteDialog.exists, "Delete confirmation should stay open while navigating with tab")
        }

        app.typeKey(.return, modifierFlags: [])
        page.waitForAnimation()
        XCTAssertFalse(page.deleteDialog.exists)
    }

    @MainActor
    func testDeleteConfirmationRepeatedShiftTabKeepsDialogOpen() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        XCTAssertTrue(page.deleteButton.waitForExistence(timeout: 5))
        page.deleteButton.click()
        XCTAssertTrue(page.deleteDialog.waitForExistence(timeout: 5))

        let calculator = XCUIApplication(bundleIdentifier: "com.apple.calculator")
        _ = calculator.terminate()
        page.waitForAnimation()

        for _ in 0 ..< 10 {
            app.typeKey(.tab, modifierFlags: [.shift])
            page.waitForFocus()

            XCTAssertEqual(
                calculator.state,
                .notRunning,
                "Pressing Shift+Tab inside delete confirmation should not launch Calculator"
            )
            XCTAssertTrue(page.deleteDialog.exists, "Delete confirmation should stay open while navigating with Shift+Tab")
        }

        app.typeKey(.escape, modifierFlags: [])
        page.waitForAnimation()
        XCTAssertFalse(page.deleteDialog.exists, "Escape should dismiss delete confirmation")
    }

    @MainActor
    func testDeleteConfirmationShiftTabReturnsToCancel() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        XCTAssertTrue(page.deleteButton.waitForExistence(timeout: 5))
        page.deleteButton.click()
        XCTAssertTrue(page.dialogCancel.waitForExistence(timeout: 5))

        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.tab, modifierFlags: [.shift])
        page.waitForFocus()
        app.typeKey(.return, modifierFlags: [])
        page.waitForAnimation()

        XCTAssertFalse(page.deleteDialog.exists, "Shift+Tab should return focus to cancel")
        XCTAssertTrue(page.waitForAppName("Calculator"), "Calculator should remain after cancelling remove")
        XCTAssertTrue(page.cancelEditButton.waitForExistence(timeout: 5), "Edit mode should remain after cancelling")
    }

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

    @MainActor
    func testDisabledShortcutDoesNotLaunchApp() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        XCTAssertTrue(page.notSetBadgeExists(), "Shortcut should start unset for the seeded app")
        page.clickRecordShortcut()
        XCTAssertTrue(page.waitForRecordingBadge(timeout: 5), "Record badge should appear before capturing a shortcut")

        app.typeKey("t", modifierFlags: [.command, .shift])
        page.waitForAnimation()

        XCTAssertTrue(page.waitForShortcutBadge(timeout: 5), "Shortcut badge should appear after recording a shortcut")
        page.cancelEditButton.click()
        page.waitForAnimation()

        let calculator = XCUIApplication(bundleIdentifier: "com.apple.calculator")
        calculator.terminate()
        XCTAssertTrue(waitForAppToStop(calculator), "Calculator should be stopped before testing the shortcut")

        app.typeKey("t", modifierFlags: [.command, .shift])
        XCTAssertTrue(waitForAppToLaunch(calculator), "Enabled shortcut should launch Calculator")

        calculator.terminate()
        XCTAssertTrue(waitForAppToStop(calculator), "Calculator should stop before testing the disabled state")

        app.activate()
        page.focusWindow()
        page.openEditMode()

        XCTAssertTrue(page.shortcutBadgeButton.waitForExistence(timeout: 5), "Shortcut badge should exist in edit mode")
        page.shortcutBadgeButton.click()
        page.waitForAnimation()

        XCTAssertTrue(
            page.waitForShortcutBadgeLabelContaining("disabled"),
            "Shortcut badge should reflect the disabled state after toggling"
        )

        page.cancelEditButton.click()
        page.waitForAnimation()

        app.typeKey("t", modifierFlags: [.command, .shift])
        page.waitForAnimation()

        XCTAssertEqual(calculator.state, .notRunning, "Disabled shortcut should not launch Calculator")
    }

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
    func testAddedAppReceivesFocus() {
        page.launchClean()
        page.waitForWindow()

        XCTAssertTrue(page.addAppButton.waitForExistence(timeout: 5))
        page.addAppButton.click()
        page.waitForAnimation()

        page.selectAppInOpenPanel(path: "/System/Applications/Calculator.app")

        XCTAssertTrue(page.waitForAppName("Calculator"), "Calculator should appear after adding")

        page.waitForFocus()
        app.typeKey(.rightArrow, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(
            page.cancelEditButton.waitForExistence(timeout: 3),
            "Newly added app should receive focus so keyboard navigation continues from that row"
        )
    }

    @MainActor
    func testAddedAppIsActionableInLongList() {
        let shortcuts = (1 ... 20).map { index in
            KeypunchPage.makeSeedShortcut(
                name: "Seed \(index)",
                bundleID: "com.example.seed\(index)",
                appPath: "/Applications/Seed \(index).app"
            )
        }

        page.launchWithSeededShortcuts(shortcuts)
        page.waitForWindow()

        app.typeKey(.upArrow, modifierFlags: [])
        page.waitForFocus()
        XCTAssertTrue(page.addAppButton.isHittable, "Add App should be scrolled into view before opening the picker")

        app.typeKey(.return, modifierFlags: [])
        page.selectAppInOpenPanel(path: "/System/Applications/Calculator.app")

        XCTAssertTrue(page.waitForAppName("Calculator"), "Calculator should appear after adding")

        let calculatorRow = app.buttons.matching(NSPredicate(
            format: "label CONTAINS %@ AND label CONTAINS %@",
            "Calculator",
            "/System/Applications"
        )).firstMatch
        XCTAssertTrue(calculatorRow.waitForExistence(timeout: 5), "Calculator row should be visible after auto-scroll")

        page.waitForAnimation()

        XCTAssertTrue(calculatorRow.isHittable, "Newly added app row should be visible after auto-scroll")
        app.typeKey(.rightArrow, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(
            page.cancelEditButton.waitForExistence(timeout: 3),
            "Newly added app should be immediately actionable even in a long list"
        )
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
        app.typeKey(.return, modifierFlags: [])
        page.waitForAnimation()

        XCTAssertFalse(page.duplicateDialog.exists, "Duplicate dialog should dismiss after OK")
    }

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
}
