import AppKit
import SwiftUI
#if canImport(ReplierCore)
import ReplierCore
#endif

/// NSTextView-backed multi-line editor for the instruction/gist field, replacing
/// `TextField(axis: .vertical)` so Shift+Enter can insert a newline (Option+Enter previously
/// did, via AppKit's own key bindings) while staying fully IME-safe. Grows from ~3 to ~5
/// visible lines, then scrolls internally.
struct GistTextEditor: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    let onCancel: () -> Void

    private static let font = NSFont.systemFont(ofSize: 13)
    private static let minLines: CGFloat = 3
    private static let maxLines: CGFloat = 5
    private static let containerInset = NSSize(width: 4, height: 6)

    private static var lineHeight: CGFloat {
        NSLayoutManager().defaultLineHeight(for: font)
    }

    func makeNSView(context: Context) -> GrowingScrollView {
        let textView = PlaceholderTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.placeholderString = placeholder
        textView.font = Self.font
        textView.isRichText = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = Self.containerInset
        textView.drawsBackground = false
        textView.allowsUndo = true

        let scrollView = GrowingScrollView()
        scrollView.minHeight = Self.lineHeight * Self.minLines + Self.containerInset.height * 2
        scrollView.maxHeight = Self.lineHeight * Self.maxLines + Self.containerInset.height * 2
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .lineBorder
        scrollView.documentView = textView
        // Auto Layout (not the autoresizing mask) must drive sizing so `intrinsicContentSize`
        // is actually consulted by SwiftUI's NSViewRepresentable host.
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }

    func updateNSView(_ scrollView: GrowingScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? PlaceholderTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.placeholderString = placeholder
        textView.needsDisplay = true
        scrollView.invalidateIntrinsicContentSize()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: GistTextEditor

        init(parent: GistTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            (textView.enclosingScrollView as? GrowingScrollView)?.invalidateIntrinsicContentSize()
        }

        /// ↑↓ are intentionally left unhandled here (no `moveUp:`/`moveDown:` cases) — IME
        /// candidate navigation needs them.
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let hasMarkedText = textView.hasMarkedText()
                let shiftPressed = NSApp.currentEvent?.modifierFlags.contains(.shift) == true
                switch returnAction(hasMarkedText: hasMarkedText, shiftPressed: shiftPressed) {
                case .passToIME:
                    return false
                case .insertNewline:
                    textView.insertNewlineIgnoringFieldEditor(nil)
                    return true
                case .submit:
                    parent.onSubmit()
                    return true
                }
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                // Deliberately not calling `parent.onCancel()` here: returning false lets the
                // action message bubble up the responder chain to `FloatingPanel.cancelOperation`,
                // which is the single source of truth for Esc (avoids double-handling).
                return false
            }
            return false
        }
    }
}

/// Draws placeholder text manually since `NSTextView` has no native placeholder support.
final class PlaceholderTextView: NSTextView {
    var placeholderString: String = ""

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholderString.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? .systemFont(ofSize: 13),
            .foregroundColor: NSColor.placeholderTextColor,
        ]
        let padding = textContainer?.lineFragmentPadding ?? 0
        let origin = NSPoint(x: textContainerInset.width + padding, y: textContainerInset.height)
        placeholderString.draw(at: origin, withAttributes: attributes)
    }
}

/// An `NSScrollView` whose intrinsic content height tracks its document text view's laid-out
/// content, clamped to `[minHeight, maxHeight]` — this is what makes `GistTextEditor` grow
/// from ~3 to ~5 lines and then scroll internally past that.
final class GrowingScrollView: NSScrollView {
    var minHeight: CGFloat = 0
    var maxHeight: CGFloat = 0

    override var intrinsicContentSize: NSSize {
        guard let textView = documentView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else {
            return NSSize(width: NSView.noIntrinsicMetric, height: minHeight)
        }

        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer)
        let height = used.height + textView.textContainerInset.height * 2
        return NSSize(width: NSView.noIntrinsicMetric, height: min(max(height, minHeight), maxHeight))
    }
}
