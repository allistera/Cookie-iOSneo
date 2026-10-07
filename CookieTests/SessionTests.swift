import Testing

@testable import Cookie

@MainActor
private final class InMemoryLogoutIntentStore: LogoutIntentStore {
    var hasPendingLogout = false
}

@MainActor
private final class FakeCredentialsSource: CredentialsSource {
    var hasStoredCredentials = false
    var profile: UserProfile?
    /// The profile that becomes stored when `signIn()` succeeds.
    var profileAfterSignIn: UserProfile?
    var signInFailure: CredentialsFailure?
    var tokenFailure: CredentialsFailure?
    var clearFailure = false
    private(set) var clearCount = 0
    private(set) var accessTokenCount = 0
    private(set) var endWebSessionCount = 0
    var endWebSessionHook: (() -> Void)?

    func storedProfile() -> UserProfile? { profile }

    func signIn() async throws {
        if let signInFailure { throw signInFailure }
        hasStoredCredentials = true
        profile = profileAfterSignIn
    }

    func accessToken() async throws -> String {
        accessTokenCount += 1
        if let tokenFailure { throw tokenFailure }
        return "access-token"
    }

    func renewedAccessToken() async throws -> String {
        if let tokenFailure { throw tokenFailure }
        return "renewed-token"
    }

    func clear() throws {
        clearCount += 1
        if clearFailure { throw CredentialsFailure.transient }
        hasStoredCredentials = false
        profile = nil
    }

    func endWebSession() async {
        endWebSessionCount += 1
        endWebSessionHook?()
    }
}

@MainActor
struct SessionTests {
    private let allister = UserProfile(name: "Allister", email: "allister@example.com")

    private func signedInSource() -> FakeCredentialsSource {
        let source = FakeCredentialsSource()
        source.hasStoredCredentials = true
        source.profile = allister
        return source
    }

    private func makeSession(_ source: FakeCredentialsSource) -> Session {
        Session(source: source, logoutIntentStore: InMemoryLogoutIntentStore())
    }

    @Test func startsSignedOutWithoutStoredCredentials() {
        let session = makeSession(FakeCredentialsSource())
        #expect(session.state == .signedOut)
    }

    @Test func startsSignedInFromStoredCredentials() {
        let session = makeSession(signedInSource())
        #expect(session.state == .signedIn(allister))
    }

    @Test func storedCredentialsWithoutReadableProfileAreCleared() {
        let source = FakeCredentialsSource()
        source.hasStoredCredentials = true

        let session = makeSession(source)

        #expect(session.state == .signedOut)
        #expect(source.clearCount == 1)
    }

    @Test func signInSuccessSignsIn() async {
        let source = FakeCredentialsSource()
        source.profileAfterSignIn = allister
        let session = makeSession(source)

        await session.signIn()

        #expect(session.state == .signedIn(allister))
        #expect(session.signInError == nil)
    }

    @Test func cancelledSignInShowsNoError() async {
        let source = FakeCredentialsSource()
        source.signInFailure = .cancelled
        let session = makeSession(source)

        await session.signIn()

        #expect(session.state == .signedOut)
        #expect(session.signInError == nil)
    }

    @Test func failedSignInShowsErrorAndStaysSignedOut() async {
        let source = FakeCredentialsSource()
        source.signInFailure = .transient
        let session = makeSession(source)

        await session.signIn()

        #expect(session.state == .signedOut)
        #expect(session.signInError != nil)
    }

    @Test func retryingSignInClearsThePreviousError() async {
        let source = FakeCredentialsSource()
        source.signInFailure = .transient
        let session = makeSession(source)
        await session.signIn()

        source.signInFailure = nil
        source.profileAfterSignIn = allister
        await session.signIn()

        #expect(session.signInError == nil)
        #expect(session.state == .signedIn(allister))
    }

    @Test func signOutClearsCredentialsAndWebSession() async {
        let source = signedInSource()
        let session = makeSession(source)
        source.endWebSessionHook = { #expect(session.state == .signedOut) }

        await session.signOut()

        #expect(session.state == .signedOut)
        #expect(source.clearCount == 1)
        #expect(source.endWebSessionCount == 1)
    }

    @Test func failedCredentialDeletionStaysSignedOutAndLeavesIntentMarker() async {
        let source = signedInSource()
        source.clearFailure = true
        let store = InMemoryLogoutIntentStore()
        let session = Session(source: source, logoutIntentStore: store)

        await session.signOut()

        #expect(session.state == .signedOut)
        #expect(session.signOutError != nil)
        #expect(store.hasPendingLogout)

        let relaunched = Session(source: source, logoutIntentStore: store)
        #expect(relaunched.state == .signedOut)
        #expect(relaunched.signOutError != nil)
        #expect(store.hasPendingLogout)

        source.clearFailure = false
        let recovered = Session(source: source, logoutIntentStore: store)
        #expect(recovered.state == .signedOut)
        #expect(recovered.signOutError == nil)
        #expect(!store.hasPendingLogout)
    }

    @Test func tokenRequestWhileSignedOutDoesNotUseRetainedCredentials() async {
        let source = signedInSource()
        source.clearFailure = true
        let session = makeSession(source)

        await session.signOut()

        await #expect(throws: CredentialsFailure.signInRequired) {
            _ = try await session.accessToken()
        }
        #expect(session.state == .signedOut)
        #expect(source.accessTokenCount == 0)
    }

    @Test func accessTokenComesFromTheSource() async throws {
        let session = makeSession(signedInSource())
        #expect(try await session.accessToken() == "access-token")
        #expect(try await session.renewAccessToken() == "renewed-token")
    }

    @Test func tokenFailureRequiringSignInSignsOut() async {
        let source = signedInSource()
        source.tokenFailure = .signInRequired
        let session = makeSession(source)

        await #expect(throws: CredentialsFailure.signInRequired) {
            _ = try await session.accessToken()
        }
        #expect(session.state == .signedOut)
        #expect(source.clearCount == 1)
    }

    @Test func transientTokenFailureKeepsTheSession() async {
        let source = signedInSource()
        source.tokenFailure = .transient
        let session = makeSession(source)

        await #expect(throws: CredentialsFailure.transient) {
            _ = try await session.renewAccessToken()
        }
        #expect(session.state == .signedIn(allister))
        #expect(source.clearCount == 0)
    }

    @Test func invalidateSignsOutWithoutTouchingTheWebSession() async {
        let source = signedInSource()
        let session = makeSession(source)

        await session.invalidate()

        #expect(session.state == .signedOut)
        #expect(source.clearCount == 1)
        #expect(source.endWebSessionCount == 0)
    }
}
