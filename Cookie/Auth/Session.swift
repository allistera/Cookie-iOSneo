import Foundation
import Observation

enum SessionState: Equatable {
    case signedOut
    case signedIn(UserProfile)
}

/// Owns whether the user is signed in, and hands out access tokens.
@MainActor
@Observable
final class Session {
    private(set) var state: SessionState
    /// A message for the sign-in screen after a failed attempt.
    private(set) var signInError: String?

    private let source: any CredentialsSource

    /// Restores a stored session without a network call, so an offline launch
    /// still lands signed in. The first API call validates the token.
    init(source: any CredentialsSource) {
        self.source = source
        if source.hasStoredCredentials, let profile = source.storedProfile() {
            state = .signedIn(profile)
        } else {
            if source.hasStoredCredentials { source.clear() }
            state = .signedOut
        }
    }

    func signIn() async {
        signInError = nil
        do {
            try await source.signIn()
        } catch CredentialsFailure.cancelled {
            return
        } catch {
            signInError = String(localized: "Sign-in failed. Check your connection and try again.")
            return
        }
        guard let profile = source.storedProfile() else {
            signInError = String(localized: "Signed in, but your profile could not be read. Please try again.")
            return
        }
        state = .signedIn(profile)
    }

    /// Always signs out on this device, even if ending the browser session fails.
    func signOut() async {
        await source.endWebSession()
        signOutLocally()
    }

    func accessToken() async throws -> String {
        try await token { try await self.source.accessToken() }
    }

    func renewAccessToken() async throws -> String {
        try await token { try await self.source.renewedAccessToken() }
    }

    /// The API rejected a freshly renewed token, so the session is over.
    func invalidate() {
        signOutLocally()
    }

    private func token(_ fetch: () async throws -> String) async throws -> String {
        do {
            return try await fetch()
        } catch CredentialsFailure.signInRequired {
            signOutLocally()
            throw CredentialsFailure.signInRequired
        }
    }

    private func signOutLocally() {
        source.clear()
        signInError = nil
        state = .signedOut
    }
}
