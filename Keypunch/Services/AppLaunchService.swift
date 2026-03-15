import AppKit

@MainActor
final class AppLaunchService {
    private let workspace: AppLaunching
    private let mainBundle: BundleProviding

    var onSelfActivate: (() -> Void)?

    init(
        workspace: AppLaunching = NSWorkspace.shared,
        mainBundle: BundleProviding = Bundle.main
    ) {
        self.workspace = workspace
        self.mainBundle = mainBundle
    }

    func launch(for shortcut: AppShortcut) {
        if let bundleID = shortcut.bundleIdentifier,
           bundleID == mainBundle.bundleIdentifier
        {
            onSelfActivate?()
            return
        }

        let url: URL = if let bundleID = shortcut.bundleIdentifier,
                          let resolved = workspace.urlForApplication(withBundleIdentifier: bundleID)
        {
            resolved
        } else {
            shortcut.appURL
        }

        let configuration = NSWorkspace.OpenConfiguration()
        Task {
            do {
                try await workspace.openApplication(at: url, configuration: configuration)
            } catch {
                print("Failed to launch \(shortcut.name): \(error)")
            }
        }
    }
}
