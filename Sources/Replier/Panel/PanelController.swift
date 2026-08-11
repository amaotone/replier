import AppKit
import SwiftUI
import ReplierCore

@MainActor
final class PanelController {
    private static let panelSize = NSSize(width: 640, height: 420)

    private var panel: FloatingPanel?
    private let drafter: any ReplyDrafting
    private let style: StyleProfile

    init(drafter: any ReplyDrafting, style: StyleProfile) {
        self.drafter = drafter
        self.style = style
    }

    func show() {
        guard let selection = SelectionReader.read() else { return }

        let model = PanelModel(
            contextText: selection.text,
            sourceApp: selection.sourceApp,
            drafter: drafter,
            style: style
        )

        let panel = panel ?? makePanel()
        self.panel = panel

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

        position(panel)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func confirm(text: String) {
        hide()
        Task {
            await Paster.paste(text)
        }
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
