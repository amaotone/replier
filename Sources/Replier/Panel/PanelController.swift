import AppKit
import SwiftUI
#if canImport(ReplierCore)
import ReplierCore
#endif

@MainActor
final class PanelController {
    private static let initialSize = NSSize(width: 760, height: 460)
    /// The panel is capped at this fraction of the target screen's visible height; beyond
    /// that, candidate text scrolls inside its card instead of growing the panel further.
    private static let maxHeightFraction: CGFloat = 0.7
    /// Delays (seconds) for the post-open focus retry loop; see `retryFocus`.
    private static let focusRetryDelays: [TimeInterval] = [0, 0.1, 0.3]

    private var panel: FloatingPanel?
    private var resizeObserver: NSObjectProtocol?
    private var resignKeyObserver: NSObjectProtocol?
    /// The model backing whatever is currently shown, so `hide()` can cancel its in-flight
    /// generation regardless of which path triggered the hide (Esc, confirm, focus loss).
    private var currentModel: PanelModel?
    /// Top edge and horizontal center recorded at `position(_:hostingView:screen:)` time.
    /// SwiftUI content growth (via `NSHostingView.sizingOptions = .preferredContentSize`)
    /// resizes the panel automatically but keeps its bottom-left corner fixed by default;
    /// `reanchor(_:)` corrects the frame on every resize so the panel instead grows downward
    /// from where it first appeared.
    private var anchorTopY: CGFloat = 0
    private var anchorCenterX: CGFloat = 0
    private let drafter: any ReplyDrafting
    private let styleProfileStore: StyleProfileStore

    init(drafter: any ReplyDrafting, styleProfileStore: StyleProfileStore) {
        self.drafter = drafter
        self.styleProfileStore = styleProfileStore
    }

    /// Reads the current selection (or falls back to empty context, letting the user
    /// paste/type into the context editor) and loads the style profile fresh from disk
    /// so samples added via onboarding/settings take effect without an app restart.
    func show() {
        let selection = SelectionReader.read()

        let panel = panel ?? makePanel()
        self.panel = panel

        Task { [weak self] in
            guard let self else { return }
            let style = (try? await self.styleProfileStore.profile()) ?? StyleProfile()

            let model = PanelModel(
                contextText: selection?.text ?? "",
                sourceApp: selection?.sourceApp ?? .other,
                drafter: self.drafter,
                style: style
            )
            self.currentModel = model

            let screen = self.screenWithMouse() ?? NSScreen.main
            let visibleHeight = screen?.visibleFrame.height ?? Self.initialSize.height
            let maxContentHeight = visibleHeight * Self.maxHeightFraction

            let rootView = PanelView(
                model: model,
                maxContentHeight: maxContentHeight,
                onConfirm: { [weak self] text in
                    self?.confirm(text: text)
                },
                onCancel: { [weak self] in
                    self?.hide()
                }
            )
            let hostingView = NSHostingView(rootView: rootView)
            hostingView.sizingOptions = .preferredContentSize
            panel.contentView = hostingView

            self.position(panel, hostingView: hostingView, screen: screen)
            self.observeResize(of: panel)

            panel.orderFrontRegardless()
            panel.makeKey()
            // Bumped after the panel is key so PanelView's `.onChange(of:)` handler (not
            // `.onAppear`, which fires too early) can reliably refocus the instruction field.
            model.requestFocus()
            self.retryFocus(panel: panel, model: model, hostingView: hostingView)
        }
    }

    /// Idempotent: `orderOut(nil)` on an already-hidden panel is a harmless no-op, which
    /// matters now that Esc can be handled both by `FloatingPanel.onCancel` and by SwiftUI's
    /// own `.onKeyPress(.escape)` for the same keypress — and now that `orderOut` itself can
    /// resign key status and re-enter here via `observeResignKey`. That re-entrant call finds
    /// the panel already ordered out (no further resign notification fires) and
    /// `cancelGeneration()` already idle, so it terminates without looping.
    func hide() {
        currentModel?.cancelGeneration()
        panel?.orderOut(nil)
    }

