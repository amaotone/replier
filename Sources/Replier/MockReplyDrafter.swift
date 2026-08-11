import Foundation
import ReplierCore

/// Yields a canned sentinel-delimited response in chunks so the panel UI is demo-able
/// before real Codex wiring lands. The chunking deliberately splits the `<<<long>>>`
/// sentinel across two chunks to regression-proof the incremental parser's line buffering.
struct MockReplyDrafter: ReplyDrafting {
    private static let cannedText = """
    <<<short>>>
    了解です、対応します。
    <<<long>>>
    ご連絡ありがとうございます。承知しました、内容を確認の上で対応いたします。何かご不明な点がございましたら、改めてご連絡いたします。
    """

    func draft(_ request: ReplyRequest) async throws -> AsyncThrowingStream<String, Error> {
        let chunks = Self.chunks(for: Self.cannedText)

        return AsyncThrowingStream { continuation in
            Task {
                for chunk in chunks {
                    continuation.yield(chunk)
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                continuation.finish()
            }
        }
    }

    /// Splits `text` into small demo chunks, forcing a break in the middle of
    /// `<<<long>>>` (after "<<<lon") so the parser must reassemble a sentinel that
    /// arrives split across two deltas.
    private static func chunks(for text: String) -> [String] {
        guard let sentinelRange = text.range(of: "<<<long>>>") else {
            return evenChunks(text, count: 10)
        }
        let splitPoint = text.index(sentinelRange.lowerBound, offsetBy: 6)
        let before = String(text[text.startIndex..<splitPoint])
        let after = String(text[splitPoint...])
        return evenChunks(before, count: 6) + evenChunks(after, count: 6)
    }

    private static func evenChunks(_ text: String, count: Int) -> [String] {
        guard !text.isEmpty else { return [] }
        let chunkSize = max(1, Int(ceil(Double(text.count) / Double(count))))
        var chunks: [String] = []
        var current = text.startIndex
        while current < text.endIndex {
            let next = text.index(current, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            chunks.append(String(text[current..<next]))
            current = next
        }
        return chunks
    }
}
