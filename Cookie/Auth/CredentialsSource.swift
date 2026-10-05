/// Why a credentials operation failed, independent of the identity provider.
enum CredentialsFailure: Error, Equatable {
    /// The user dismissed the login screen.
    case cancelled
    /// The stored session is unusable; the user must sign in again.
    case signInRequired
    /// A network, provider or keychain problem that may succeed later.
    case transient
}

/// The identity provider and credential store behind `Session`.
/// Throwing members throw `CredentialsFailure`.
@MainActor
protocol CredentialsSource: AnyObject {
    /// Whether credentials are stored that are valid or can be renewed.
    var hasStoredCredentials: Bool { get }
    /// The user from the stored ID token, read without a network call.
    func storedProfile() -> UserProfile?
    /// Presents the web login and stores the resulting credentials.
    func signIn() async throws
    /// A valid access token, renewed first if it has expired.
    func accessToken() async throws -> String
    /// An access token from a forced renewal.
    func renewedAccessToken() async throws -> String
    /// Removes stored credentials from this device.
    func clear()
    /// Ends the provider's browser session. Best effort.
    func endWebSession() async
}
