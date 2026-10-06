import Foundation

/// One message of the conversation, as `GET /messages?id=` lists it in `thread`.
struct ThreadMessage: Decodable, Equatable, Sendable {
    let id: String
    let fromName: String?
    let fromAddress: String
    let snippet: String?
    let sentAt: Date
}

/// The part of `GET /messages?id=` the reader uses. Both bodies may be null.
struct MessageBody: Decodable, Equatable, Sendable {
    let id: String
    let subject: String?
    let bodyHtml: String?
    let bodyText: String?
    let thread: [ThreadMessage]

    private enum CodingKeys: String, CodingKey {
        case id, subject, bodyHtml, bodyText, thread
    }

    init(id: String, subject: String? = nil, bodyHtml: String?, bodyText: String?, thread: [ThreadMessage] = []) {
        self.id = id
        self.subject = subject
        self.bodyHtml = bodyHtml
        self.bodyText = bodyText
        self.thread = thread
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        subject = try container.decodeIfPresent(String.self, forKey: .subject)
        bodyHtml = try container.decodeIfPresent(String.self, forKey: .bodyHtml)
        bodyText = try container.decodeIfPresent(String.self, forKey: .bodyText)
        thread = try container.decodeIfPresent([ThreadMessage].self, forKey: .thread) ?? []
    }
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
