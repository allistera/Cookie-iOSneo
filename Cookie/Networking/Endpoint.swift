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
    static let messages = Endpoint(host: "messages-api.infinitywave.online", path: "/messages")
    static let send = Endpoint(host: "send-api.infinitywave.online", path: "/send")

    /// One message's body. Calendar-invite parsing is deferred: the reader does not show invites.
    static func message(id: String) -> Endpoint {
        Endpoint(
            host: "messages-api.infinitywave.online", path: "/messages",
            queryItems: [URLQueryItem(name: "id", value: id), URLQueryItem(name: "calendar", value: "deferred")])
    }

    static let labels = Endpoint(host: "labels-api.infinitywave.online", path: "/labels")
    static let drafts = Endpoint(host: "drafts-api.infinitywave.online", path: "/drafts")
    static let tasks = Endpoint(host: "tasks-api.infinitywave.online", path: "/tasks")
    static let tasksRefresh = Endpoint(host: "tasks-api.infinitywave.online", path: "/tasks/refresh")

    /// One folder's rows, newest first. `cursor` is the previous page's `nextCursor`.
    static func mailbox(folder: MailboxFolder, before cursor: String?, limit: Int = 50) -> Endpoint {
        var items = folder.queryItems + [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            items.append(URLQueryItem(name: "before", value: cursor))
        }
        return Endpoint(host: "emails-api.infinitywave.online", path: "/emails", queryItems: items)
    }
}
