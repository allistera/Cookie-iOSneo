import Testing

@testable import Cookie

@MainActor
private final class CredentialGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var isWaiting = false

    func wait() async {
        isWaiting = true
        await withCheckedContinuation { continuation = $0 }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class ConcurrentCredentialsSource: CredentialsSource {
    var hasStoredCredentials = true
    let renewalGate = CredentialGate()
    let logoutGate = CredentialGate()
    var waitsForBrowserLogout = false
    private(set) var clearCount = 0

    func storedProfile() -> UserProfile? {
        hasStoredCredentials ? UserProfile(name: "Fixture", email: "fixture@example.com") : nil
    }

    func signIn() async throws { hasStoredCredentials = true }
    func accessToken() async throws -> String { "fixture-token" }

    func renewedAccessToken() async throws -> String {
        await renewalGate.wait()
        // Models the SDK persisting renewed credentials before returning to Session.
        hasStoredCredentials = true
        return "renewed-fixture-token"
    }

    func clear() {
        clearCount += 1
        hasStoredCredentials = false
    }

    func endWebSession() async {
        if waitsForBrowserLogout { await logoutGate.wait() }
    }
}

@MainActor
private final class ConcurrentLogoutIntentStore: LogoutIntentStore {
    var hasPendingLogout = false
}

@MainActor
struct SessionConcurrencyTests {
    @Test func logoutFinishesCredentialDeletionAfterAnInFlightRenewal() async {
        let source = ConcurrentCredentialsSource()
        let intent = ConcurrentLogoutIntentStore()
        let session = Session(source: source, logoutIntentStore: intent)
        let renewal = Task { try await session.renewAccessToken() }
        while !source.renewalGate.isWaiting { await Task.yield() }

        let logout = Task { await session.signOut() }
        while session.state != .signedOut { await Task.yield() }
        #expect(intent.hasPendingLogout)
        await #expect(throws: CredentialsFailure.signInRequired) { try await session.accessToken() }

        source.renewalGate.release()
        await #expect(throws: CancellationError.self) { try await renewal.value }
        await logout.value

        #expect(session.state == .signedOut)
        #expect(!source.hasStoredCredentials)
        #expect(source.clearCount == 1)
        #expect(!intent.hasPendingLogout)
    }

    @Test func browserLogoutCannotDelayLocalCredentialRemoval() async {
        let source = ConcurrentCredentialsSource()
        source.waitsForBrowserLogout = true
        let session = Session(source: source, logoutIntentStore: ConcurrentLogoutIntentStore())
        let logout = Task { await session.signOut() }
        while !source.logoutGate.isWaiting { await Task.yield() }

        #expect(session.state == .signedOut)
        #expect(!source.hasStoredCredentials)
        await #expect(throws: CredentialsFailure.signInRequired) { try await session.accessToken() }

        source.logoutGate.release()
        await logout.value
    }
}
