/// What a Return keypress in the instruction editor should do.
public enum ReturnAction: Sendable, Equatable {
    case submit
    case insertNewline
    case passToIME
}

/// Pure decision for Return-key handling, extracted so it's unit-testable without AppKit.
/// Marked text (active IME conversion) takes precedence over Shift: the confirming Return
/// must never submit or insert a newline while kana→kanji conversion is in progress.
public func returnAction(hasMarkedText: Bool, shiftPressed: Bool) -> ReturnAction {
    if hasMarkedText { return .passToIME }
    if shiftPressed { return .insertNewline }
    return .submit
}
