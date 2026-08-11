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

    private var panel: FloatingPanel?
    private var resizeObserver: NSObjectProtocol?
    /// Top edge and horizontal center recorded at `position(_:screen:)` time. SwiftUI content
    /// growth (via `NSHostingView.sizingOptions = .preferredContentSize`) resizes the panel
    /// automatically but keeps its bottom-left corner fixed by default; `reanchor(_:)`
    /// corrects the frame on every resize so the panel instead grows downward from where it
    /// first appeared.
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

            self.position(panel, screen: screen)
            self.observeResize(of: panel)

            panel.orderFrontRegardless()
            panel.makeKey()
            // Bumped after the panel is key so PanelView's `.onChange(of:)` handler (not
            // `.onAppear`, which fires too early) can reliably refocus the instruction field.
            model.requestFocus()
        }
    }

    func hide() {
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
        FloatingPanel(contentRect: NSRect(origin: .zero, size: Self.initialSize))
    }

    /// Positions the panel centered horizontally at roughly the top third of `screen`, and
    /// records the top edge + horizontal center as anchors for `reanchor(_:)`.
    private func position(_ panel: FloatingPanel, screen: NSScreen?) {
        guard let frame = screen?.visibleFrame else { return }

        let size = Self.initialSize
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
}
