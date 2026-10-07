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

private actor TaskResponses {
    private var responses: [(Int, String)]

    init(_ responses: [(Int, String)]) {
        self.responses = responses
    }

    func next() -> (Int, String) {
        if responses.count > 1 { return responses.removeFirst() }
        return responses[0]
    }
}

private actor LoadGate {
    private(set) var isWaiting = false
    private var isOpen = false
    private var shouldWait = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func arm() {
        shouldWait = true
    }

    func waitIfArmed() async {
        guard shouldWait else { return }
        shouldWait = false
        await wait()
    }

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

    @Test func failedFollowUpLoadKeepsPopulatedDigestAndExposesError() async {
        let responses = TaskResponses([(200, TriageTests.recorded), (503, "{}")])
        let tokens = TokenProvider(current: { "t" }, renewed: { "t" }, invalidate: {})
        let client = APIClient(tokens: tokens) { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let (status, body): (Int, String) =
                if url.path == "/tasks/refresh" { (200, "{}") } else { await responses.next() }
            guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
            else { throw URLError(.badURL) }
            return (Data(body.utf8), response)
        }
        let today = TodayModel(client: client)

        await today.load()
        await today.refresh()

        #expect(today.refreshState == .failed)
        #expect(today.loadError == .server(status: 503))
        guard case .loaded = today.phase else {
            Issue.record("the previously loaded digest should remain visible")
            return
        }
    }

    @Test func failedFollowUpLoadKeepsEmptyStateAndExposesError() async {
        let responses = TaskResponses([(200, #"{"digest":null}"#), (503, "{}")])
        let tokens = TokenProvider(current: { "t" }, renewed: { "t" }, invalidate: {})
        let client = APIClient(tokens: tokens) { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let (status, body): (Int, String) =
                if url.path == "/tasks/refresh" { (200, "{}") } else { await responses.next() }
            guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
            else { throw URLError(.badURL) }
            return (Data(body.utf8), response)
        }
        let today = TodayModel(client: client)

        await today.load()
        await today.refresh()

        #expect(today.refreshState == .failed)
        #expect(today.loadError == .server(status: 503))
        #expect(today.phase == .empty)
    }

    @Test func slowerLoadCannotReplaceNewerLoad() async {
        let gate = LoadGate()
        let responses = TaskResponses([
            (200, TriageTests.recorded),
            (200, TriageTests.recorded.replacingOccurrences(of: "Two things need a reply today.", with: "New digest")),
        ])
        let tokens = TokenProvider(current: { "t" }, renewed: { "t" }, invalidate: {})
        let client = APIClient(tokens: tokens) { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let responseValue = await responses.next()
            await gate.waitIfArmed()
            guard
                let response = HTTPURLResponse(
                    url: url, statusCode: responseValue.0, httpVersion: nil, headerFields: nil)
            else { throw URLError(.badURL) }
            return (Data(responseValue.1.utf8), response)
        }
        let today = TodayModel(client: client)

        await gate.arm()
        let first = Task { await today.load() }
        while await !gate.isWaiting {
            await Task.yield()
        }
        await today.load()
        await gate.open()
        await first.value

        guard case .loaded(let digest) = today.phase else {
            Issue.record("expected loaded digest")
            return
        }
        #expect(digest.overview == "New digest")
    }

    @Test func confirmedReadInvalidatesAnOlderDigestLoad() async {
        let gate = LoadGate()
        let tokens = TokenProvider(current: { "t" }, renewed: { "t" }, invalidate: {})
        let client = APIClient(tokens: tokens) { request in
            guard let url = request.url else { throw URLError(.badURL) }
            await gate.waitIfArmed()
            guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            else { throw URLError(.badURL) }
            return (Data(TriageTests.recorded.utf8), response)
        }
        let today = TodayModel(client: client)
        await today.load()
        await gate.arm()

        let reload = Task { await today.load() }
        while await !gate.isWaiting {
            await Task.yield()
        }
        today.markRead("6f1c")
        await gate.open()
        await reload.value

        guard case .loaded(let digest) = today.phase else {
            Issue.record("expected loaded digest")
            return
        }
        #expect(digest.topics.first?.items.first?.unread == false)
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
