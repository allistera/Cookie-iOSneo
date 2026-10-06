# Email Detail and Reply Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Inbox rows open the design's email detail screen, which renders the body safely in a bounded web view, marks the message read, and sends a plain-text reply with a quoted original.

**Architecture:** `EmailDetail` (`@Observable`) owns the body load, the read state and the reply draft on top of `APIClient`, which gains `post` and `patch`. `EmailBodyView` is the single WebKit bridge. `HomeView` owns the `Inbox` and a `NavigationStack` whose destination is `EmailDetailView`.

**Tech Stack:** Swift 6, SwiftUI, Observation, WebKit (one file), Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-06-email-detail-design.md`.

## Global Constraints

- As in `docs/superpowers/plans/2026-10-05-foundation-sign-in.md`: Xcode 27.0, Swift 6 mode, no force unwraps, no lint suppressions, tests only in CI, `scripts/format.sh` then `scripts/lint.sh` before each commit, co-author trailer on commits.
- Branch `email-detail` (based on `inbox`); pull request to `main` after #2 merges. Do not merge.
- `import WebKit` appears only in `Cookie/Detail/EmailBodyView.swift`.
- Every user-facing string is in `Cookie/Resources/Localizable.xcstrings`.

## File Structure

| Path | Responsibility |
| --- | --- |
| `Cookie/Networking/APIClient.swift` | `get`, `post`, `patch` over one `request` |
| `Cookie/Networking/Endpoint.swift` | `message(id:)`, `messages`, `send` |
| `Cookie/Networking/ISO8601Date.swift` | adds `JSONEncoder.cookieAPI()` |
| `Cookie/Inbox/EmailSummary.swift` | `Hashable`; `isUnread` becomes `var` |
| `Cookie/Inbox/Inbox.swift` | `markRead`, `markUnread` |
| `Cookie/Inbox/InboxView.swift`, `InboxPageView.swift` | take an injected `Inbox`; rows are `NavigationLink`s |
| `Cookie/Home/HomeView.swift` | owns `Inbox`; `NavigationStack` and destination |
| `Cookie/Detail/MessageBody.swift` | body model, `MarkReadRequest`, `SendRequest`, `EmptyResponse` |
| `Cookie/Detail/ReplyDraft.swift` | subject, quote, request builder |
| `Cookie/Detail/EmailDetail.swift` | state model |
| `Cookie/Detail/EmailBodyView.swift` | WebKit bridge |
| `Cookie/Detail/ReplyComposer.swift` | composer |
| `Cookie/Detail/EmailDetailView.swift` | screen |
| `CookieTests/…` | tests per task |

---

### Task 1: API client verbs, endpoints and models

**Files:** modify `APIClient.swift`, `Endpoint.swift`, `ISO8601Date.swift`, `EmailSummary.swift`, `Inbox.swift`; create `Cookie/Detail/MessageBody.swift`, `Cookie/Detail/ReplyDraft.swift`; tests `APIClientTests.swift` (add), `EndpointTests.swift` (add), `MessageBodyTests.swift`, `ReplyDraftTests.swift`, `InboxTests.swift` (add).

**Interfaces produced:**

```swift
extension JSONEncoder { static func cookieAPI() -> JSONEncoder }   // convertToSnakeCase
struct APIClient {
    func get<Response>(_ endpoint: Endpoint) async throws -> Response
    func post<Body: Encodable & Sendable, Response: Decodable & Sendable>(_ endpoint: Endpoint, body: Body, encoder: JSONEncoder = .cookieAPI()) async throws -> Response
    func patch<Body, Response>(_ endpoint: Endpoint, body: Body, encoder: JSONEncoder = .cookieAPI()) async throws -> Response
}
struct EmptyResponse: Decodable, Equatable, Sendable {}          // body is not decoded
enum CookieAPIEndpoints { static func message(id: String) -> Endpoint; static let messages: Endpoint; static let send: Endpoint }
struct MessageBody: Decodable, Equatable, Sendable { let id: String; let bodyHtml: String?; let bodyText: String? }
struct MarkReadRequest: Encodable, Equatable, Sendable { let id: String; let isUnread: Bool }
struct SendRequest: Encodable, Equatable, Sendable { let to, subject, text, replyToMessageId, requestId: String }
struct ReplyDraft: Equatable, Sendable {
    let requestID: String
    init(requestID: String = UUID().uuidString)
    static func subject(replyingTo subject: String?) -> String
    static func quotedText(original: EmailSummary, bodyText: String?, locale: Locale = .current, calendar: Calendar = .current, timeZone: TimeZone = .current) -> String
    func request(replyText: String, original: EmailSummary, bodyText: String?) -> SendRequest
}
extension Inbox { func markRead(_ id: String); func markUnread(_ id: String) }
```

- [ ] **Step 1: Tests**

Add to `CookieTests/EndpointTests.swift`:

```swift
    @Test func messageBodyPinsOriginAndQuery() {
        let url = CookieAPIEndpoints.message(id: "6f1c").url
        #expect(url?.absoluteString == "https://messages-api.infinitywave.online/messages?id=6f1c&calendar=deferred")
    }

    @Test func messagesAndSendPinOrigins() {
        #expect(CookieAPIEndpoints.messages.url?.absoluteString == "https://messages-api.infinitywave.online/messages")
        #expect(CookieAPIEndpoints.send.url?.absoluteString == "https://send-api.infinitywave.online/send")
    }
