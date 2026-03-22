import Foundation
@testable import Keypunch
import Testing

struct SparkleUpdaterTests {
    private func makeTestDefaults() -> UserDefaults {
        let suiteName = "com.mkusaka.KeypunchTests.sparkle.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @MainActor
    @Test func updaterNotStartedBeforeSetup() {
        let store = ShortcutStore(defaults: makeTestDefaults())
        let coordinator = SettingsWindowCoordinator()
        let controller = FloatingWidgetController(
            store: store,
            settingsWindowCoordinator: coordinator
        )

        #expect(
            controller.updaterController.updater.canCheckForUpdates == false,
            "Updater should not be started until setup() is called"
        )
    }

    @MainActor
    @Test func statusBarMenuContainsCheckForUpdatesItem() {
        let store = ShortcutStore(defaults: makeTestDefaults())
        let coordinator = SettingsWindowCoordinator()
        let controller = FloatingWidgetController(
            store: store,
            settingsWindowCoordinator: coordinator
        )
        controller.setup()

        let menu = controller.statusItem?.menu
        let titles = menu?.items.map(\.title) ?? []
        #expect(titles.contains("Check for Updates…"))
    }

    @Test func infoPlistContainsFeedURL() {
        let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        #expect(feedURL == "https://mkusaka.github.io/keypunch/appcast.xml")
    }

    @Test func infoPlistContainsPublicEDKey() {
        let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        #expect(publicKey != nil && !publicKey!.isEmpty, "SUPublicEDKey should be present and non-empty")
    }
}
