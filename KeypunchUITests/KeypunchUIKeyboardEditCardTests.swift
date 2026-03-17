import XCTest

final class KeypunchUIKeyboardEditCardTests: KeypunchUITestCase {
    @MainActor
    func testTabOrderEditModeNoShortcutToCancelEdit() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

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

        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.tab, modifierFlags: [])
        page.waitForAnimation()

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
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        app.typeKey(.return, modifierFlags: [])
        page.waitForAnimation()
        XCTAssertTrue(page.recordingBadgeExists(), "Should be in recording mode")

        app.typeKey(.escape, modifierFlags: [])
        page.waitForAnimation()

        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()

        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(
            page.deleteDialog.waitForExistence(timeout: 5),
            "After record cancel, Tab should reach deleteButton within the same card"
        )
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testFocusRestoredAfterRecordingCancelWithTwoApps() {
        page.launchWithSeededShortcuts([calcShortcut(), textEditShortcut()])
        page.waitForWindow()

        let editButtons = app.buttons.matching(identifier: "edit-shortcut")
        XCTAssertTrue(editButtons.element(boundBy: 1).waitForExistence(timeout: 5), "Second edit button should exist")
        editButtons.element(boundBy: 1).click()
        _ = page.cancelEditButton.waitForExistence(timeout: 3)

        app.typeKey(.return, modifierFlags: [])
        page.waitForAnimation()
        XCTAssertTrue(page.waitForRecordingBadge(timeout: 3), "Should be in recording mode")

        app.typeKey(.escape, modifierFlags: [])
        page.waitForAnimation()

        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()
        app.typeKey(.return, modifierFlags: [])
        page.waitForAnimation()

        XCTAssertTrue(
            editButtons.element(boundBy: 1).waitForExistence(timeout: 3),
            "Should be back on the row with edit button"
        )
    }

    @MainActor
    func testTabLoopsWithinEditCard() {
        page.launchWithSeededShortcuts([calcShortcut(), textEditShortcut()])
        page.waitForWindow()

        let editButtons = app.buttons.matching(identifier: "edit-shortcut")
        XCTAssertTrue(editButtons.element(boundBy: 1).waitForExistence(timeout: 5), "Second edit button should exist")
        editButtons.element(boundBy: 1).click()
        _ = page.cancelEditButton.waitForExistence(timeout: 3)

        for _ in 0 ..< 3 {
            app.typeKey(.tab, modifierFlags: [])
            page.waitForFocus()
        }

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
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        page.clickRecordShortcut()
        page.waitForAnimation()
        app.typeKey("t", modifierFlags: [.command, .shift])
        page.waitForAnimation()
        XCTAssertFalse(page.notSetBadgeExists(), "Shortcut should be set")

        page.cancelEditButton.click()
        page.waitForAnimation()
        page.openEditMode()

        app.typeKey(.return, modifierFlags: [])
        page.waitForAnimation()

        app.typeKey(.return, modifierFlags: [])
        page.waitForAnimation()

        XCTAssertFalse(page.recordingBadgeExists(), "Enter on badge should toggle, not start recording")
        XCTAssertFalse(page.notSetBadgeExists(), "Shortcut should still be set after toggle")
    }

    @MainActor
    func testShiftTabLoopsWithinEditCardWithTwoApps() {
        page.launchWithSeededShortcuts([calcShortcut(), textEditShortcut()])
        page.waitForWindow()

        let editButtons = app.buttons.matching(identifier: "edit-shortcut")
        XCTAssertTrue(editButtons.element(boundBy: 1).waitForExistence(timeout: 5), "Second edit button should exist")
        editButtons.element(boundBy: 1).click()
        _ = page.cancelEditButton.waitForExistence(timeout: 3)

        app.typeKey(.tab, modifierFlags: .shift)
        page.waitForFocus()

        app.typeKey(.return, modifierFlags: [])
        page.waitForAnimation()

        XCTAssertTrue(
            editButtons.element(boundBy: 1).waitForExistence(timeout: 3),
            "Shift+Tab should wrap to cancelEdit within the card, not escape to app1"
        )
    }

    @MainActor
    func testEditButtonIsStandaloneWithShortcutSet() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        page.clickRecordShortcut()
        page.waitForAnimation()
        app.typeKey("t", modifierFlags: [.command, .shift])
        page.waitForAnimation()
        XCTAssertFalse(page.notSetBadgeExists(), "Shortcut should be set")

        page.cancelEditButton.click()
        page.waitForAnimation()
        page.openEditMode()

        app.typeKey(.tab, modifierFlags: [])
        page.waitForFocus()

        app.typeKey(.return, modifierFlags: [])
        page.waitForAnimation()
        XCTAssertTrue(
            page.waitForRecordingBadge(timeout: 3),
            "Enter on standalone edit button should start recording"
        )
    }

    @MainActor
    func testTabOrderWithShortcutSet() {
        page.launchWithSeededShortcuts([calcShortcut()])
        page.openEditMode()

        page.clickRecordShortcut()
        page.waitForAnimation()
        app.typeKey("t", modifierFlags: [.command, .shift])
        page.waitForAnimation()

        page.cancelEditButton.click()
        page.waitForAnimation()
        page.openEditMode()

        for _ in 0 ..< 5 {
            app.typeKey(.tab, modifierFlags: [])
            page.waitForFocus()
        }

        app.typeKey(.return, modifierFlags: [])
        page.waitForAnimation()
        XCTAssertFalse(page.recordingBadgeExists(), "After full Tab loop, Enter on badge should toggle, not record")
        XCTAssertFalse(page.notSetBadgeExists(), "Shortcut should still be set")
    }
}
