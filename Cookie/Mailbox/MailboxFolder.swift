import Foundation

/// A folder of `GET /emails`. The sidebar's Views map onto these.
enum MailboxFolder: Hashable, Sendable {
    case inbox
    /// Mail from senders awaiting screening ("New senders").
    case screening
    case done
    case sent
    case spam
    case blocked
    case label(String)

    var title: String {
        switch self {
        case .inbox: String(localized: "Inbox")
        case .screening: String(localized: "New senders")
        case .done: String(localized: "Done")
        case .sent: String(localized: "Sent")
        case .spam: String(localized: "Spam")
        case .blocked: String(localized: "Blocked")
        case .label(let name): name
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .inbox: [URLQueryItem(name: "folder", value: "inbox")]
        case .screening: [URLQueryItem(name: "folder", value: "screening")]
        case .done: [URLQueryItem(name: "folder", value: "done")]
        case .sent: [URLQueryItem(name: "folder", value: "sent")]
        case .spam: [URLQueryItem(name: "folder", value: "spam")]
        case .blocked: [URLQueryItem(name: "folder", value: "blocked")]
        case .label(let name): [URLQueryItem(name: "folder", value: "label"), URLQueryItem(name: "label", value: name)]
        }
    }
}
