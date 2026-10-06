import Foundation

/// One category page of the inbox. The rule mirrors Cookie-Web's
/// TraditionalInboxView: Important first, then every category in server
/// order, then Other; each email appears in exactly one tab.
struct InboxTab: Identifiable, Equatable {
    static let importantID = "important"
    static let otherID = "other"

    let id: String
    let name: String
    let isImportant: Bool
    let emails: [EmailSummary]

    var unreadCount: Int {
        emails.count(where: \.isUnread)
    }

    static func tabs(for emails: [EmailSummary], categories: [EmailCategory]) -> [InboxTab] {
        let categoryTabs = categories.filter { !$0.isImportant }
        let knownIDs = Set(categoryTabs.map(\.id))

        var important: [EmailSummary] = []
        var other: [EmailSummary] = []
        var byCategory: [String: [EmailSummary]] = [:]
        for email in emails {
            if email.isImportant {
                important.append(email)
            } else if let categoryID = email.category?.id, knownIDs.contains(categoryID) {
                byCategory[categoryID, default: []].append(email)
            } else {
                other.append(email)
            }
        }

        return [InboxTab(id: importantID, name: String(localized: "Important"), isImportant: true, emails: important)]
            + categoryTabs.map {
                InboxTab(id: "category:\($0.id)", name: $0.name, isImportant: false, emails: byCategory[$0.id] ?? [])
            }
            + [InboxTab(id: otherID, name: String(localized: "Other"), isImportant: false, emails: other)]
    }
}
