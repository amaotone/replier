import AppKit
import SwiftUI

/// Raycast-style transient HUD. Shows a capsule message above the floating panel's level
/// and fades itself out; never steals key/main status so it can't interrupt typing.
@MainActor
final class ToastPresenter {
    static let shared = ToastPresenter()

    private static let fadeInDuration: TimeInterval = 0.15
    private static let holdDuration: TimeInterval = 0.9
    private static let fadeOutDuration: TimeInterval = 0.3

    /// Guards against a stale fade-out (from a superseded toast) touching state that a
    /// newer `show` call already owns.
    private var generation = 0
    private var panel: ToastPanel?

    private init() {}

    func show(_ message: String, centeredAt point: NSPoint) {
        generation += 1
        let myGeneration = generation

        // Replace immediately: no fade race with whatever toast was already on screen.
        panel?.orderOut(nil)
        panel = nil

        let toastPanel = makePanel(message: message, centeredAt: point)
        panel = toastPanel

        toastPanel.alphaValue = 0
        toastPanel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeInDuration
            toastPanel.animator().alphaValue = 1
        }

        Task { [weak self] in
            let holdNanoseconds = UInt64((Self.fadeInDuration + Self.holdDuration) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: holdNanoseconds)
            guard let self, self.generation == myGeneration else { return }
            self.dismiss(toastPanel, generation: myGeneration)
        }
    }

    private func dismiss(_ toastPanel: ToastPanel, generation: Int) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeOutDuration
            toastPanel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.generation == generation else { return }
                toastPanel.orderOut(nil)
                if self.panel === toastPanel {
                    self.panel = nil
                }
            }
        }
    }

    private func makePanel(message: String, centeredAt point: NSPoint) -> ToastPanel {
        let hostingView = NSHostingView(rootView: ToastContentView(message: message))
        let size = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: size)

        let origin = NSPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
        let toastPanel = ToastPanel(contentRect: NSRect(origin: origin, size: size))
        toastPanel.contentView = hostingView
        return toastPanel
    }
}

private final class ToastPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .statusBar
        ignoresMouseEvents = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct ToastContentView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: Capsule())
            .fixedSize()
    }
}