    private func confirm(text: String) {
        let center = panel.map { NSPoint(x: $0.frame.midX, y: $0.frame.midY) }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        hide()

        guard let center else { return }
        ToastPresenter.shared.show("コピーしました", centeredAt: center)
    }

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: Self.initialSize))
        panel.onCancel = { [weak self] in self?.hide() }
        observeResignKey(of: panel)
        return panel
    }

    /// Spotlight-style auto-hide: clicking into another app/window or ⌘Tabbing away resigns
    /// the panel's key status, which should close it. Registered once, when the panel is
    /// created (it's reused for the app's lifetime), rather than on every `show()`.
    /// `queue: .main` dispatches the block asynchronously even though we're already on the
    /// main thread, so this never re-enters `hide()` synchronously from within `orderOut`.
    private func observeResignKey(of panel: FloatingPanel) {
        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }
    }

    /// Positions the panel centered horizontally at roughly the top third of `screen`, sized
    /// to `hostingView`'s natural fitting height (fixed width) instead of a hardcoded guess.
    /// This is what makes the panel actually contract back down to a short composing view
    /// instead of retaining a previous session's taller frame. Records the top edge +
    /// horizontal center as anchors for `reanchor(_:)`.
    private func position(_ panel: FloatingPanel, hostingView: NSHostingView<PanelView>, screen: NSScreen?) {
        guard let frame = screen?.visibleFrame else { return }

        hostingView.layoutSubtreeIfNeeded()
        let fittingHeight = hostingView.fittingSize.height
        let size = NSSize(width: Self.initialSize.width, height: max(fittingHeight, 1))
        let originX = frame.origin.x + (frame.width - size.width) / 2
        let originY = frame.origin.y + frame.height - frame.height / 3 - size.height / 2

        anchorCenterX = originX + size.width / 2
        anchorTopY = originY + size.height

        panel.setFrame(NSRect(x: originX, y: originY, width: size.width, height: size.height), display: true)
    }

    private func observeResize(of panel: FloatingPanel) {
        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
        }
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: panel,
            queue: .main
        ) { [weak self, weak panel] _ in
            Task { @MainActor in
                guard let self, let panel else { return }
                self.reanchor(panel)
            }
        }
    }

    /// Re-applies the recorded top edge + horizontal center anchors to `panel`'s current
    /// size. Only changes the origin (not the size), so this does not itself trigger another
    /// resize notification.
    private func reanchor(_ panel: FloatingPanel) {
        let size = panel.frame.size
        let target = NSRect(
            x: anchorCenterX - size.width / 2,
            y: anchorTopY - size.height,
            width: size.width,
            height: size.height
        )
        guard target.origin != panel.frame.origin else { return }
        panel.setFrame(target, display: true)
    }

    private func screenWithMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
    }

    /// Focus sometimes doesn't stick right after `makeKey()` (the hosting view's layout may
    /// not have settled yet). Retries at increasing delays, each re-bumping
    /// `model.focusRequest` (SwiftUI path) and directly locating + focusing the instruction
    /// editor's `NSTextView` (AppKit fallback) — stops as soon as it already holds focus.
    private func retryFocus(panel: FloatingPanel, model: PanelModel, hostingView: NSView, attempt: Int = 0) {
        guard attempt < Self.focusRetryDelays.count else { return }

        let delay = Self.focusRetryDelays[attempt]
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak panel, weak model, weak hostingView] in
            guard let self, let panel, let model, let hostingView else { return }
            guard panel.firstResponder as? NSTextView == nil else { return }

            model.requestFocus()
            if let textView = Self.findTextView(in: hostingView) {
                panel.makeFirstResponder(textView)
            }

            self.retryFocus(panel: panel, model: model, hostingView: hostingView, attempt: attempt + 1)
        }
    }

    private static func findTextView(in view: NSView) -> NSTextView? {
        if let textView = view as? NSTextView { return textView }
        for subview in view.subviews {
            if let found = findTextView(in: subview) { return found }
        }
        return nil
    }
}
