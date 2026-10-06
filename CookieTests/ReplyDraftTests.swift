import Foundation
import Testing

@testable import Cookie

struct ReplyDraftTests {
    private let original = EmailSummary(
        id: "6f1c", fromName: "Jordan Blake", fromAddress: "jordan@example.com", subject: "Final terms",
        snippet: nil, sentAt: Date(timeIntervalSince1970: 1_791_193_692), isUnread: true, priority: nil,
        labels: [], category: nil)
    private let locale = Locale(identifier: "en_GB")
    private let utc = TimeZone(identifier: "UTC") ?? .current
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar
    }

    @Test func subjectGetsRePrefixOnce() {
        #expect(ReplyDraft.subject(replyingTo: "Final terms") == "Re: Final terms")
        #expect(ReplyDraft.subject(replyingTo: "RE: Final terms") == "RE: Final terms")
        #expect(ReplyDraft.subject(replyingTo: "  re: x ") == "re: x")
        #expect(ReplyDraft.subject(replyingTo: nil) == "Re: (No subject)")
        #expect(ReplyDraft.subject(replyingTo: "  ") == "Re: (No subject)")
    }

    @Test func quotesOriginalTextWithHeader() {
        let quote = ReplyDraft.quotedText(
            original: original, bodyText: "Line one\n\nLine two", locale: locale, calendar: calendar, timeZone: utc)
        #expect(quote == "\n\nOn 5 Oct 2026 at 9:48, Jordan Blake wrote:\n> Line one\n> \n> Line two")
    }

    @Test func noBodyTextMeansNoQuote() {
        let none = ReplyDraft.quotedText(
            original: original, bodyText: nil, locale: locale, calendar: calendar, timeZone: utc)
        let blank = ReplyDraft.quotedText(
            original: original, bodyText: "  \n", locale: locale, calendar: calendar, timeZone: utc)
        #expect(none.isEmpty)
        #expect(blank.isEmpty)
    }

    @Test func requestTargetsOriginalSenderAndKeepsRequestID() {
        let draft = ReplyDraft(requestID: "req-1")
        let request = draft.request(replyText: "Thanks", original: original, bodyText: nil)
        #expect(request.recipient == "jordan@example.com")
        #expect(request.subject == "Re: Final terms")
        #expect(request.text == "Thanks")
        #expect(request.replyToMessageId == "6f1c")
        #expect(request.requestId == "req-1")
    }
}
