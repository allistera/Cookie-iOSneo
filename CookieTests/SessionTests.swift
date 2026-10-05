import Testing

@testable import Cookie

@MainActor
private final class FakeCredentialsSource: CredentialsSource {
    var hasStoredCredentials = false
    var profile: UserProfile?
    /// The profile that becomes stored when `signIn()` succeeds.
    var profileAfterSignIn: UserProfile?
    var signInFailure: CredentialsFailure?
    var tokenFailure: CredentialsFailure?
    private(set) var clearCount = 0
    private(set) var endWebSessionCount = 0

    func storedProfile() -> UserProfile? { profile }

    func signIn() async throws {
        if let signInFailure { throw signInFailure }
        hasStoredCredentials = true
        profile = profileAfterSignIn
    }

    func accessToken() async throws -> String {
        if let tokenFailure { throw tokenFailure }
        return "access-token"
    }

    func renewedAccessToken() async throws -> String {
        if let tokenFailure { throw tokenFailure }
        return "renewed-token"
    }

    func clear() {
        clearCount += 1
        hasStoredCredentials = false
        profile = nil
    }

    func endWebSession() async { endWebSessionCount += 1 }
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

    @Test func startsSignedOutWithoutStoredCredentials() {
        let session = Session(source: FakeCredentialsSource())
        #expect(session.state == .signedOut)
    }

    @Test func startsSignedInFromStoredCredentials() {
        let session = Session(source: signedInSource())
        #expect(session.state == .signedIn(allister))
    }

    @Test func storedCredentialsWithoutReadableProfileAreCleared() {
        let source = FakeCredentialsSource()
        source.hasStoredCredentials = true

        let session = Session(source: source)

        #expect(session.state == .signedOut)
        #expect(source.clearCount == 1)
    }

    @Test func signInSuccessSignsIn() async {
        let source = FakeCredentialsSource()
        source.profileAfterSignIn = allister
        let session = Session(source: source)

        await session.signIn()

        #expect(session.state == .signedIn(allister))
        #expect(session.signInError == nil)
    }

    @Test func cancelledSignInShowsNoError() async {
        let source = FakeCredentialsSource()
        source.signInFailure = .cancelled
        let session = Session(source: source)

        await session.signIn()

        #expect(session.state == .signedOut)
        #expect(session.signInError == nil)
    }

    @Test func failedSignInShowsErrorAndStaysSignedOut() async {
        let source = FakeCredentialsSource()
        source.signInFailure = .transient
        let session = Session(source: source)

        await session.signIn()

        #expect(session.state == .signedOut)
        #expect(session.signInError != nil)
    }

    @Test func retryingSignInClearsThePreviousError() async {
        let source = FakeCredentialsSource()
        source.signInFailure = .transient
        let session = Session(source: source)
        await session.signIn()

        source.signInFailure = nil
        source.profileAfterSignIn = allister
        await session.signIn()

        #expect(session.signInError == nil)
        #expect(session.state == .signedIn(allister))
    }

    @Test func signOutClearsCredentialsAndWebSession() async {
        let source = signedInSource()
        let session = Session(source: source)

        await session.signOut()

        #expect(session.state == .signedOut)
        #expect(source.clearCount == 1)
        #expect(source.endWebSessionCount == 1)
    }

    @Test func accessTokenComesFromTheSource() async throws {
        let session = Session(source: signedInSource())
        #expect(try await session.accessToken() == "access-token")
        #expect(try await session.renewAccessToken() == "renewed-token")
    }

    @Test func tokenFailureRequiringSignInSignsOut() async {
        let source = signedInSource()
        source.tokenFailure = .signInRequired
        let session = Session(source: source)

        await #expect(throws: CredentialsFailure.signInRequired) {
            _ = try await session.accessToken()
        }
        #expect(session.state == .signedOut)
        #expect(source.clearCount == 1)
    }

    @Test func transientTokenFailureKeepsTheSession() async {
        let source = signedInSource()
        source.tokenFailure = .transient
        let session = Session(source: source)

        await #expect(throws: CredentialsFailure.transient) {
            _ = try await session.renewAccessToken()
        }
        #expect(session.state == .signedIn(allister))
        #expect(source.clearCount == 0)
    }

    @Test func invalidateSignsOutWithoutTouchingTheWebSession() {
        let source = signedInSource()
        let session = Session(source: source)

        session.invalidate()

        #expect(session.state == .signedOut)
        #expect(source.clearCount == 1)
        #expect(source.endWebSessionCount == 0)
    }
}
