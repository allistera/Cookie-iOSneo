/// How `APIClient` obtains access tokens and reports a rejected session.
struct TokenProvider: Sendable {
    /// A token believed valid, renewed first if it has expired.
    let current: @Sendable () async throws -> String
    /// A token from a forced renewal, used after the server answers 401.
    let renewed: @Sendable () async throws -> String
    /// Called when the server rejects a freshly renewed token.
    let invalidate: @Sendable () async -> Void
}

extension TokenProvider {
    init(session: Session) {
        self.init(
            current: { try await session.accessToken() },
            renewed: { try await session.renewAccessToken() },
            invalidate: { await session.invalidate() }
        )
    }
}
