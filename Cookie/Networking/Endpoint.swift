import Foundation

/// One HTTPS route on a Cookie Worker.
struct Endpoint: Equatable, Sendable {
    let host: String
    let path: String

    /// `nil` when the host and path cannot form a URL, for example a path
    /// without a leading slash.
    var url: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        return components.url
    }
}

/// Every production route the app calls. A contract test pins each one.
enum CookieAPIEndpoints {
    static let mailboxState = Endpoint(host: "emails-api.infinitywave.online", path: "/emails/state")
}
