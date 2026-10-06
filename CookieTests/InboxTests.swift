import Foundation
import Testing

@testable import Cookie

/// Lets a test hold one response until it says so.
private actor Gate {
    private var isOpen = false
    private(set) var isWaiting = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        isWaiting = true
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        for waiter in waiters {
            waiter.resume()
        }
        waiters = []
    }
}

private actor Counter {
    private var value = 0

    func next() -> Int {
        defer { value += 1 }
        return value
    }
}

private func row(_ id: String, unread: Bool = false) -> String {
    #"{"id":"\#(id)","from_address":"\#(id)@example.com","sent_at":"2026-10-05T09:48:12Z","#
        + #""is_unread":\#(unread),"labels":[]}"#
}

private func page(_ ids: [String], next: String?) -> String {
    let cursor = next.map { #""\#($0)""# } ?? "null"
    let rows = ids.map { row($0) }.joined(separator: ",")
    return #"{"emails":[\#(rows)],"nextCursor":\#(cursor),"unreadCount":1}"#
}

private let categoriesJSON = #"{"categories":[{"id":"c1","name":"Finance","color":null}]}"#

/// Routes by path: `/categories` always succeeds; `/emails` answers from a
/// queue of (status, body), repeating the last entry.
@MainActor
private func makeInbox(emailResponses: [(Int, String)], gateFirstEmails gate: Gate? = nil) -> Inbox {
    let tokens = TokenProvider(current: { "t" }, renewed: { "t" }, invalidate: {})
    let counter = Counter()
    let client = APIClient(tokens: tokens) { request in
        guard let url = request.url else { throw URLError(.badURL) }
        let (status, body): (Int, String)
        if url.path == "/categories" {
            (status, body) = (200, categoriesJSON)
        } else {
            let index = await counter.next()
            if index == 0, let gate { await gate.wait() }
            (status, body) = emailResponses[min(index, emailResponses.count - 1)]
        }
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else {
            throw URLError(.badURL)
        }
        return (Data(body.utf8), response)
    }
    return Inbox(client: client)
}

@MainActor
struct InboxTests {
    @Test func refreshLoadsRowsCategoriesAndCursor() async {
        let inbox = makeInbox(emailResponses: [(200, page(["a", "b"], next: "cur"))])
        #expect(inbox.phase == .loading)

        await inbox.refresh()

        #expect(inbox.phase == .loaded)
        #expect(inbox.emails.map(\.id) == ["a", "b"])
        #expect(inbox.categories.map(\.id) == ["c1"])
        #expect(inbox.nextCursor == "cur")
        #expect(inbox.tabs.map(\.id) == ["important", "category:c1", "other"])
    }

    @Test func loadMoreAppendsAndSkipsDuplicates() async {
        let inbox = makeInbox(
            emailResponses: [(200, page(["a", "b"], next: "cur")), (200, page(["b", "c"], next: nil))])
        await inbox.refresh()

        await inbox.loadMore()

        #expect(inbox.emails.map(\.id) == ["a", "b", "c"])
        #expect(inbox.nextCursor == nil)
        #expect(!inbox.loadMoreFailed)
    }

    @Test func loadMoreWithoutCursorDoesNothing() async {
        let inbox = makeInbox(emailResponses: [(200, page(["a"], next: nil))])
        await inbox.refresh()

        await inbox.loadMore()

        #expect(inbox.emails.map(\.id) == ["a"])
    }

    @Test func loadMoreFailureIsReportedAndRetryable() async {
        let inbox = makeInbox(
            emailResponses: [(200, page(["a"], next: "cur")), (500, "{}"), (200, page(["b"], next: nil))])
        await inbox.refresh()

        await inbox.loadMore()
        #expect(inbox.loadMoreFailed)
        #expect(inbox.emails.map(\.id) == ["a"])

        await inbox.loadMore()
        #expect(!inbox.loadMoreFailed)
        #expect(inbox.emails.map(\.id) == ["a", "b"])
    }

    @Test func firstLoadFailureSetsFailed() async {
        let inbox = makeInbox(emailResponses: [(503, "{}")])
        await inbox.refresh()
        #expect(inbox.phase == .failed)
        #expect(inbox.emails.isEmpty)
    }

    @Test func refreshFailureWithRowsKeepsThem() async {
        let inbox = makeInbox(emailResponses: [(200, page(["a"], next: nil)), (500, "{}")])
        await inbox.refresh()

        await inbox.refresh()

        #expect(inbox.phase == .loaded)
        #expect(inbox.refreshFailed)
        #expect(inbox.emails.map(\.id) == ["a"])
    }

    @Test func supersededRefreshIsDiscarded() async {
        let gate = Gate()
        let inbox = makeInbox(
            emailResponses: [(200, page(["old"], next: nil)), (200, page(["new"], next: nil))],
            gateFirstEmails: gate)

        let first = Task { await inbox.refresh() }
        while await !gate.isWaiting {
            await Task.yield()
        }
        await inbox.refresh()
        await gate.open()
        await first.value

        #expect(inbox.emails.map(\.id) == ["new"])
    }
}
