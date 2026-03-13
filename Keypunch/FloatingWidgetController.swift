import AppKit
import SwiftUI
import KeyboardShortcuts

@MainActor
final class FloatingWidgetController: NSObject {
    private var triggerPanel: NSPanel!
    private var expandedPanel: NSPanel!
    private let store: ShortcutStore
    private let isTestMode: Bool
    private var isExpanded = false
    private var hideTimer: Timer?
    private var triggerHostingView: NSHostingView<FloatingTriggerView>!

    init(store: ShortcutStore, isTestMode: Bool) {
        self.store = store
        self.isTestMode = isTestMode
        super.init()
    }

    func setup() {
        setupTriggerPanel()
        setupExpandedPanel()
        positionPanels()
        triggerPanel.orderFront(nil)

        KeyboardShortcuts.onKeyUp(for: .toggleKeypunch) { [weak self] in
            Task { @MainActor in
                self?.toggleExpandedPanel()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    // MARK: - Panel Setup

    private func setupTriggerPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 48, height: 160),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isOpaque = false
        panel.setAccessibilityIdentifier("keypunch-trigger")

        let hostingView = NSHostingView(rootView: FloatingTriggerView(store: store, isActive: false) { [weak self] in
            self?.showExpandedPanel()
        })
        panel.contentView = hostingView
        triggerHostingView = hostingView

        let rightClickGesture = NSClickGestureRecognizer(target: self, action: #selector(triggerRightClicked(_:)))
        rightClickGesture.buttonMask = 0x2
        hostingView.addGestureRecognizer(rightClickGesture)

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: ["panel": "trigger"]
        )
        hostingView.addTrackingArea(trackingArea)

        self.triggerPanel = panel
    }

    private func setupExpandedPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 290),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isOpaque = false
        panel.alphaValue = 0
        panel.setAccessibilityIdentifier("keypunch-panel")

        let hostingView = NSHostingView(
            rootView: FloatingPanelView(store: store, showAllForTesting: isTestMode)
        )
        panel.contentView = hostingView

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: ["panel": "expanded"]
        )
        hostingView.addTrackingArea(trackingArea)

        self.expandedPanel = panel
    }

    // MARK: - Positioning

    private func positionPanels() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame

        let triggerX = visibleFrame.maxX - 48 - 8
        let triggerY = visibleFrame.midY - 80
        triggerPanel.setFrameOrigin(NSPoint(x: triggerX, y: triggerY))

        let expandedX = triggerX - 300 - 12
        let expandedY = triggerY - 65
        expandedPanel.setFrameOrigin(NSPoint(x: expandedX, y: expandedY))
    }

    @objc private func screenDidChange() {
        positionPanels()
    }

    // MARK: - Show/Hide

    func showExpandedPanel() {
        guard !isExpanded else { return }
        isExpanded = true
        hideTimer?.invalidate()
        hideTimer = nil

        updateTriggerActive(true)
        expandedPanel.orderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            expandedPanel.animator().alphaValue = 1.0
        }
    }

    func hideExpandedPanel() {
        guard isExpanded else { return }
        isExpanded = false

        updateTriggerActive(false)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            expandedPanel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.expandedPanel.orderOut(nil)
        })
    }

    func toggleExpandedPanel() {
        if isExpanded {
            hideExpandedPanel()
        } else {
            showExpandedPanel()
        }
    }

    private func updateTriggerActive(_ active: Bool) {
        triggerHostingView.rootView = FloatingTriggerView(store: store, isActive: active) { [weak self] in
            self?.showExpandedPanel()
        }
    }

    // MARK: - Mouse Events

    @objc(mouseEntered:) func mouseEntered(with event: NSEvent) {
        hideTimer?.invalidate()
        hideTimer = nil
        if !isExpanded {
            showExpandedPanel()
        }
    }

    @objc(mouseExited:) func mouseExited(with event: NSEvent) {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let triggerContains = self.triggerPanel.frame.contains(NSEvent.mouseLocation)
                let expandedContains = self.expandedPanel.frame.contains(NSEvent.mouseLocation)
                if !triggerContains && !expandedContains {
                    self.hideExpandedPanel()
                }
            }
        }
    }

    // MARK: - Click Handlers

    @objc private func triggerRightClicked(_ gesture: NSClickGestureRecognizer) {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Keypunch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        let location = gesture.location(in: triggerPanel.contentView)
        menu.popUp(positioning: nil, at: location, in: triggerPanel.contentView)
    }

    @objc private func openSettingsAction() {
        Self.openSettings()
    }

    private static var settingsWindow: NSWindow?

    static func openSettings() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }

        guard let store = KeypunchApp.sharedStore else { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 450),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Keypunch Settings"
        window.contentView = NSHostingView(rootView: SettingsView(store: store))
        window.center()
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
    }
}
