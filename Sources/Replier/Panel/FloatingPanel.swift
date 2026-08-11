import AppKit

final class FloatingPanel: NSPanel {
    /// Invoked when Esc is pressed, regardless of which view (SwiftUI-focused or a raw
    /// AppKit `NSTextView`) currently holds first responder. Set by `PanelController` to
    /// `hide()`, which is idempotent, so this is safe to fire alongside any SwiftUI-level
    /// `.onKeyPress(.escape)` handler that also catches the same press.
    var onCancel: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Standard AppKit target for Esc: whichever view is first responder routes an
    /// unhandled Esc here via `doCommand(by: #selector(cancelOperation(_:)))`'s action-message
    /// propagation up the responder chain. During active IME composition, the input method
    /// consumes Esc itself to cancel the conversion, so this never double-fires with that.
    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    /// Belt-and-braces: catches Esc from the raw keyDown path too, in case some responder in
    /// the chain never translates it into the `cancelOperation:` action message.
    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 53 else {
            super.keyDown(with: event)
            return
        }
        onCancel?()
    }
}