```

Add to `CookieTests/APIClientTests.swift` (inside `APIClientTests`):

```swift
    @Test func postEncodesSnakeCaseBodyAndContentType() async throws {
        let log = CallLog()
        let client = makeClient([StubResponse(status: 200, body: "{}")], log: log)

        let _: EmptyResponse = try await client.post(CookieAPIEndpoints.messages, body: MarkReadRequest(id: "m1", isUnread: false))

        let request = try #require(await log.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let json = try JSONSerialization.jsonObject(with: #require(request.httpBody)) as? [String: Any]
        #expect(json?["id"] as? String == "m1")
        #expect(json?["is_unread"] as? Bool == false)
    }

    @Test func patchWithPlainEncoderKeepsCamelCase() async throws {
        let log = CallLog()
        let client = makeClient([StubResponse(status: 200, body: "{}")], log: log)
        let body = SendRequest(to: "a@example.com", subject: "Re: x", text: "hi", replyToMessageId: "m1", requestId: "r1")

        let _: EmptyResponse = try await client.patch(CookieAPIEndpoints.send, body: body, encoder: JSONEncoder())

        let request = try #require(await log.requests.first)
        #expect(request.httpMethod == "PATCH")
        let json = try JSONSerialization.jsonObject(with: #require(request.httpBody)) as? [String: Any]
        #expect(json?["replyToMessageId"] as? String == "m1")
        #expect(json?["requestId"] as? String == "r1")
    }

    @Test func emptyResponseIgnoresBody() async throws {
        let log = CallLog()
        let client = makeClient([StubResponse(status: 200, body: "not json")], log: log)
        let _: EmptyResponse = try await client.get(CookieAPIEndpoints.categories)
    }
```

`CookieTests/MessageBodyTests.swift`:

```swift
import Foundation
import Testing

@testable import Cookie

struct MessageBodyTests {
    @Test func decodesRecordedShape() throws {
        let json = """
            {"id":"6f1c","subject":"Final terms","body_html":"<p>Hi</p>","body_text":"Hi","thread_summary":null,
             "thread":[],"attachments":[],"unsubscribe":null,"calendar_invite":null,"calendar_invite_pending":false}
            """
        let body = try JSONDecoder.cookieAPI().decode(MessageBody.self, from: Data(json.utf8))
        #expect(body == MessageBody(id: "6f1c", bodyHtml: "<p>Hi</p>", bodyText: "Hi"))
    }

    @Test func decodesNullBodies() throws {
        let json = #"{"id":"6f1c","body_html":null,"body_text":null}"#
        let body = try JSONDecoder.cookieAPI().decode(MessageBody.self, from: Data(json.utf8))
        #expect(body.bodyHtml == nil)
        #expect(body.bodyText == nil)
    }
}
```

`CookieTests/ReplyDraftTests.swift`:

```swift
import Foundation
import Testing

@testable import Cookie

struct ReplyDraftTests {
    private let original = EmailSummary(
        id: "6f1c", fromName: "Jordan Blake", fromAddress: "jordan@example.com", subject: "Final terms",
        snippet: nil, sentAt: Date(timeIntervalSince1970: 1_791_193_692), isUnread: true, priority: nil,
        labels: [], category: nil)
    private let locale = Locale(identifier: "en_GB")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }
    private let utc = TimeZone(identifier: "UTC") ?? .current

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
        #expect(ReplyDraft.quotedText(original: original, bodyText: nil, locale: locale, calendar: calendar, timeZone: utc).isEmpty)
        #expect(ReplyDraft.quotedText(original: original, bodyText: "  \n", locale: locale, calendar: calendar, timeZone: utc).isEmpty)
    }

    @Test func requestTargetsOriginalSenderAndKeepsRequestID() {
        let draft = ReplyDraft(requestID: "req-1")
        let request = draft.request(replyText: "Thanks", original: original, bodyText: nil)
        #expect(request.to == "jordan@example.com")
        #expect(request.subject == "Re: Final terms")
        #expect(request.text == "Thanks")
        #expect(request.replyToMessageId == "6f1c")
        #expect(request.requestId == "req-1")
    }
}
```

Add to `CookieTests/InboxTests.swift` (inside `InboxTests`):

```swift
    @Test func markReadAndUnreadUpdateTheRow() async {
        let inbox = makeInbox(emailResponses: [(200, #"{"emails":[\#(row("a", unread: true))],"nextCursor":null}"#)])
        await inbox.refresh()

        inbox.markRead("a")
        #expect(inbox.emails.first?.isUnread == false)
        #expect(inbox.tabs.last?.unreadCount == 0)

        inbox.markUnread("a")
        #expect(inbox.emails.first?.isUnread == true)
    }
```

- [ ] **Step 2: Production code**

`Cookie/Networking/APIClient.swift` (whole file):

```swift
import Foundation

/// Authenticated JSON requests to Cookie's Worker APIs.
struct APIClient: Sendable {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let tokens: TokenProvider
    private let transport: Transport

    init(
        tokens: TokenProvider,
        transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }
    ) {
        self.tokens = tokens
        self.transport = transport
    }

    func get<Response: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> Response {
        try await request(endpoint, method: "GET", body: nil)
    }

    /// Posts `body` as JSON. The default encoder writes snake_case keys;
    /// pass `JSONEncoder()` for routes that read camelCase.
    func post<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ endpoint: Endpoint, body: Body, encoder: JSONEncoder = .cookieAPI()
    ) async throws -> Response {
        try await request(endpoint, method: "POST", body: try encoder.encode(body))
    }

    func patch<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ endpoint: Endpoint, body: Body, encoder: JSONEncoder = .cookieAPI()
    ) async throws -> Response {
        try await request(endpoint, method: "PATCH", body: try encoder.encode(body))
    }

    /// A 401 forces one token renewal and one retry; a second 401
    /// invalidates the session.
    private func request<Response: Decodable & Sendable>(
        _ endpoint: Endpoint, method: String, body: Data?
    ) async throws -> Response {
        guard let url = endpoint.url else { throw APIError.invalidRequest }

        var (data, status) = try await send(url, method: method, body: body, token: try await tokens.current())
        if status == 401 {
            (data, status) = try await send(url, method: method, body: body, token: try await tokens.renewed())
            if status == 401 {
                await tokens.invalidate()
                throw APIError.unauthorised
            }
        }
        guard (200..<300).contains(status) else { throw APIError.server(status: status) }

        if Response.self == EmptyResponse.self, let empty = EmptyResponse() as? Response {
            return empty
        }
        do {
            return try JSONDecoder.cookieAPI().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func send(_ url: URL, method: String, body: Data?, token: String) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await transport(request)
            guard let http = response as? HTTPURLResponse else { throw APIError.transport }
            return (data, http.statusCode)
        } catch let error as APIError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw APIError.transport
        }
    }
}

