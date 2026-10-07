import Auth0
import OSLog
import SimpleKeychain

/// `CredentialsSource` backed by Auth0 and its Keychain credentials manager.
/// Client ID and domain come from `Auth0.plist`.
@MainActor
final class Auth0CredentialsSource: CredentialsSource {
    /// Must match the audience the Cookie Workers verify, so Auth0 issues a
    /// signed JWT access token rather than an opaque one.
    private static let audience = "https://cookie-web/api"
    private static let scope = "openid profile email offline_access"
    private static let logger = Logger(subsystem: "com.cookie.ios", category: "auth")

    private let manager = CredentialsManager(authentication: Auth0.authentication())

    var hasStoredCredentials: Bool {
        manager.canRenew() || manager.hasValid()
    }

    func storedProfile() -> UserProfile? {
        do {
            guard let user = try manager.userProfile() else { return nil }
            return UserProfile(name: user.name ?? user.nickname ?? user.email ?? "", email: user.email)
        } catch {
            Self.logger.error("Stored profile unreadable: \(String(describing: type(of: error)), privacy: .public)")
            return nil
        }
    }

    func signIn() async throws {
        do {
            _ = try await Auth0.webAuth()
                .scope(Self.scope)
                .audience(Self.audience)
                .useCredentialsManager(manager)
                .start()
        } catch WebAuthError.userCancelled {
            throw CredentialsFailure.cancelled
        } catch {
            Self.logger.error("Sign-in failed: \(String(describing: type(of: error)), privacy: .public)")
            throw CredentialsFailure.transient
        }
    }

    func accessToken() async throws -> String {
        do {
            return try await manager.credentials().accessToken
        } catch {
            throw Self.failure(for: error)
        }
    }

    func renewedAccessToken() async throws -> String {
        do {
            return try await manager.renew().accessToken
        } catch {
            throw Self.failure(for: error)
        }
    }

    func clear() throws {
        do {
            try manager.clear()
        } catch let error as SimpleKeychainError where error == .itemNotFound {
            // Deleting an already absent entry is an idempotent success.
            return
        } catch {
            Self.logger.error("Clearing credentials failed: \(String(describing: type(of: error)), privacy: .public)")
            throw error
        }
    }

    func endWebSession() async {
        do {
            try await Auth0.webAuth().logout()
        } catch {
            // Best effort: the user may cancel the sheet. Local sign-out still happens.
            Self.logger.info("Web session not cleared: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    /// Only a missing session or a rejected refresh token ends the session.
    /// Network, rate-limit, Auth0 5xx and other keychain failures are transient.
    private static func failure(for error: Error) -> CredentialsFailure {
        guard let error = error as? CredentialsManagerError else { return .transient }
        switch error {
        case .noCredentials, .noRefreshToken, .sessionExpired:
            return .signInRequired
        case .renewFailed, .storeFailed:
            return causeEndsSession(error.cause) ? .signInRequired : .transient
        default:
            return .transient
        }
    }

    private static func causeEndsSession(_ cause: Error?) -> Bool {
        switch cause {
        case let cause as AuthenticationError:
            return (400..<500).contains(cause.statusCode) && cause.statusCode != 429
        case let cause as SimpleKeychainError:
            return cause == .itemNotFound
        default:
            return false
        }
    }
}
