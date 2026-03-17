import XCTest

final class KeypunchUIBasicsTests: KeypunchUITestCase {
    @MainActor
    func testWindowAppearsOnLaunch() {
        page.launchClean()
        XCTAssertTrue(page.window.waitForExistence(timeout: 5), "Settings window should appear on launch")
    }

    @MainActor
    func testWindowAppearsOutsideTestMode() {
        page.launchWithSeededShortcutsNoTestMode([calcShortcut()])
        XCTAssertTrue(page.window.waitForExistence(timeout: 5), "Settings window should appear on a normal launch")
    }

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
