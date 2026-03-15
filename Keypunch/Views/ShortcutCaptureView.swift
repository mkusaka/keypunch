import KeyboardShortcuts
import SwiftUI

class ShortcutCaptureView: NSView {
    var onCapture: ((KeyboardShortcuts.Shortcut) -> Void)?
    var onCancel: (() -> Void)?
    private var didComplete = false

    override var acceptsFirstResponder: Bool {
        true
    }

    override var canBecomeKeyView: Bool {
        true
    }

    private func complete() {
        guard !didComplete else { return }
        didComplete = true
    }

    override func keyDown(with event: NSEvent) {
        guard !didComplete else { return }

        if event.keyCode == 53 {
            complete()
            onCancel?()
            return
        }

        guard let shortcut = KeyboardShortcuts.Shortcut(event: event) else { return }
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty else { return }

        complete()
        onCapture?(shortcut)
    }

    override func resignFirstResponder() -> Bool {
        if !didComplete {
            complete()
            onCancel?()
        }
        return super.resignFirstResponder()
    }
}

struct ShortcutCaptureRepresentable: NSViewRepresentable {
    let name: KeyboardShortcuts.Name
    let onShortcutSet: (KeyboardShortcuts.Shortcut) -> Void
    let onRecordingEnd: () -> Void

    func makeNSView(context _: Context) -> ShortcutCaptureView {
        let view = ShortcutCaptureView()
        view.onCapture = { shortcut in
            KeyboardShortcuts.setShortcut(shortcut, for: name)
            onShortcutSet(shortcut)
        }
        view.onCancel = {
            onRecordingEnd()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let window = view.window else { return }
            window.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_: ShortcutCaptureView, context _: Context) {}

    static func dismantleNSView(_: ShortcutCaptureView, coordinator _: ()) {}
}
