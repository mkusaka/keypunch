import AppKit
import SwiftUI
import KeyboardShortcuts
import ServiceManagement

@MainActor
final class FloatingWidgetController: NSObject {
    private var triggerPanel: NSPanel!
    private var expandedPanel: NSPanel!
    private var tooltipPanel: NSPanel!
    private let store: ShortcutStore
    private let isTestMode: Bool
    private var isExpanded = false
    private var hideTimer: Timer?
    private var triggerHostingView: NSHostingView<FloatingTriggerView>!
    private var dragStartOrigin: NSPoint?

    private static let triggerPositionXKey = "triggerPositionX"
    private static let triggerPositionYKey = "triggerPositionY"

    init(store: ShortcutStore, isTestMode: Bool) {
        self.store = store
        self.isTestMode = isTestMode
        super.init()
    }

    func setup() {
        setupTriggerPanel()
        setupExpandedPanel()
        setupTooltipPanel()
        positionTrigger()
        triggerPanel.orderFront(nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(triggerDidMove),
            name: NSWindow.didMoveNotification,
            object: triggerPanel
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

        let hostingView = NSHostingView(rootView: makeTriggerView(isActive: false))
        panel.contentView = hostingView
        triggerHostingView = hostingView

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
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 380),
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
            rootView: FloatingPanelView(
                store: store,
                showAllForTesting: isTestMode
            )
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

    private func setupTooltipPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
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
        panel.ignoresMouseEvents = true

        self.tooltipPanel = panel
    }

    // MARK: - Trigger View Factory

    private func makeTriggerView(isActive: Bool) -> FloatingTriggerView {
        FloatingTriggerView(
            store: store,
            isActive: isActive,
            onShowPanel: { [weak self] in
                self?.showExpandedPanel()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            },
            onHideTrigger: { [weak self] in
                self?.hideTriggerAnimated()
            },
            onToggleLoginItem: { [weak self] in
                self?.toggleLoginItem()
            },
            isLoginItemEnabled: SMAppService.mainApp.status == .enabled,
            onTooltipChanged: { [weak self] text in
                self?.showTooltip(text)
            },
            onDrag: { [weak self] translation in
                guard let self else { return }
                if self.dragStartOrigin == nil {
                    self.dragStartOrigin = self.triggerPanel.frame.origin
                }
                guard let startOrigin = self.dragStartOrigin else { return }
                self.triggerPanel.setFrameOrigin(NSPoint(
                    x: startOrigin.x + translation.width,
                    y: startOrigin.y - translation.height
                ))
            },
            onDragEnd: { [weak self] in
                self?.dragStartOrigin = nil
            }
        )
    }

    // MARK: - Tooltip

    private func showTooltip(_ text: String?) {
        if let text {
            let tooltipView = Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .fixedSize()

            let hostingView = NSHostingView(rootView: tooltipView)
            tooltipPanel.contentView = hostingView
            let size = hostingView.fittingSize
            tooltipPanel.setContentSize(size)

            let triggerFrame = triggerPanel.frame
            let screenCenterX = NSScreen.main?.visibleFrame.midX ?? 0

            let x: CGFloat
            if triggerFrame.midX > screenCenterX {
                x = triggerFrame.minX - size.width - 8
            } else {
                x = triggerFrame.maxX + 8
            }
            let y = triggerFrame.midY - size.height / 2

            tooltipPanel.setFrameOrigin(NSPoint(x: x, y: y))
            tooltipPanel.orderFront(nil)

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                tooltipPanel.animator().alphaValue = 1
            }
        } else {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.1
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                tooltipPanel.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                self?.tooltipPanel.orderOut(nil)
            })
        }
    }

    // MARK: - Positioning

    private func positionTrigger() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame

        let savedX = UserDefaults.standard.object(forKey: Self.triggerPositionXKey) as? CGFloat
        let savedY = UserDefaults.standard.object(forKey: Self.triggerPositionYKey) as? CGFloat

        let triggerX: CGFloat
        let triggerY: CGFloat

        if let savedX, let savedY {
            triggerX = savedX
            triggerY = savedY
        } else {
            triggerX = visibleFrame.maxX - 48 - 8
            triggerY = visibleFrame.midY - 80
        }

        triggerPanel.setFrameOrigin(NSPoint(x: triggerX, y: triggerY))
    }

    private func positionExpandedPanel() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let triggerFrame = triggerPanel.frame
        let screenCenterX = visibleFrame.midX

        let expandedX: CGFloat
        if triggerFrame.midX > screenCenterX {
            expandedX = triggerFrame.minX - expandedPanel.frame.width - 12
        } else {
            expandedX = triggerFrame.maxX + 12
        }

        let expandedY = triggerFrame.midY - expandedPanel.frame.height / 2

        let clampedX = max(visibleFrame.minX, min(expandedX, visibleFrame.maxX - expandedPanel.frame.width))
        let clampedY = max(visibleFrame.minY, min(expandedY, visibleFrame.maxY - expandedPanel.frame.height))

        expandedPanel.setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
    }

    @objc private func screenDidChange() {
        positionTrigger()
    }

    @objc private func triggerDidMove() {
        let origin = triggerPanel.frame.origin
        UserDefaults.standard.set(origin.x, forKey: Self.triggerPositionXKey)
        UserDefaults.standard.set(origin.y, forKey: Self.triggerPositionYKey)
    }

    // MARK: - Show/Hide

    func showExpandedPanel() {
        guard !isExpanded else { return }
        isExpanded = true
        hideTimer?.invalidate()
        hideTimer = nil

        positionExpandedPanel()
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
        triggerHostingView.rootView = makeTriggerView(isActive: active)
    }

    // MARK: - Trigger Visibility

    func showTrigger() {
        triggerPanel.orderFront(nil)
    }

    private func hideTriggerAnimated() {
        showTooltip(nil)
        hideExpandedPanel()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            triggerPanel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.triggerPanel.orderOut(nil)
            self?.triggerPanel.alphaValue = 1
        })
    }

    // MARK: - Login Item

    private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("Failed to toggle login item: \(error)")
        }
        updateTriggerActive(isExpanded)
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
        guard NSApp.modalWindow == nil else { return }
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
}
