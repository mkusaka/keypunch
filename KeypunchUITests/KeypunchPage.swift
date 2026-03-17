import XCTest

/// Page Object for Keypunch UI tests.
/// Encapsulates element queries and common interactions.
final class KeypunchPage {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Launch Helpers

    func launchClean() {
        app.launchArguments = ["-resetForTesting"]
        app.launch()
    }

    func launchWithSeededShortcuts(_ shortcuts: [[String: Any]]) {
        let data = try! JSONSerialization.data(withJSONObject: shortcuts)
        let json = String(data: data, encoding: .utf8)!
        app.launchArguments = ["-resetForTesting"]
        app.launchEnvironment["SEED_SHORTCUTS"] = json
        app.launch()
    }

    func launchWithSeededShortcutsNoTestMode(_ shortcuts: [[String: Any]]) {
        let data = try! JSONSerialization.data(withJSONObject: shortcuts)
        let json = String(data: data, encoding: .utf8)!
        app.launchArguments = ["-seedOnly"]
        app.launchEnvironment["SEED_SHORTCUTS"] = json
        app.launch()
    }

    static func makeSeedShortcut(name: String, bundleID: String?, appPath: String) -> [String: Any] {
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

    // MARK: - Element Queries

    var window: XCUIElement {
        app.windows["keypunch-panel"]
    }

    var addAppButton: XCUIElement {
        app.buttons["add-app-button"]
    }

    var editButton: XCUIElement {
        app.buttons["edit-shortcut"]
    }

    var cancelEditButton: XCUIElement {
        app.buttons["cancel-edit"]
    }

    var deleteButton: XCUIElement {
        app.buttons["delete-app"]
    }

    var unsetButton: XCUIElement {
        app.buttons["unset-shortcut"]
    }

    var recordButton: XCUIElement {
        app.buttons["record-shortcut"]
    }

    var notSetBadgeButton: XCUIElement {
        app.buttons["not-set-badge"].firstMatch
    }

    var cancelRecordingButton: XCUIElement {
        app.buttons["Cancel recording"]
    }

    var dialogCancel: XCUIElement {
        app.buttons["dialog-cancel"]
    }

    var dialogRemove: XCUIElement {
        app.buttons["dialog-remove"]
    }

    var dialogOK: XCUIElement {
        app.buttons["dialog-ok"]
    }

    var deleteDialog: XCUIElement {
        app.groups["delete-confirmation-dialog"]
    }

    var duplicateDialog: XCUIElement {
        app.groups["duplicate-alert-dialog"]
    }

    var emptyState: XCUIElement {
        app.staticTexts["empty-state"]
    }

    var openPanel: XCUIElement {
        app.dialogs.firstMatch
    }

    // MARK: - Existence Checks

    func appNameExists(_ name: String) -> Bool {
        if app.staticTexts[name].exists { return true }
        let predicate = NSPredicate(format: "label CONTAINS %@", name)
        return app.buttons.matching(predicate).firstMatch.exists
    }

    func waitForAppName(_ name: String, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if appNameExists(name) { return true }
            usleep(200_000)
        }
        return appNameExists(name)
    }

    func notSetBadgeExists() -> Bool {
        app.buttons["not-set-badge"].exists
            || app.staticTexts["not-set-badge"].exists
            || app.otherElements["not-set-badge"].exists
    }

    func waitForNotSetBadge(timeout: TimeInterval = 5) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if notSetBadgeExists() { return true }
            usleep(200_000)
        }
        return notSetBadgeExists()
    }

    func recordingBadgeExists() -> Bool {
        app.groups["recording-badge"].exists
            || app.otherElements["recording-badge"].exists
            || app.staticTexts["recording-badge"].exists
    }

    func waitForRecordingBadge(timeout: TimeInterval = 5) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if recordingBadgeExists() { return true }
            usleep(200_000)
        }
        return recordingBadgeExists()
    }

    // MARK: - Actions

    func waitForWindow() {
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Settings window should appear")
    }

    func clickRecordShortcut() {
        let btn = app.buttons["record-shortcut"]
        if btn.waitForExistence(timeout: 3) {
            btn.click()
            return
        }
        let notSetBtn = app.buttons["not-set-badge"].firstMatch
        if notSetBtn.waitForExistence(timeout: 2) {
            notSetBtn.click()
            return
        }
        let img = app.images["record-shortcut"]
        if img.waitForExistence(timeout: 2) {
            img.click()
            return
        }
        let notSet = app.otherElements["not-set-badge"]
        if notSet.waitForExistence(timeout: 1) {
            notSet.click()
            return
        }
        XCTFail("Could not find record-shortcut element")
    }

    func openEditMode() {
        waitForWindow()
        XCTAssertTrue(editButton.waitForExistence(timeout: 3), "Edit button should exist on a shortcut row")
        editButton.click()
        _ = cancelEditButton.waitForExistence(timeout: 3)
    }

    func focusWindow() {
        if window.exists, window.isHittable {
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02)).click()
            usleep(300_000)
        }
    }

    func selectAppInOpenPanel(path: String) {
        XCTAssertTrue(openPanel.waitForExistence(timeout: 5), "NSOpenPanel should appear")

        openPanel.typeKey("g", modifierFlags: [.command, .shift])

        let goToSheet = openPanel.sheets.firstMatch
        guard goToSheet.waitForExistence(timeout: 3) else {
            XCTFail("Go to Folder sheet did not appear")
            return
        }

        let pathField = goToSheet.comboBoxes.firstMatch.exists
            ? goToSheet.comboBoxes.firstMatch
            : goToSheet.textFields.firstMatch
        guard pathField.waitForExistence(timeout: 3) else {
            XCTFail("Path field not found in Go to Folder sheet")
            return
        }

        pathField.click()
        pathField.typeKey("a", modifierFlags: .command)
        pathField.typeText(path)
        usleep(500_000)

        pathField.typeKey(.return, modifierFlags: [])
        usleep(800_000)

        if openPanel.exists {
            openPanel.typeKey(.return, modifierFlags: [])
            usleep(800_000)
        }
    }

    /// Wait briefly for UI animations to settle.
    func waitForAnimation() {
        usleep(500_000)
    }

    /// Wait briefly for focus changes to propagate.
    func waitForFocus() {
        usleep(300_000)
    }
}
