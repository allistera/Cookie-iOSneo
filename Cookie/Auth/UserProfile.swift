/// The signed-in user, read from the stored ID token.
struct UserProfile: Equatable, Sendable {
    let name: String
    let email: String?

    /// The letter shown on the account button.
    var initial: String {
        String(name.prefix(1)).uppercased()
    }
}
