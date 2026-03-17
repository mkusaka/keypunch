import AppKit
import SwiftUI

@MainActor
final class KeypunchRuntime {
    static let shared = KeypunchRuntime()

    let store: ShortcutStore
    let settingsWindowCoordinator: SettingsWindowCoordinator
    let widgetController: FloatingWidgetController

    private init() {
        let isResetForTesting = CommandLine.arguments.contains("-resetForTesting")
        let isSeedOnly = CommandLine.arguments.contains("-seedOnly")

        if isResetForTesting || isSeedOnly {
            UserDefaults.standard.removeObject(forKey: ShortcutStore.storageKey)
        }
        if let seedJSON = ProcessInfo.processInfo.environment["SEED_SHORTCUTS"],
           let data = seedJSON.data(using: .utf8)
        {
            UserDefaults.standard.set(data, forKey: ShortcutStore.storageKey)
        }

        let store = ShortcutStore()
        let settingsWindowCoordinator = SettingsWindowCoordinator()

        self.store = store
        self.settingsWindowCoordinator = settingsWindowCoordinator
        widgetController = FloatingWidgetController(
            store: store,
            settingsWindowCoordinator: settingsWindowCoordinator
        )
    }

    func setup() {
        widgetController.setup()
    }

    func showSettingsWindow() {
        settingsWindowCoordinator.showSettingsWindow()
    }
}

@MainActor
final class SettingsWindowCoordinator {
    static let sceneID = "settings-window"
    static let accessibilityID = "keypunch-panel"

    private var openWindowHandler: (() -> Void)?

    func registerOpenWindowHandler(_ handler: @escaping () -> Void) {
        openWindowHandler = handler
    }

    func configure(_ window: NSWindow) {
        window.title = "Keypunch"
        window.identifier = NSUserInterfaceItemIdentifier(Self.accessibilityID)
        window.setAccessibilityIdentifier(Self.accessibilityID)
    }

    func showSettingsWindow() {
        openWindowHandler?()
        DispatchQueue.main.async {
            if let window = self.settingsWindow {
                window.makeKeyAndOrderFront(nil)
            }
            NSApp.activate()
            NSRunningApplication.current.activate(options: [.activateAllWindows])
        }
    }

    private var settingsWindow: NSWindow? {
        NSApp.windows.first { $0.identifier?.rawValue == Self.accessibilityID }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let runtime = KeypunchRuntime.shared

    func applicationDidFinishLaunching(_: Notification) {
        guard NSClassFromString("XCTestCase") == nil else { return }
        runtime.setup()
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            runtime.showSettingsWindow()
        }
        return true
    }
}

struct SettingsWindowSceneView: View {
    let store: ShortcutStore
    let coordinator: SettingsWindowCoordinator

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        SettingsPanelView(store: store)
            .frame(minWidth: 380, idealWidth: 380, maxWidth: 380, minHeight: 616, idealHeight: 616, maxHeight: 616)
            .background(
                WindowAccessor { window in
                    coordinator.configure(window)
                }
                .frame(width: 0, height: 0)
            )
            .onAppear {
                coordinator.registerOpenWindowHandler {
                    openWindow(id: SettingsWindowCoordinator.sceneID)
                }
            }
    }
}

struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context _: Context) -> NSView {
        let view = NSView(frame: .zero)
        resolveWindow(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        resolveWindow(for: nsView)
    }

    private func resolveWindow(for view: NSView) {
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            onResolve(window)
        }
    }
}

@main
@MainActor
struct KeypunchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let runtime = KeypunchRuntime.shared

    var body: some Scene {
        Window("Keypunch", id: SettingsWindowCoordinator.sceneID) {
            SettingsWindowSceneView(
                store: runtime.store,
                coordinator: runtime.settingsWindowCoordinator
            )
        }
        .defaultSize(width: 380, height: 616)
        .windowResizability(.contentSize)
    }
}
