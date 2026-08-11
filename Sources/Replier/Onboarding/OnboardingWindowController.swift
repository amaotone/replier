import AppKit
import SwiftUI
#if canImport(ReplierCore)
import ReplierCore
#endif

/// Hosts `OnboardingView` in a regular, closable window. Showing it temporarily raises
/// the app's activation policy to `.regular` (so it can gain focus/Dock presence like a
/// normal app); closing it restores `.accessory` since replier is primarily a menu bar app.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let styleProfileStore: StyleProfileStore
    private var window: NSWindow?

    init(styleProfileStore: StyleProfileStore) {
        self.styleProfileStore = styleProfileStore
    }

    func show() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "replierへようこそ"
        window.contentView = NSHostingView(
            rootView: OnboardingView(
                styleProfileStore: styleProfileStore,
                onFinish: { [weak self] in self?.window?.close() }
            )
        )
        window.center()
        window.delegate = self
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
