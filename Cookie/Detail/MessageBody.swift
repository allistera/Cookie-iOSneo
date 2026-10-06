/// The part of `GET /messages?id=` the reader shows. Both bodies may be null.
struct MessageBody: Decodable, Equatable, Sendable {
    let id: String
    let bodyHtml: String?
    let bodyText: String?
}

/// `PATCH /messages` body; encoded with snake_case keys.
struct MarkReadRequest: Encodable, Equatable, Sendable {
    let id: String
    let isUnread: Bool
}

/// `POST /send` body. The send Worker reads camelCase keys, so encode this
/// with a plain `JSONEncoder`.
struct SendRequest: Encodable, Equatable, Sendable {
    let recipient: String
    let subject: String
    let text: String
    let replyToMessageId: String
    let requestId: String

    private enum CodingKeys: String, CodingKey {
        case recipient = "to"
        case subject, text, replyToMessageId, requestId
    }
}
