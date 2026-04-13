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

    private func sparkleBuildVersion(for marketingVersion: String) throws -> Int {
        let parts = marketingVersion.split(separator: ".")
        guard parts.count == 3 else {
            struct VersionFormatError: Error {}
            throw VersionFormatError()
        }
        let major = try #require(Int(parts[0]))
        let minor = try #require(Int(parts[1]))
        let patch = try #require(Int(parts[2]))
        return major * 10000 + minor * 100 + patch
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

    @Test func infoPlistKeepsDisplayVersionAlignedWithBuildInfo() {
        let marketingVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        #expect(marketingVersion != nil)
        #expect(BuildInfo.version == marketingVersion)
    }

    @Test func infoPlistContainsPublicEDKey() {
        let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        #expect(publicKey != nil && !publicKey!.isEmpty, "SUPublicEDKey should be present and non-empty")
    }

    @Test func sparkleBuildVersionUsesMajorMinorPatchFormula() throws {
        #expect(try sparkleBuildVersion(for: "0.0.1") == 1)
        #expect(try sparkleBuildVersion(for: "0.0.9") == 9)
        #expect(try sparkleBuildVersion(for: "0.1.0") == 100)
        #expect(try sparkleBuildVersion(for: "1.2.3") == 10203)
    }
}
