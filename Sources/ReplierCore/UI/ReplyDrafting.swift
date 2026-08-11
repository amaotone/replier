public protocol ReplyDrafting: Sendable {
    func draft(_ request: ReplyRequest) async throws -> AsyncThrowingStream<String, Error>

    /// Best-effort warm-up of any underlying connection, ahead of the first `draft` call.
    func prewarm() async
}

extension ReplyDrafting {
    public func prewarm() async {}
}
