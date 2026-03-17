import XCTest

class KeypunchUITestCase: XCTestCase {
    var app: XCUIApplication!
    var page: KeypunchPage!

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

    func calcShortcut() -> [String: Any] {
        KeypunchPage.makeSeedShortcut(
            name: "Calculator",
            bundleID: "com.apple.calculator",
            appPath: "/System/Applications/Calculator.app"
        )
    }

    func textEditShortcut() -> [String: Any] {
        KeypunchPage.makeSeedShortcut(
            name: "TextEdit",
            bundleID: "com.apple.TextEdit",
            appPath: "/System/Applications/TextEdit.app"
        )
    }

    func seed(_ name: String, _ bundleID: String) -> [String: Any] {
        KeypunchPage.makeSeedShortcut(
            name: name,
            bundleID: bundleID,
            appPath: "/System/Applications/\(name).app"
        )
    }
}
