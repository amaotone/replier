public protocol ReplyDrafting: Sendable {
    func draft(_ request: ReplyRequest) async throws -> AsyncThrowingStream<String, Error>
}
