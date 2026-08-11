import Testing
@testable import ReplierCore

@Suite struct CandidateParserTests {
    let parser = CandidateParser()

    private let validJSON = """
    {"candidates":[{"label":"short","text":"了解です。"},{"label":"standard","text":"承知しました。対応します。"},{"label":"polite","text":"ご連絡いただきありがとうございます。承知いたしました。"}]}
    """

    @Test func parsesPlainJSONObject() throws {
        let candidates = try parser.parse(validJSON)
        #expect(candidates.count == 3)
        #expect(candidates[0].label == .short)
        #expect(candidates[0].text == "了解です。")
        #expect(candidates[1].label == .standard)
        #expect(candidates[2].label == .polite)
    }

    @Test func parsesJSONWrappedInJsonFence() throws {
        let wrapped = "```json\n\(validJSON)\n```"
        let candidates = try parser.parse(wrapped)
        #expect(candidates.count == 3)
    }

    @Test func parsesJSONWrappedInPlainFence() throws {
        let wrapped = "```\n\(validJSON)\n```"
        let candidates = try parser.parse(wrapped)
        #expect(candidates.count == 3)
    }

    @Test func parsesJSONWithLeadingAndTrailingProse() throws {
        let wrapped = "はい、こちらが返信案です: \(validJSON) ご確認ください。"
        let candidates = try parser.parse(wrapped)
        #expect(candidates.count == 3)
    }

    @Test func throwsNoJSONFoundWhenNoBraces() {
        #expect(throws: CandidateParserError.noJSONFound) {
            try parser.parse("すみません、返信案を生成できませんでした。")
        }
    }

    @Test func throwsMalformedForUndecodableJSON() {
        #expect(throws: CandidateParserError.self) {
            try parser.parse("{this is not valid json}")
        }
    }

    @Test func malformedErrorCarriesAReason() {
        do {
            _ = try parser.parse("{this is not valid json}")
            Issue.record("expected malformed error to be thrown")
        } catch CandidateParserError.malformed(let reason) {
            #expect(!reason.isEmpty)
        } catch {
            Issue.record("expected .malformed, got \(error)")
        }
    }

    @Test func throwsWrongCandidateCountWhenNotThree() {
        let twoCandidates = """
        {"candidates":[{"label":"short","text":"了解です。"},{"label":"standard","text":"承知しました。"}]}
        """
        #expect(throws: CandidateParserError.wrongCandidateCount(2)) {
            try parser.parse(twoCandidates)
        }
    }

    @Test func throwsWrongCandidateCountWhenFour() {
        let fourCandidates = """
        {"candidates":[
            {"label":"short","text":"a"},
            {"label":"standard","text":"b"},
            {"label":"polite","text":"c"},
            {"label":"polite","text":"d"}
        ]}
        """
        #expect(throws: CandidateParserError.wrongCandidateCount(4)) {
            try parser.parse(fourCandidates)
        }
    }
}
