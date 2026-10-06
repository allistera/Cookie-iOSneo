import Foundation
import Testing

@testable import Cookie

private actor Counter {
    private(set) var refreshes = 0
    private(set) var loads = 0
    func count(_ method: String?) {
        if method == "POST" { refreshes += 1 } else { loads += 1 }
    }
}

@MainActor
private func makeToday(tasksBody: String = TriageTests.recorded, refreshStatus: Int = 200, counter: Counter)
    -> TodayModel
{
    let tokens = TokenProvider(current: { "t" }, renewed: { "t" }, invalidate: {})
    let client = APIClient(tokens: tokens) { request in
        guard let url = request.url else { throw URLError(.badURL) }
        await counter.count(request.httpMethod)
        let (status, body) = url.path == "/tasks/refresh" ? (refreshStatus, "{}") : (200, tasksBody)
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else {
            throw URLError(.badURL)
        }
        return (Data(body.utf8), response)
    }
    return TodayModel(client: client)
}

@MainActor
struct TodayModelTests {
    @Test func loadsDigest() async {
        let today = makeToday(counter: Counter())
        await today.load()
        guard case .loaded(let digest) = today.phase else {
            Issue.record("expected loaded, got \(today.phase)")
            return
        }
        #expect(digest.topics.count == 2)
    }

    @Test func nullDigestIsEmpty() async {
        let today = makeToday(tasksBody: #"{"tasks":[],"digest":null}"#, counter: Counter())
        await today.load()
        #expect(today.phase == .empty)
    }

    @Test func malformedResponseFails() async {
        let today = makeToday(tasksBody: "nope", counter: Counter())
        await today.load()
        #expect(today.phase == .failed)
    }

    @Test func refreshPostsThenReloads() async {
        let counter = Counter()
        let today = makeToday(counter: counter)
        await today.refresh()
        #expect(today.refreshState == .idle)
        #expect(await counter.refreshes == 1)
        #expect(await counter.loads == 1)
        guard case .loaded = today.phase else {
            Issue.record("expected loaded")
            return
        }
    }

    @Test func rateLimitedRefreshKeepsDigest() async {
        let counter = Counter()
        let today = makeToday(refreshStatus: 429, counter: counter)
        await today.load()
        await today.refresh()
        #expect(today.refreshState == .rateLimited)
        guard case .loaded = today.phase else {
            Issue.record("digest should be kept")
            return
        }
        #expect(await counter.loads == 1)
    }

    @Test func otherRefreshFailureIsReported() async {
        let today = makeToday(refreshStatus: 503, counter: Counter())
        await today.refresh()
        #expect(today.refreshState == .failed)
    }

    @Test func markReadClearsTheItem() async {
        let today = makeToday(counter: Counter())
        await today.load()
        today.markRead("6f1c")
        guard case .loaded(let digest) = today.phase else {
            Issue.record("expected loaded")
            return
        }
        #expect(digest.topics.first?.items.first?.unread == false)
    }
}
