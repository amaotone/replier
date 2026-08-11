import AppKit
import SwiftUI
import ReplierCore

@MainActor
final class PanelController {
    private static let panelSize = NSSize(width: 640, height: 420)

    private var panel: FloatingPanel?
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

            let rootView = PanelView(
                model: model,
                onConfirm: { [weak self] text in
                    self?.confirm(text: text)
                },
                onCancel: { [weak self] in
                    self?.hide()
                }
            )
            panel.contentView = NSHostingView(rootView: rootView)

            self.position(panel)
            panel.orderFrontRegardless()
            panel.makeKey()
        }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func confirm(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        hide()
    }

    private func makePanel() -> FloatingPanel {
        FloatingPanel(contentRect: NSRect(origin: .zero, size: Self.panelSize))
    }

    private func position(_ panel: FloatingPanel) {
        let screen = screenWithMouse() ?? NSScreen.main
        guard let frame = screen?.frame else { return }

        let size = Self.panelSize
        let originX = frame.origin.x + (frame.width - size.width) / 2
        let originY = frame.origin.y + frame.height - frame.height / 3 - size.height / 2

        panel.setFrame(NSRect(x: originX, y: originY, width: size.width, height: size.height), display: true)
    }

    private func screenWithMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
    }
}
