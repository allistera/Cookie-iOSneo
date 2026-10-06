import Foundation

/// A saved draft from `GET /drafts`. Keys are camelCase on the wire.
struct Draft: Decodable, Hashable, Identifiable, Sendable {
    let id: String
    let recipients: String?
    let subject: String?
    let preview: String?
    let updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id, subject, preview, updatedAt
        case recipients = "to"
    }
}

struct DraftList: Decodable, Equatable, Sendable {
    let drafts: [Draft]
}
