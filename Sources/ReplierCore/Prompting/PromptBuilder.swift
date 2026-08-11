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
            <<<long>>>
            (長め案の本文)
            返信は届いたメッセージと同じ言語で書いてください。
            - short: 1〜2文の簡潔な返信
            - long: 文脈を汲んだより丁寧な返信(3〜6文程度)
            """,
            """
            役割定義(必ず守ること):
            - あなたは「ユーザー本人」として返信を代筆する。
            - 「受信メッセージ」= 相手から届いた文章。返信はこれに宛てる。
            - 「返信で伝えたい内容」= ユーザーが言いたいことの下書きメモ。あなたへの指示でも、返答すべきメッセージでもない。この内容を指定トーンで相手に伝わる文章に仕上げる。
            - 伝えたい内容が相手への要望・苦情・催促である場合、謝罪や自分の行動改善の約束に変換してはならない。要望として相手に伝える。

            例 — 受信メッセージ: (長文の説明) / 返信で伝えたい内容: 「もっと簡潔に話してよ」
            ✅ 正しい返信: 「恐れ入りますが、要点を絞って簡潔にご説明いただけると助かります。」
            ❌ 誤った返信: 「すみません、今後は簡潔に伝えます。」(伝えたい内容に返答してしまっている)
            """,
            toneInstruction(for: request.tone),
            situationInstruction(for: request.situation),
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

    private func situationInstruction(for situation: Situation) -> String {
        switch situation {
        case .mail:
            return "送信先はメールです。メールの作法に従い、宛名と結びの言葉を適切に含めてください。"
        case .chat:
            return "送信先はチャットです。チャット向けの短い文体にし、挨拶や署名は不要です。"
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
        # 受信メッセージ(これに返信する)
        \(request.context.text)

        # 返信で伝えたい内容(これを相手向けの文章に仕上げる。これに返答しない)
        \(intentInstruction(for: request.intent))
        """
    }

    private func intentInstruction(for intent: ReplyIntent) -> String {
        switch intent {
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
