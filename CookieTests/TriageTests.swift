import Foundation
import Testing

@testable import Cookie

struct TriageTests {
    static let recorded = """
        {"tasks":[],"digest":{"overview":"Two things need a reply today.","created_at":"2026-10-06T08:00:00.000Z",
        "topics":[{"emoji":"✉️","title":"Reply Needed","items":[{"message_id":"6f1c","headline":"Jordan needs sign-off",
        "note":"By Thursday.","unread":true}]},{"emoji":"👀","title":"Review","items":[]}],
        "noise":{"count":17,"categories":[{"category":"Newsletters","count":12},{"category":"Promotions","count":5}]}},
        "news":null}
        """

    @Test func decodesRecordedDigest() throws {
        let response = try JSONDecoder.cookieAPI().decode(TodayResponse.self, from: Data(Self.recorded.utf8))
        let digest = try #require(response.digest)
        #expect(digest.overview == "Two things need a reply today.")
        #expect(digest.createdAt == Date(timeIntervalSince1970: 1_791_273_600))
        #expect(digest.topics.map(\.title) == ["Reply Needed", "Review"])
        #expect(digest.topics.first?.items.first?.id == "6f1c")
        #expect(digest.topics.first?.items.first?.unread == true)
        #expect(digest.noise.count == 17)
        #expect(digest.noise.categories.map(\.category) == ["Newsletters", "Promotions"])
    }

    @Test func nullDigestDecodesToNil() throws {
        let response = try JSONDecoder.cookieAPI().decode(
            TodayResponse.self, from: Data(#"{"tasks":[],"digest":null,"news":null}"#.utf8))
        #expect(response.digest == nil)
    }

    @Test func buildsSummaryFromThreadRow() {
        let row = ThreadMessage(
            id: "6f1c", fromName: "Jordan Blake", fromAddress: "jordan@example.com", snippet: "Hi",
            sentAt: Date(timeIntervalSince1970: 1_791_193_692))
        let body = MessageBody(id: "6f1c", subject: "Final terms", bodyHtml: nil, bodyText: nil, thread: [row])
        let summary = EmailReference.summary(for: "6f1c", unread: true, from: body)
        #expect(summary?.senderName == "Jordan Blake")
        #expect(summary?.subject == "Final terms")
        #expect(summary?.isUnread == true)
        #expect(EmailReference.summary(for: "other", unread: false, from: body) == nil)
    }
}
