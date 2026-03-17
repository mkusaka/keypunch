import XCTest

final class KeypunchUIEditFlowTests: KeypunchUITestCase {
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
        XCTAssertEqual(cancelButtons.count, 1, "Only one row should be in edit mode")
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
}
