import Foundation

/// One HTTPS route on a Cookie Worker.
struct Endpoint: Equatable, Sendable {
    let host: String
    let path: String
    var queryItems: [URLQueryItem] = []

    /// `nil` when the host and path cannot form a URL, for example a path
    /// without a leading slash.
    var url: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url
    }
}

/// Every production route the app calls. A contract test pins each one.
enum CookieAPIEndpoints {
    static let categories = Endpoint(host: "labels-api.infinitywave.online", path: "/categories")

    /// The inbox, newest first. `cursor` is the previous page's `nextCursor`.
    static func inbox(before cursor: String?, limit: Int = 50) -> Endpoint {
        var items = [URLQueryItem(name: "folder", value: "inbox"), URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            items.append(URLQueryItem(name: "before", value: cursor))
        }
        return Endpoint(host: "emails-api.infinitywave.online", path: "/emails", queryItems: items)
    }
}
