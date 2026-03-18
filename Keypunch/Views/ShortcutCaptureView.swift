import AppKit
import KeypunchKeyboardShortcuts
import SwiftUI

final class ShortcutCaptureView: NSView {
    var onCapture: ((KeyboardShortcutsClient.Shortcut) -> Void)?
    var onCancel: (() -> Void)?
    var isCaptureActive = false

    private var didComplete = false
    private var eventMonitor: Any?

    deinit {
        removeMonitor()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window == nil {
            removeMonitor()
        } else {
            installMonitorIfNeeded()
        }
    }

    private func complete() {
        guard !didComplete else { return }
        didComplete = true
    }

    private func installMonitorIfNeeded() {
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    private func removeMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard !didComplete, isCaptureActive else { return event }
        guard window?.isKeyWindow == true else { return event }
        if let eventWindow = event.window, eventWindow != window {
            return event
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let navigationOnly = !flags.contains(.command)
            && !flags.contains(.control)
            && !flags.contains(.option)
            && !flags.contains(.function)
            && !flags.contains(.capsLock)
            && !flags.contains(.numericPad)

        if event.keyCode == 48, navigationOnly {
            return event
        }

        if event.keyCode == 53, navigationOnly {
            complete()
            onCancel?()
            return nil
        }

        guard let shortcut = KeyboardShortcutsClient.Shortcut(event: event) else { return nil }
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty else { return nil }

        complete()
        onCapture?(shortcut)
        return nil
    }
}

struct ShortcutCaptureRepresentable: NSViewRepresentable {
    let name: KeyboardShortcutsClient.Name
    let isCaptureActive: Bool
    let onShortcutSet: (KeyboardShortcutsClient.Shortcut) -> Void
    let onRecordingEnd: () -> Void

    func makeNSView(context _: Context) -> ShortcutCaptureView {
        let view = ShortcutCaptureView()
        view.onCapture = { shortcut in
            KeyboardShortcutsClient.setShortcut(shortcut, for: name)
            onShortcutSet(shortcut)
        }
        view.onCancel = {
            onRecordingEnd()
        }
        view.isCaptureActive = isCaptureActive
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureView, context _: Context) {
        nsView.isCaptureActive = isCaptureActive
    }

    static func dismantleNSView(_: ShortcutCaptureView, coordinator _: ()) {}
}
