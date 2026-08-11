import Testing
@testable import ReplierCore

@Suite struct PromptBuilderTests {
    let builder = PromptBuilder()

    private func request(
        text: String = "明日の会議、参加できますか？",
        sourceApp: SourceApp = .mail,
        intent: ReplyIntent = .accept,
        tone: Tone = .business,
        samples: [String] = []
    ) -> ReplyRequest {
        ReplyRequest(
            context: CapturedContext(text: text, sourceApp: sourceApp),
            intent: intent,
            tone: tone,
            style: StyleProfile(samples: samples)
        )
    }

    @Test func systemPromptContainsSentinelContract() {
        let prompt = builder.build(request())
        #expect(prompt.system.contains("<<<short>>>"))
        #expect(prompt.system.contains("<<<standard>>>"))
        #expect(prompt.system.contains("<<<polite>>>"))
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

    @Test func systemPromptReflectsSlackSourceApp() {
        let prompt = builder.build(request(sourceApp: .slack))
        #expect(prompt.system.contains("チャット"))
        #expect(prompt.system.contains("挨拶や署名は不要"))
    }

    @Test func systemPromptReflectsMailSourceApp() {
        let prompt = builder.build(request(sourceApp: .mail))
        #expect(prompt.system.contains("宛名"))
        #expect(prompt.system.contains("結び"))
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

    @Test func userPromptReflectsAutoIntent() {
        let prompt = builder.build(request(intent: .auto))
        #expect(prompt.user.contains("推測"))
    }

    @Test func userPromptReflectsAcceptIntent() {
        let prompt = builder.build(request(intent: .accept))
        #expect(prompt.user.contains("承諾する返信"))
    }

    @Test func userPromptReflectsDeclineIntent() {
        let prompt = builder.build(request(intent: .decline))
        #expect(prompt.user.contains("丁重に断る返信"))
    }

    @Test func userPromptReflectsQuestionIntent() {
        let prompt = builder.build(request(intent: .question))
        #expect(prompt.user.contains("不明点を確認する返信"))
    }

    @Test func userPromptReflectsFollowUpIntent() {
        let prompt = builder.build(request(intent: .followUp))
        #expect(prompt.user.contains("後で改めて連絡する旨の返信"))
    }

    @Test func userPromptFramesCustomIntentAsGistInstruction() {
        let prompt = builder.build(request(intent: .custom("英語で、少しユーモアを交えて返信してください")))
        #expect(prompt.user.contains("次の要旨・指示に沿って返信を作成してください: 英語で、少しユーモアを交えて返信してください"))
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

    @Test func userPromptStructuresCustomInstructionUnderSecondHeadingAndDoesNotAnswerIt() {
        let prompt = builder.build(request(intent: .custom("もっと簡潔に話してよ。わかりにくすぎる")))
        #expect(prompt.user.contains("# 返信で伝えたい内容(これを相手向けの文章に仕上げる。これに返答しない)"))
        let headingRange = prompt.user.range(of: "# 返信で伝えたい内容(これを相手向けの文章に仕上げる。これに返答しない)")!
        let instructionRange = prompt.user.range(of: "もっと簡潔に話してよ。わかりにくすぎる")!
        #expect(headingRange.upperBound <= instructionRange.lowerBound)
    }

    @Test func userPromptSecondHeadingAppliesUniformlyToAutoAndFixedIntents() {
        for intent in [ReplyIntent.auto, .accept, .decline, .question, .followUp] {
            let prompt = builder.build(request(intent: intent))
            #expect(prompt.user.contains("# 返信で伝えたい内容(これを相手向けの文章に仕上げる。これに返答しない)"))
        }
    }
}
