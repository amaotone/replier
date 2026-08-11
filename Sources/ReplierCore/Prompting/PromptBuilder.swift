public struct PromptBuilder: Sendable {
    public init() {}

    public func build(_ request: ReplyRequest) -> Prompt {
        Prompt(system: systemPrompt(for: request), user: userPrompt(for: request))
    }

    private func systemPrompt(for request: ReplyRequest) -> String {
        var sections: [String] = [
            """
            あなたは優秀なアシスタントです。ユーザー本人になりきり、一人称で返信文を作成してください。
            出力は次の形式のプレーンテキストのみとし、前置きや説明、マークダウンのコードフェンスなどの余計な文章は一切含めないでください。センチネル行(<<<...>>>)はそれぞれ単独の行に、必ずこの順序で出力してください。
            <<<short>>>
            (短め案の本文)
            <<<standard>>>
            (標準案の本文)
            <<<polite>>>
            (丁寧案の本文)
            返信は届いたメッセージと同じ言語で書いてください。
            - short: 簡潔な返信(1-2文)
            - standard: 標準的な長さの返信
            - polite: standardよりも丁寧な返信
            """,
            toneInstruction(for: request.tone),
            sourceAppInstruction(for: request.context.sourceApp),
        ]

        if let styleSection = styleInstruction(for: request.style) {
            sections.append(styleSection)
        }

        return sections.joined(separator: "\n\n")
    }

    private func toneInstruction(for tone: Tone) -> String {
        switch tone {
        case .business:
            return "トーン: ビジネスにふさわしい丁寧さを心がけてください。"
        case .casual:
            return "トーン: 砕けた口調で書いてください。"
        }
    }

    private func sourceAppInstruction(for sourceApp: SourceApp) -> String {
        switch sourceApp {
        case .slack:
            return "送信先はチャット(Slack)です。チャット向けの文体にし、挨拶や署名は不要です。"
        case .mail:
            return "送信先はメールです。メールの作法に従い、宛名と結びの言葉を適切に含めてください。"
        case .browser, .other:
            return "送信先は特定のフォーマットを問いません。ニュートラルな文体で書いてください。"
        }
    }

    private func styleInstruction(for style: StyleProfile) -> String? {
        guard !style.samples.isEmpty else { return nil }
        let examples = style.samples
            .enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        return """
        以下はユーザー本人の過去の文章例です。この文体・口調を模倣してください。
        \(examples)
        """
    }

    private func userPrompt(for request: ReplyRequest) -> String {
        """
        以下は受信したメッセージです。
        ---
        \(request.context.text)
        ---

        \(intentInstruction(for: request.intent))
        """
    }

    private func intentInstruction(for intent: ReplyIntent) -> String {
        switch intent {
        case .auto:
            return "メッセージ内容から、送り手が最も自然に返すべき意図(承諾・お断り・質問への回答・確認など)を推測して返信を作ってください。"
        case .accept:
            return "承諾する返信を作成してください。"
        case .decline:
            return "丁重に断る返信を作成してください。"
        case .question:
            return "不明点を確認する返信を作成してください。"
        case .followUp:
            return "後で改めて連絡する旨の返信を作成してください。"
        case .custom(let instruction):
            return "次の要旨・指示に沿って返信を作成してください: \(instruction)"
        }
    }
}
