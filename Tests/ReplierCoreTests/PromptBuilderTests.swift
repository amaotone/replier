import Testing
@testable import ReplierCore

@Suite struct PromptBuilderTests {
    let builder = PromptBuilder()

    private func request(
        text: String = "明日の会議、参加できますか？",
        sourceApp: SourceApp = .mail,
        gist: String = "承諾する返信を作成してください。",
        tone: Tone = .business,
        situation: Situation = .mail,
        samples: [String] = [],
        format: OutputFormat = .plain
    ) -> ReplyRequest {
        ReplyRequest(
            context: CapturedContext(text: text, sourceApp: sourceApp),
            gist: gist,
            tone: tone,
            situation: situation,
            style: StyleProfile(samples: samples),
            format: format
        )
    }

    @Test func systemPromptContainsSentinelContract() {
        let prompt = builder.build(request())
        #expect(prompt.system.contains("<<<short>>>"))
        #expect(prompt.system.contains("<<<long>>>"))
    }

    @Test func systemPromptDefinesShortAndLongLengths() {
        let prompt = builder.build(request())
        #expect(prompt.system.contains("1〜2文"))
        #expect(prompt.system.contains("3〜6文"))
    }

    @Test func systemPromptNoLongerContainsJSONContract() {
        let prompt = builder.build(request())
        #expect(!prompt.system.contains("candidates"))
        #expect(!prompt.system.contains("\"label\""))
    }

    @Test func systemPromptInstructsFirstPersonAndPlainTextOnlyOutput() {
        let prompt = builder.build(request())
        #expect(prompt.system.contains("一人称"))
        #expect(prompt.system.contains("マークダウン"))
    }

    @Test func systemPromptReflectsBusinessTone() {
        let prompt = builder.build(request(tone: .business))
        #expect(prompt.system.contains("ビジネスにふさわしい丁寧さ"))
    }

    @Test func systemPromptReflectsCasualTone() {
        let prompt = builder.build(request(tone: .casual))
        #expect(prompt.system.contains("砕けた口調"))
    }

    @Test func systemPromptReflectsChatSituation() {
        let prompt = builder.build(request(situation: .chat))
        #expect(prompt.system.contains("チャット"))
        #expect(prompt.system.contains("挨拶や署名は不要"))
    }

    @Test func systemPromptReflectsMailSituation() {
        let prompt = builder.build(request(situation: .mail))
        #expect(prompt.system.contains("宛名"))
        #expect(prompt.system.contains("結び"))
    }

    @Test func systemPromptReflectsPlainFormat() {
        let prompt = builder.build(request(format: .plain))
        #expect(prompt.system.contains("通常の文章として書く"))
    }

    @Test func systemPromptReflectsStructuredFormat() {
        let prompt = builder.build(request(format: .structured))
        #expect(prompt.system.contains("箇条書きや番号リストを積極的に使い"))
    }

    @Test func systemPromptOmitsStyleSectionWhenSamplesEmpty() {
        let prompt = builder.build(request(samples: []))
        #expect(!prompt.system.contains("文体"))
    }

    @Test func systemPromptIncludesStyleSamplesWhenPresent() {
        let prompt = builder.build(request(samples: ["いつもお世話になっております。", "了解です！"]))
        #expect(prompt.system.contains("いつもお世話になっております。"))
        #expect(prompt.system.contains("了解です！"))
        #expect(prompt.system.contains("文体"))
    }

    @Test func userPromptContainsIncomingMessageText() {
        let prompt = builder.build(request(text: "来週火曜、空いてますか？"))
        #expect(prompt.user.contains("来週火曜、空いてますか？"))
    }

    @Test func userPromptRendersGistDirectly() {
        let prompt = builder.build(request(gist: "英語で、少しユーモアを交えて返信してください"))
        #expect(prompt.user.contains("英語で、少しユーモアを交えて返信してください"))
    }

    @Test func systemPromptDefinesRoleModelForIncomingMessageAndGist() {
        let prompt = builder.build(request())
        #expect(prompt.system.contains("受信メッセージ"))
        #expect(prompt.system.contains("返信で伝えたい内容"))
        #expect(prompt.system.contains("返答すべきメッセージでもない"))
    }

    @Test func systemPromptForbidsConvertingRequestsIntoApologies() {
        let prompt = builder.build(request())
        #expect(prompt.system.contains("謝罪や自分の行動改善の約束に変換してはならない"))
    }

    @Test func systemPromptIncludesOneShotContrastExample() {
        let prompt = builder.build(request())
        #expect(prompt.system.contains("✅"))
        #expect(prompt.system.contains("❌"))
        #expect(prompt.system.contains("恐れ入りますが、要点を絞って簡潔にご説明いただけると助かります。"))
        #expect(prompt.system.contains("すみません、今後は簡潔に伝えます。"))
    }

    @Test func userPromptStructuresIncomingMessageUnderFirstHeading() {
        let prompt = builder.build(request(text: "来週火曜、空いてますか？"))
        #expect(prompt.user.contains("# 受信メッセージ(これに返信する)"))
        let headingRange = prompt.user.range(of: "# 受信メッセージ(これに返信する)")!
        let textRange = prompt.user.range(of: "来週火曜、空いてますか？")!
        #expect(headingRange.upperBound <= textRange.lowerBound)
    }

    @Test func userPromptStructuresGistUnderSecondHeadingAndDoesNotAnswerIt() {
        let prompt = builder.build(request(gist: "もっと簡潔に話してよ。わかりにくすぎる"))
        #expect(prompt.user.contains("# 返信で伝えたい内容(これを相手向けの文章に仕上げる。これに返答しない)"))
        let headingRange = prompt.user.range(of: "# 返信で伝えたい内容(これを相手向けの文章に仕上げる。これに返答しない)")!
        let gistRange = prompt.user.range(of: "もっと簡潔に話してよ。わかりにくすぎる")!
        #expect(headingRange.upperBound <= gistRange.lowerBound)
    }
}
