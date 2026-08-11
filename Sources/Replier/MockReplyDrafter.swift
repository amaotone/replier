import Foundation
import ReplierCore

/// Yields a canned 3-candidate JSON response in chunks so the panel UI is demo-able
/// before real Codex wiring lands.
struct MockReplyDrafter: ReplyDrafting {
    private static let cannedJSON = """
    {"candidates":[\
    {"label":"short","text":"了解です、対応します。"},\
    {"label":"standard","text":"ご連絡ありがとうございます。承知しました、対応いたします。"},\
    {"label":"polite","text":"ご連絡いただきありがとうございます。内容を確認いたしました。ご期待に沿えるよう対応いたします。"}\
    ]}
    """

    func draft(_ request: ReplyRequest) async throws -> AsyncThrowingStream<String, Error> {
        let text = Self.cannedJSON
        let chunkCount = 10
        let chunkSize = max(1, Int(ceil(Double(text.count) / Double(chunkCount))))

        return AsyncThrowingStream { continuation in
            Task {
                var current = text.startIndex
                while current < text.endIndex {
                    let next = text.index(current, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
                    continuation.yield(String(text[current..<next]))
                    current = next
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                continuation.finish()
            }
        }
    }
}
