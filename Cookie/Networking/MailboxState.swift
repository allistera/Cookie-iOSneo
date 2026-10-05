/// The part of `GET /emails/state` this app reads.
struct MailboxState: Decodable, Equatable, Sendable {
    let unreadCount: Int
}
