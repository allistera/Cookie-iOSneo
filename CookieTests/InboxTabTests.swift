import Foundation
import Testing

@testable import Cookie

struct InboxTabTests {
    private let finance = EmailCategory(id: "c1", name: "Finance", color: nil)
    private let personal = EmailCategory(id: "c2", name: "Personal", color: nil)
    private let important = EmailCategory(id: "c3", name: "Important", color: nil)

    private func email(_ id: String, priority: String? = nil, category: EmailCategory? = nil, unread: Bool = false)
        -> EmailSummary
    {
        EmailSummary(
            id: id, fromName: nil, fromAddress: "\(id)@example.com", subject: nil, snippet: nil,
            sentAt: Date(timeIntervalSince1970: 0), isUnread: unread, priority: priority, labels: [],
            category: category)
    }

    @Test func importantThenCategoriesInServerOrderThenOther() {
        let tabs = InboxTab.tabs(for: [], categories: [personal, finance])
        #expect(tabs.map(\.id) == ["important", "category:c2", "category:c1", "other"])
        #expect(tabs.map(\.name) == ["Important", "Personal", "Finance", "Other"])
        #expect(tabs.allSatisfy { $0.emails.isEmpty })
    }

    @Test func highPriorityWinsOverCategory() {
        let tabs = InboxTab.tabs(for: [email("a", priority: "high", category: finance)], categories: [finance])
        #expect(tabs[0].emails.map(\.id) == ["a"])
        #expect(tabs[1].emails.isEmpty)
    }

    @Test func categoryNamedImportantSharesTheImportantTab() {
        let tabs = InboxTab.tabs(for: [email("a", category: important)], categories: [important, finance])
        #expect(tabs.map(\.id) == ["important", "category:c1", "other"])
        #expect(tabs[0].emails.map(\.id) == ["a"])
    }

    @Test func unknownOrMissingCategoryGoesToOther() {
        let stale = EmailCategory(id: "gone", name: "Old", color: nil)
        let tabs = InboxTab.tabs(for: [email("a", category: stale), email("b")], categories: [finance])
        #expect(tabs.last?.emails.map(\.id) == ["a", "b"])
    }

    @Test func unreadCountCountsLoadedUnreadRows() {
        let rows = [
            email("a", category: finance, unread: true), email("b", category: finance),
            email("c", category: finance, unread: true),
        ]
        let tabs = InboxTab.tabs(for: rows, categories: [finance])
        #expect(tabs[1].unreadCount == 2)
        #expect(tabs[0].unreadCount == 0)
    }
}
