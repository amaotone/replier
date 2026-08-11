import Testing
@testable import ReppCore

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

    @Test func systemPromptContainsJSONContractKeys() {
        let prompt = builder.build(request())
        #expect(prompt.system.contains("\"candidates\""))
        #expect(prompt.system.contains("\"label\""))
        #expect(prompt.system.contains("\"short\""))
        #expect(prompt.system.contains("\"standard\""))
        #expect(prompt.system.contains("\"polite\""))
    }

    @Test func systemPromptInstructsFirstPersonAndJSONOnlyOutput() {
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

    @Test func userPromptReflectsCustomIntentVerbatim() {
        let prompt = builder.build(request(intent: .custom("英語で、少しユーモアを交えて返信してください")))
        #expect(prompt.user.contains("英語で、少しユーモアを交えて返信してください"))
    }
}
