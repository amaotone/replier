import Testing
@testable import ReplierCore

@Suite struct IncrementalCandidateParserTests {
    private let sampleText = """
    <<<short>>>
    短めの本文
    <<<long>>>
    長めの本文
    複数行もあり得る
    """

    @Test func splittingAcrossEveryDeltaBoundaryProducesSameResult() {
        let chars = Array(sampleText)
        for splitPoint in 0...chars.count {
            var parser = IncrementalCandidateParser()
            let first = String(chars[0..<splitPoint])
            let second = String(chars[splitPoint...])
            _ = parser.feed(first)
            _ = parser.feed(second)
            let result = parser.finish()

            #expect(result.count == 2, "split at \(splitPoint) produced \(result.count) candidates")
            guard result.count == 2 else { continue }
            #expect(result[0].label == .short)
            #expect(result[0].text == "短めの本文")
            #expect(result[1].label == .long)
            #expect(result[1].text == "長めの本文\n複数行もあり得る")
            #expect(result.allSatisfy { $0.isComplete })
        }
    }

    @Test func bothLabelsParsedInOrderAndComplete() {
        var parser = IncrementalCandidateParser()
        _ = parser.feed(sampleText)
        let result = parser.finish()

        #expect(result.count == 2)
        #expect(result.map(\.label) == [.short, .long])
        #expect(result.allSatisfy { $0.isComplete && !$0.text.isEmpty })
    }

    @Test func feedYieldsGrowingPartialsAsLinesArrive() {
        var parser = IncrementalCandidateParser()

        var result = parser.feed("<<<short>>>\n")
        #expect(result.count == 1)
        #expect(result[0].isComplete == false)
        #expect(result[0].text == "")

        result = parser.feed("短め")
        #expect(result[0].text == "")

        result = parser.feed("の本文\n")
        #expect(result[0].text == "短めの本文")
        #expect(result[0].isComplete == false)

        result = parser.feed("<<<long>>>\n")
        #expect(result.count == 2)
        #expect(result[0].isComplete == true)
        #expect(result[1].isComplete == false)
    }

    @Test func textBeforeFirstSentinelIsIgnored() {
        var parser = IncrementalCandidateParser()
        _ = parser.feed("前置きの文章です\nもう一行\n<<<short>>>\n本文\n")
        let result = parser.finish()

        #expect(result.count == 1)
        #expect(result[0].label == .short)
        #expect(result[0].text == "本文")
    }

    @Test func unrecognizedSentinelIsTreatedAsLiteralText() {
        var parser = IncrementalCandidateParser()
        _ = parser.feed("<<<short>>>\n<<<unknown>>>\n本文\n")
        let result = parser.finish()

        #expect(result.count == 1)
        #expect(result[0].text == "<<<unknown>>>\n本文")
    }

    @Test func duplicateLabelIsTreatedAsLiteralText() {
        var parser = IncrementalCandidateParser()
        _ = parser.feed("<<<short>>>\n短め\n<<<long>>>\n長め\n<<<short>>>\n重複\n")
        let result = parser.finish()

        #expect(result.count == 2)
        #expect(result[0].label == .short)
        #expect(result[0].text == "短め")
        #expect(result[1].label == .long)
        #expect(result[1].text == "長め\n<<<short>>>\n重複")
    }

    @Test func singleCandidateAtFinishIsFine() {
        var parser = IncrementalCandidateParser()
        _ = parser.feed("<<<short>>>\n短めだけ\n")
        let result = parser.finish()

        #expect(result.count == 1)
        #expect(result[0].isComplete == true)
        #expect(!result[0].text.isEmpty)
    }

    @Test func zeroCandidatesWhenNoSentinelSeen() {
        var parser = IncrementalCandidateParser()
        _ = parser.feed("宛先不明のテキストのみ\n")
        let result = parser.finish()

        #expect(result.isEmpty)
    }

    @Test func finishTrimsWhitespaceAroundCandidateText() {
        var parser = IncrementalCandidateParser()
        _ = parser.feed("<<<short>>>\n  \n本文です  \n  \n")
        let result = parser.finish()

        #expect(result.count == 1)
        #expect(result[0].text == "本文です")
    }

    @Test func midLineDeltaSplitsWithinBody() {
        var parser = IncrementalCandidateParser()
        _ = parser.feed("<<<short>>>\n短")
        _ = parser.feed("め")
        _ = parser.feed("の本文")
        let result = parser.finish()

        #expect(result.count == 1)
        #expect(result[0].text == "短めの本文")
    }

    @Test func sentinelSplitAcrossManyTinyDeltas() {
        var parser = IncrementalCandidateParser()
        for ch in "<<<long>>>\n本文\n" {
            _ = parser.feed(String(ch))
        }
        let final = parser.finish()

        #expect(final.count == 1)
        #expect(final[0].label == .long)
        #expect(final[0].text == "本文")
    }

    @Test func emptyDeltaIsANoOp() {
        var parser = IncrementalCandidateParser()
        let result = parser.feed("")
        #expect(result.isEmpty)
    }
}
