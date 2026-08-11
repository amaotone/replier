import Testing
@testable import ReplierCore

@Suite struct ReturnActionTests {
    @Test func plainReturnSubmits() {
        #expect(returnAction(hasMarkedText: false, shiftPressed: false) == .submit)
    }

    @Test func shiftReturnInsertsNewline() {
        #expect(returnAction(hasMarkedText: false, shiftPressed: true) == .insertNewline)
    }

    @Test func markedTextReturnPassesToIME() {
        #expect(returnAction(hasMarkedText: true, shiftPressed: false) == .passToIME)
    }

    @Test func markedTextTakesPrecedenceOverShift() {
        #expect(returnAction(hasMarkedText: true, shiftPressed: true) == .passToIME)
    }
}
