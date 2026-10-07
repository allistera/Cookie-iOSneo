import Foundation
import Observation

enum SessionState: Equatable {
    case signedOut
    case signedIn(UserProfile)
}

/// Stores the non-secret intent to finish signing out on a later launch.
@MainActor
protocol LogoutIntentStore: AnyObject {
    var hasPendingLogout: Bool { get set }
}

/// The production logout marker. It contains no credentials or provider data.
@MainActor
final class UserDefaultsLogoutIntentStore: LogoutIntentStore {
    private static let key = "com.cookie.ios.pendingLogout"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasPendingLogout: Bool {
        get { defaults.bool(forKey: Self.key) }
        set { defaults.set(newValue, forKey: Self.key) }
    }
}

/// Owns whether the user is signed in, and hands out access tokens.
@MainActor
@Observable
final class Session {
    private(set) var state: SessionState
    /// A message for the sign-in screen after a failed attempt.
    private(set) var signInError: String?
    /// A message shown when local credential deletion could not be completed.
    private(set) var signOutError: String?

    private let source: any CredentialsSource
    private let logoutIntentStore: any LogoutIntentStore
    private var generation: UInt64 = 0
    private var operationTail: Task<Void, Never>?

    /// The current authentication context. API requests use this to reject
    /// tokens and responses that belong to a previous session.
    var authGeneration: UInt64 { generation }

    /// Restores a stored session without a network call, so an offline launch
    /// still lands signed in. The first API call validates the token.
    init(
        source: any CredentialsSource,
        logoutIntentStore: any LogoutIntentStore = UserDefaultsLogoutIntentStore()
    ) {
        self.source = source
        self.logoutIntentStore = logoutIntentStore
        state = .signedOut
        signInError = nil
        signOutError = nil

        if logoutIntentStore.hasPendingLogout {
            clearStoredCredentialsDuringLaunch()
        } else if source.hasStoredCredentials, let profile = source.storedProfile() {
            state = .signedIn(profile)
        } else if source.hasStoredCredentials {
            logoutIntentStore.hasPendingLogout = true
            clearStoredCredentialsDuringLaunch()
        }
    }

    func signIn() async {
        let expectedGeneration = advanceGeneration()
        signInError = nil
        signOutError = nil

        do {
            try await enqueue { [source] in
                guard self.generation == expectedGeneration else { throw CancellationError() }
                try await source.signIn()
            }
        } catch is CancellationError {
            return
        } catch CredentialsFailure.cancelled {
            return
        } catch {
            guard generation == expectedGeneration else { return }
            signInError = String(localized: "Sign-in failed. Check your connection and try again.")
            return
        }

        guard generation == expectedGeneration else { return }
        guard let profile = source.storedProfile() else {
            signInError = String(localized: "Signed in, but your profile could not be read. Please try again.")
            logoutIntentStore.hasPendingLogout = true
            await clearStoredCredentials(for: expectedGeneration)
            return
        }
        guard generation == expectedGeneration else { return }

        logoutIntentStore.hasPendingLogout = false
        state = .signedIn(profile)
    }

    /// Local sign-out starts immediately. Credential deletion is serialized
    /// with SDK renewal before the browser session is ended best-effort.
    func signOut() async {
        let expectedGeneration = advanceGeneration()
        signInError = nil
        signOutError = nil
        logoutIntentStore.hasPendingLogout = true
        state = .signedOut

        await clearStoredCredentials(for: expectedGeneration)
        let source = self.source
        await enqueueCleanup {
            guard self.generation == expectedGeneration else { return }
            await source.endWebSession()
        }
    }

    func accessToken() async throws -> String {
        let expectedGeneration = generation
        return try await token(expectedGeneration: expectedGeneration) { [source] in
            try await self.enqueue {
                guard self.generation == expectedGeneration else { throw CancellationError() }
                return try await source.accessToken()
            }
        }
    }

    func renewAccessToken() async throws -> String {
        let expectedGeneration = generation
        return try await token(expectedGeneration: expectedGeneration) { [source] in
            try await self.enqueue {
                guard self.generation == expectedGeneration else { throw CancellationError() }
                return try await source.renewedAccessToken()
            }
        }
    }

    /// The API rejected a freshly renewed token, so the session is over.
    func invalidate() async {
        await invalidate(ifCurrentGeneration: generation)
    }

    /// Invalidates only the authentication context that produced a rejected
    /// response. A response from an older context cannot sign out a new user.
    func invalidate(ifCurrentGeneration expectedGeneration: UInt64) async {
        guard generation == expectedGeneration else { return }

        let invalidatedGeneration = advanceGeneration()
        signInError = nil
        signOutError = nil
        logoutIntentStore.hasPendingLogout = true
        state = .signedOut
        await clearStoredCredentials(for: invalidatedGeneration)
    }

    private func token(
        expectedGeneration: UInt64,
        fetch: @escaping @MainActor () async throws -> String
    ) async throws -> String {
        guard generation == expectedGeneration, case .signedIn = state else {
            throw CredentialsFailure.signInRequired
        }
        do {
            let value = try await fetch()
            guard generation == expectedGeneration, case .signedIn = state else {
                throw CancellationError()
            }
            return value
        } catch CredentialsFailure.signInRequired {
            guard generation == expectedGeneration else { throw CancellationError() }
            await invalidate(ifCurrentGeneration: expectedGeneration)
            throw CredentialsFailure.signInRequired
        }
    }

    private func clearStoredCredentialsDuringLaunch() {
        do {
            try source.clear()
            logoutIntentStore.hasPendingLogout = false
        } catch {
            signOutError = Self.signOutFailureMessage
            logoutIntentStore.hasPendingLogout = true
        }
    }

    private func clearStoredCredentials(for expectedGeneration: UInt64) async {
        do {
            try await enqueue { [source] in
                try source.clear()
            }
            guard generation == expectedGeneration else { return }
            logoutIntentStore.hasPendingLogout = false
        } catch {
            guard generation == expectedGeneration else { return }
            logoutIntentStore.hasPendingLogout = true
            signOutError = Self.signOutFailureMessage
        }
    }

    private func advanceGeneration() -> UInt64 {
        generation &+= 1
        return generation
    }

    private func enqueue<T: Sendable>(
        _ operation: @escaping @MainActor () async throws -> T
    ) async throws -> T {
        let previous = operationTail
        let task = Task { @MainActor in
            await previous?.value
            try Task.checkCancellation()
            let value = try await operation()
            try Task.checkCancellation()
            return value
        }
        operationTail = Task { @MainActor in
            _ = await task.result
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func enqueueCleanup(_ operation: @escaping @MainActor () async -> Void) async {
        let previous = operationTail
        let task = Task { @MainActor in
            await previous?.value
            await operation()
        }
        operationTail = Task { @MainActor in
            await task.value
        }
        await task.value
    }

    private static let signOutFailureMessage = String(
        localized: "Could not finish signing out. Please try again."
    )
}