/// For routes whose response body the app does not read.
struct EmptyResponse: Decodable, Equatable, Sendable {
    init() {}
}
```

Append to `Cookie/Networking/ISO8601Date.swift`:

```swift
extension JSONEncoder {
    /// Encodes request bodies with the Workers' snake_case keys.
    static func cookieAPI() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}
```

Add to `CookieAPIEndpoints`:

```swift
    static let messages = Endpoint(host: "messages-api.infinitywave.online", path: "/messages")
    static let send = Endpoint(host: "send-api.infinitywave.online", path: "/send")

    /// One message's body. Calendar-invite parsing is deferred: the reader does not show invites.
    static func message(id: String) -> Endpoint {
        Endpoint(
            host: "messages-api.infinitywave.online", path: "/messages",
            queryItems: [URLQueryItem(name: "id", value: id), URLQueryItem(name: "calendar", value: "deferred")])
    }
```

In `EmailSummary.swift`: `EmailLabel`, `EmailCategory` and `EmailSummary` add `Hashable`; `let isUnread: Bool` becomes `var isUnread: Bool`.

Add to `Inbox`:

```swift
    /// Clears the row's unread flag so tab counts and row weight update at once.
    func markRead(_ id: String) {
        setUnread(id, false)
    }

    /// Restores the unread flag after the server rejected a mark-read.
    func markUnread(_ id: String) {
        setUnread(id, true)
    }

    private func setUnread(_ id: String, _ isUnread: Bool) {
        guard let index = emails.firstIndex(where: { $0.id == id }) else { return }
        emails[index].isUnread = isUnread
    }
