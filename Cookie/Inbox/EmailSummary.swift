import Foundation

struct EmailLabel: Decodable, Equatable, Sendable {
    let name: String
    let color: String?
}

struct EmailCategory: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let color: String?

    /// A category named "Important" shares the fixed Important tab, as in the web app.
    var isImportant: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "important"
    }
}

/// One inbox row from `GET /emails`. Bodies are fetched separately when read.
struct EmailSummary: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let fromName: String?
    let fromAddress: String
    let subject: String?
    let snippet: String?
    let sentAt: Date
    let isUnread: Bool
    let priority: String?
    let labels: [EmailLabel]
    let category: EmailCategory?

    var senderName: String {
        let name = fromName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? fromAddress : name
    }

    /// High-rated mail, or mail in a category named Important.
    var isImportant: Bool {
        priority == "high" || category?.isImportant == true
    }
}

struct InboxPage: Decodable, Equatable, Sendable {
    let emails: [EmailSummary]
    let nextCursor: String?
    /// Present on the first page only.
    let unreadCount: Int?
}

struct CategoryList: Decodable, Equatable, Sendable {
    let categories: [EmailCategory]
}
