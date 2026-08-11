import AppKit
import ApplicationServices
import ReplierCore

struct CapturedSelection: Sendable {
    let text: String
    let sourceApp: SourceApp
    let usedClipboardFallback: Bool
}

@MainActor
enum SelectionReader {
    static func hasAccessibilityPermission(prompt: Bool) -> Bool {
        let options: NSDictionary = ["AXTrustedCheckOptionPrompt": prompt]
        return AXIsProcessTrustedWithOptions(options)
    }

    static func read() -> CapturedSelection? {
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let sourceApp = SourceAppClassifier.classify(bundleID: frontmostApp?.bundleIdentifier)

        if let pid = frontmostApp?.processIdentifier,
           let selectedText = readSelectedText(pid: pid),
           !selectedText.isEmpty {
            return CapturedSelection(text: selectedText, sourceApp: sourceApp, usedClipboardFallback: false)
        }

        if let clipboardText = NSPasteboard.general.string(forType: .string), !clipboardText.isEmpty {
            return CapturedSelection(text: clipboardText, sourceApp: sourceApp, usedClipboardFallback: true)
        }

        return nil
    }

    private static func readSelectedText(pid: pid_t) -> String? {
        let appElement = AXUIElementCreateApplication(pid)

        var focusedElement: AnyObject?
        let focusedResult = AXUIElementCopyAttributeValue(
            appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement
        )
        guard focusedResult == .success, let focusedElement else { return nil }
        let element = focusedElement as! AXUIElement

        var selectedTextValue: AnyObject?
        let selectedResult = AXUIElementCopyAttributeValue(
            element, kAXSelectedTextAttribute as CFString, &selectedTextValue
        )
        guard selectedResult == .success, let text = selectedTextValue as? String else { return nil }
        return text
    }
}
