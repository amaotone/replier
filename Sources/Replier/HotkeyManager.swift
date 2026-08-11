import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let openPanel = Self("openReplierPanel", default: .init(.r, modifiers: [.command, .option]))
}

@MainActor
final class HotkeyManager {
    init(onOpenPanel: @escaping () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .openPanel) {
            onOpenPanel()
        }
    }
}
