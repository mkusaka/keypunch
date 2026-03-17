import XCTest

final class KeypunchUIKeyboardNavigationTests: KeypunchUITestCase {
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
}