```

`Cookie/Detail/MessageBody.swift`:

```swift
/// The part of `GET /messages?id=` the reader shows. Both bodies may be null.
struct MessageBody: Decodable, Equatable, Sendable {
    let id: String
    let bodyHtml: String?
    let bodyText: String?
}

/// `PATCH /messages` body; encoded with snake_case keys.
struct MarkReadRequest: Encodable, Equatable, Sendable {
    let id: String
    let isUnread: Bool
}

/// `POST /send` body. The send Worker reads camelCase keys, so encode this
/// with a plain `JSONEncoder`.
struct SendRequest: Encodable, Equatable, Sendable {
    let to: String
    let subject: String
    let text: String
    let replyToMessageId: String
    let requestId: String
}
```

`Cookie/Detail/ReplyDraft.swift`:

```swift
import Foundation

/// A reply in progress. The request id is fixed for the draft's life so a
/// retried send is deduplicated by the Worker.
struct ReplyDraft: Equatable, Sendable {
    let requestID: String

    init(requestID: String = UUID().uuidString) {
        self.requestID = requestID
    }

    /// "Re: " before the original subject unless it already carries one.
    static func subject(replyingTo subject: String?) -> String {
        let trimmed = subject?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let base = trimmed.isEmpty ? String(localized: "(No subject)") : trimmed
        return base.lowercased().hasPrefix("re:") ? base : "Re: \(base)"
    }

    /// The original's plain text quoted below the reply, or empty when there is none.
    static func quotedText(
        original: EmailSummary, bodyText: String?, locale: Locale = .current, calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> String {
        guard let bodyText, !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        let date = original.sentAt.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale, calendar: calendar, timeZone: timeZone))
        let header = String(localized: "On \(date), \(original.senderName) wrote:")
        let quoted = bodyText.split(separator: "\n", omittingEmptySubsequences: false)
            .map { "> \($0)" }
            .joined(separator: "\n")
        return "\n\n\(header)\n\(quoted)"
    }

    func request(replyText: String, original: EmailSummary, bodyText: String?) -> SendRequest {
        SendRequest(
            to: original.fromAddress,
            subject: Self.subject(replyingTo: original.subject),
            text: replyText + Self.quotedText(original: original, bodyText: bodyText),
            replyToMessageId: original.id,
            requestId: requestID)
    }
}
```

- [ ] **Step 3: Compile, format, lint, commit** (`"Add API verbs, message body and reply draft"`). Expected CI later: 49 + 12 = 61 tests.

---

### Task 2: `EmailDetail` model

**Files:** create `Cookie/Detail/EmailDetail.swift`; test `CookieTests/EmailDetailTests.swift`.

- [ ] **Step 1: Tests**

```swift
import Foundation
import Testing

