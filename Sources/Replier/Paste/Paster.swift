import AppKit
import CoreGraphics

@MainActor
enum Paster {
    static func paste(_ text: String) async {
        let pasteboard = NSPasteboard.general
        // Only string representations are snapshotted/restored; rich formats on the
        // clipboard (e.g. RTF, images) are not preserved across a paste operation.
        let previousString = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        sendCommandV()

        try? await Task.sleep(nanoseconds: 300_000_000)

        pasteboard.clearContents()
        if let previousString {
            pasteboard.setString(previousString, forType: .string)
        }
    }

    private static func sendCommandV() {
        let vKeyCode: CGKeyCode = 0x09
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
