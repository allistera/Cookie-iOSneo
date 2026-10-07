/// How `APIClient` obtains access tokens and reports a rejected session.
struct TokenProvider: Sendable {
    /// A token believed valid, renewed first if it has expired.
    let current: @Sendable () async throws -> String
    /// A token from a forced renewal, used after the server answers 401.
    let renewed: @Sendable () async throws -> String
    /// The authentication context associated with a request.
    let generation: @Sendable () async -> UInt64
    /// Invalidates only the context that produced a rejected response.
    let invalidateIfCurrent: @Sendable (UInt64) async -> Void

    init(
        current: @escaping @Sendable () async throws -> String,
        renewed: @escaping @Sendable () async throws -> String,
        invalidate: @escaping @Sendable () async -> Void,
        generation: @escaping @Sendable () async -> UInt64 = { 0 },
        invalidateIfCurrent: (@Sendable (UInt64) async -> Void)? = nil
    ) {
        self.current = current
        self.renewed = renewed
        self.generation = generation
        self.invalidateIfCurrent = invalidateIfCurrent ?? { _ in await invalidate() }
    }
}

extension TokenProvider {
    init(session: Session) {
        self.init(
            current: { try await session.accessToken() },
            renewed: { try await session.renewAccessToken() },
            invalidate: { await session.invalidate() },
            generation: { await session.authGeneration },
            invalidateIfCurrent: { generation in
                await session.invalidate(ifCurrentGeneration: generation)
            }
        )
    }
}