@testable import Cookie

private actor Recorder {
    private(set) var requests: [URLRequest] = []
    func record(_ request: URLRequest) { requests.append(request) }
    func bodies(for method: String) -> [Data] { requests.filter { $0.httpMethod == method }.compactMap(\.httpBody) }
}

private let bodyJSON = #"{"id":"6f1c","body_html":"<p>Hi</p>","body_text":"Hi"}"#

/// Routes: GET /messages → `bodyStatus`; PATCH /messages → `patchStatus`;
/// POST /send → `sendStatus`; GET /emails and /categories → one unread row.
@MainActor
private func makeDetail(
    bodyStatus: Int = 200, patchStatus: Int = 200, sendStatus: Int = 200, recorder: Recorder, unread: Bool = true
) async -> (EmailDetail, Inbox) {
    let tokens = TokenProvider(current: { "t" }, renewed: { "t" }, invalidate: {})
    let client = APIClient(tokens: tokens) { request in
        await recorder.record(request)
        guard let url = request.url else { throw URLError(.badURL) }
        let (status, body): (Int, String) =
            switch (url.path, request.httpMethod) {
            case ("/messages", "GET"): (bodyStatus, bodyJSON)
            case ("/messages", "PATCH"): (patchStatus, "{}")
            case ("/send", "POST"): (sendStatus, #"{"id":"re_1","messageId":"m2"}"#)
            case ("/categories", _): (200, #"{"categories":[]}"#)
            default:
                (200, #"{"emails":[{"id":"6f1c","from_name":"Jordan Blake","from_address":"jordan@example.com","subject":"Final terms","sent_at":"2026-10-05T09:48:12Z","is_unread":\#(unread),"labels":[]}],"nextCursor":null}"#)
            }
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else {
            throw URLError(.badURL)
        }
        return (Data(body.utf8), response)
    }
    let inbox = Inbox(client: client)
    await inbox.refresh()
    guard let email = inbox.emails.first else { Issue.record("inbox did not load"); return (EmailDetail(email: InboxPreviewData.emails[0], client: client, inbox: inbox), inbox) }
    return (EmailDetail(email: email, client: client, inbox: inbox), inbox)
}

@MainActor
struct EmailDetailTests {
    @Test func loadsBodyAndMarksRead() async throws {
        let recorder = Recorder()
        let (detail, inbox) = await makeDetail(recorder: recorder)

        await detail.load()

        #expect(detail.body == .loaded(MessageBody(id: "6f1c", bodyHtml: "<p>Hi</p>", bodyText: "Hi")))
        #expect(inbox.emails.first?.isUnread == false)
        let patch = try #require(await recorder.bodies(for: "PATCH").first)
        let json = try JSONSerialization.jsonObject(with: patch) as? [String: Any]
        #expect(json?["id"] as? String == "6f1c")
        #expect(json?["is_unread"] as? Bool == false)
    }

    @Test func alreadyReadEmailIsNotPatched() async {
        let recorder = Recorder()
        let (detail, _) = await makeDetail(recorder: recorder, unread: false)
        await detail.load()
        #expect(await recorder.bodies(for: "PATCH").isEmpty)
    }

    @Test func failedMarkReadRestoresUnread() async {
        let recorder = Recorder()
        let (detail, inbox) = await makeDetail(patchStatus: 500, recorder: recorder)
        await detail.load()
        #expect(inbox.emails.first?.isUnread == true)
    }

    @Test func bodyFailureIsReported() async {
        let recorder = Recorder()
        let (detail, _) = await makeDetail(bodyStatus: 404, recorder: recorder)
        await detail.load()
        #expect(detail.body == .failed)
    }

    @Test func sendSuccessClearsTextAndReportsSent() async throws {
        let recorder = Recorder()
        let (detail, _) = await makeDetail(recorder: recorder)
        await detail.load()
        detail.openReply()
        detail.replyText = "Thanks, Jordan."

        await detail.send()

        #expect(detail.reply == .sent)
        #expect(detail.replyText.isEmpty)
        let sent = try #require(await recorder.bodies(for: "POST").first)
        let json = try JSONSerialization.jsonObject(with: sent) as? [String: Any]
        #expect(json?["to"] as? String == "jordan@example.com")
        #expect(json?["subject"] as? String == "Re: Final terms")
        #expect((json?["text"] as? String)?.hasPrefix("Thanks, Jordan.\n\nOn ") == true)
        #expect((json?["text"] as? String)?.hasSuffix("wrote:\n> Hi") == true)
        #expect(json?["replyToMessageId"] as? String == "6f1c")
    }

    @Test func sendFailureKeepsTextAndReusesRequestID() async throws {
        let recorder = Recorder()
        let (detail, _) = await makeDetail(sendStatus: 502, recorder: recorder)
        detail.openReply()
        detail.replyText = "Thanks"

        await detail.send()
        #expect(detail.reply == .failed)
        #expect(detail.replyText == "Thanks")
        await detail.send()

        let bodies = await recorder.bodies(for: "POST")
        #expect(bodies.count == 2)
        let ids = try bodies.map { try (JSONSerialization.jsonObject(with: $0) as? [String: Any])?["requestId"] as? String }
        #expect(ids[0] != nil)
        #expect(ids[0] == ids[1])
    }

    @Test func blankReplyDoesNotSend() async {
        let recorder = Recorder()
        let (detail, _) = await makeDetail(recorder: recorder)
        detail.openReply()
        detail.replyText = "   "
        await detail.send()
        #expect(detail.reply == .composing)
        #expect(await recorder.bodies(for: "POST").isEmpty)
    }

    @Test func showRemoteImagesFlips() async {
        let recorder = Recorder()
        let (detail, _) = await makeDetail(recorder: recorder)
        #expect(!detail.showsRemoteImages)
        detail.showRemoteImages()
        #expect(detail.showsRemoteImages)
    }
}
```

- [ ] **Step 2: `Cookie/Detail/EmailDetail.swift`**

```swift
import Foundation
import OSLog
import Observation

/// One open email: its body, read state and reply.
@MainActor
@Observable
final class EmailDetail {
    enum BodyPhase: Equatable {
        case loading
        case loaded(MessageBody)
        case failed
    }

    enum ReplyPhase: Equatable {
        case closed
        case composing
        case sending
        case sent
        case failed
    }

    let email: EmailSummary
    private(set) var body: BodyPhase = .loading
    private(set) var reply: ReplyPhase = .closed
    var replyText = ""
    private(set) var showsRemoteImages = false

    private let client: APIClient
    private let inbox: Inbox
    private var draft: ReplyDraft?
    private var hasMarkedRead = false
    private static let logger = Logger(subsystem: "com.cookie.ios", category: "detail")

    init(email: EmailSummary, client: APIClient, inbox: Inbox) {
        self.email = email
        self.client = client
        self.inbox = inbox
    }

    /// Fetches the body and, on first open of an unread email, marks it read.
    func load() async {
        body = .loading
        let needsMarkRead = !hasMarkedRead && email.isUnread
        hasMarkedRead = true
        if needsMarkRead { inbox.markRead(email.id) }
        do {
            async let fetched: MessageBody = client.get(CookieAPIEndpoints.message(id: email.id))
            if needsMarkRead { await markRead() }
            body = .loaded(try await fetched)
        } catch is CancellationError {
            return
        } catch {
            body = .failed
        }
    }

    private func markRead() async {
        do {
            let _: EmptyResponse = try await client.patch(
                CookieAPIEndpoints.messages, body: MarkReadRequest(id: email.id, isUnread: false))
        } catch is CancellationError {
            inbox.markUnread(email.id)
        } catch {
            Self.logger.error("Mark read failed: \(String(describing: type(of: error)), privacy: .public)")
            inbox.markUnread(email.id)
        }
    }

    func showRemoteImages() {
        showsRemoteImages = true
    }

    func openReply() {
        if draft == nil { draft = ReplyDraft() }
        reply = .composing
    }

    func closeReply() {
        reply = .closed
    }

    func send() async {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let draft, reply != .sending else { return }
        reply = .sending
        var bodyText: String?
        if case .loaded(let loaded) = body { bodyText = loaded.bodyText }
        let request = draft.request(replyText: text, original: email, bodyText: bodyText)
        do {
            let _: EmptyResponse = try await client.post(CookieAPIEndpoints.send, body: request, encoder: JSONEncoder())
            replyText = ""
            self.draft = nil
            reply = .sent
        } catch is CancellationError {
            reply = .composing
        } catch {
            Self.logger.error("Send failed: \(String(describing: type(of: error)), privacy: .public)")
            reply = .failed
        }
    }
}
```

- [ ] **Step 3: Compile, format, lint, commit** (`"Add email detail model"`).

---

### Task 3: Body bridge, composer and screen

**Files:** create `Cookie/Detail/EmailBodyView.swift`, `Cookie/Detail/ReplyComposer.swift`, `Cookie/Detail/EmailDetailView.swift`; modify `HomeView.swift`, `InboxView.swift`, `InboxPageView.swift`, `Localizable.xcstrings`; test `CookieTests/EmailBodyViewTests.swift`.

- [ ] **Step 1: Test**

```swift
import Testing

@testable import Cookie

struct EmailBodyViewTests {
    @Test func detectsRemoteContent() {
        for html in [
            #"<img src="https://t.example/p.gif">"#, #"<img SRC='http://x/y.png'>"#,
            #"<div style="background: url(https://x/y.png)">"#, #"<td background="https://x/y.png">"#,
            #"<link rel="stylesheet" href="https://x/a.css">"#, #"<style>@import "https://x/a.css";</style>"#,
            #"<video src="https://x/a.mp4">"#,
        ] {
            #expect(EmailBodyView.hasBlockedRemoteContent(html), "\(html)")
        }
    }

    @Test func ignoresLinksAndInlineData() {
        for html in ["", "<p>Hello</p>", #"<a href="https://x">link</a>"#, #"<img src="data:image/png;base64,AAAA">"#, #"<img src="cid:part1">"#] {
            #expect(!EmailBodyView.hasBlockedRemoteContent(html), "\(html)")
        }
    }
}
```

- [ ] **Step 2: `Cookie/Detail/EmailBodyView.swift`** — the WebKit bridge as written in the implementation (JavaScript off, non-persistent store, content rule list blocking remote image/style-sheet/font/media/raw loads unless `showsRemoteImages`, fail-closed placeholder, external link opening, height via KVO clamped to 12,000, CSS with Figtree `@font-face` from the bundle and `color-scheme: light dark`). `hasBlockedRemoteContent` uses the six patterns from the test.

- [ ] **Step 3: `Cookie/Detail/ReplyComposer.swift`**, **`Cookie/Detail/EmailDetailView.swift`**, navigation changes in `HomeView`, `InboxView`, `InboxPageView` as in the spec's UI section; strings added: `"to me"`, `"Reply to %@"`, `"Send reply"`, `"Show images"`, `"Reply sent to %@."`, `"Couldn't send. Try again."`, `"Message unavailable"`, `"This message can't be shown safely right now."`, `"On %@, %@ wrote:"`.

- [ ] **Step 4: Compile, format, lint, inspect previews where possible, commit** (`"Add email detail screen with reply"`), push, open PR, verify CI on the SHA, hand off.
