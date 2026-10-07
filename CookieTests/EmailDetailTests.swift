import Foundation
import Testing

@testable import Cookie

private actor Recorder {
    private(set) var requests: [URLRequest] = []

    func record(_ request: URLRequest) {
        requests.append(request)
    }

    func bodies(for method: String) -> [Data] {
        requests.filter { $0.httpMethod == method }.compactMap(\.httpBody)
    }

    func requests(path: String, method: String) -> [URLRequest] {
        requests.filter { $0.url?.path == path && $0.httpMethod == method }
    }
}

private actor RequestGate {
    private var arrived = false
    private var released = false
    private var arrivalContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func arriveAndWait() async {
        arrived = true
        arrivalContinuation?.resume()
        arrivalContinuation = nil
        if !released {
            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
            }
        }
    }

    func waitForArrival() async {
        if arrived { return }
        await withCheckedContinuation { continuation in
            arrivalContinuation = continuation
        }
    }

    func release() {
        released = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

private let bodyJSON = #"{"id":"6f1c","body_html":"<p>Hi</p>","body_text":"Hi"}"#

private func inboxJSON(unread: Bool) -> String {
    #"{"emails":[{"id":"6f1c","from_name":"Jordan Blake","from_address":"jordan@example.com","#
        + #""subject":"Final terms","sent_at":"2026-10-05T09:48:12Z","is_unread":\#(unread),"labels":[]}],"#
        + #""nextCursor":null}"#
}

/// Routes: GET /messages → `bodyStatus`; PATCH /messages → `patchStatus`;
/// POST /send → `sendStatus`; GET /emails and /categories → one row.
@MainActor
private func makeDetail(
    bodyStatus: Int = 200, patchStatus: Int = 200, sendStatus: Int = 200, recorder: Recorder, unread: Bool = true,
    initialBody: MessageBody? = nil, onMarkedRead: @escaping @MainActor (String) -> Void = { _ in },
    patchGate: RequestGate? = nil, sendGate: RequestGate? = nil
) async throws -> (EmailDetail, Mailbox) {
    let tokens = TokenProvider(current: { "t" }, renewed: { "t" }, invalidate: {})
    let client = APIClient(tokens: tokens) { request in
        await recorder.record(request)
        guard let url = request.url else { throw URLError(.badURL) }
        let status: Int
        let body: String
        switch (url.path, request.httpMethod) {
        case ("/messages", "GET"):
            status = bodyStatus
            body = bodyJSON
        case ("/messages", "PATCH"):
            if let patchGate { await patchGate.arriveAndWait() }
            status = patchStatus
            body = "{}"
        case ("/send", "POST"):
            if let sendGate { await sendGate.arriveAndWait() }
            status = sendStatus
            body = #"{"id":"re_1","messageId":"m2"}"#
        case ("/categories", _):
            status = 200
            body = #"{"categories":[]}"#
        default:
            status = 200
            body = inboxJSON(unread: unread)
        }
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else {
            throw URLError(.badURL)
        }
        return (Data(body.utf8), response)
    }
    let mailbox = Mailbox(client: client)
    await mailbox.refresh()
    let email = try #require(mailbox.emails.first)
    return (
        EmailDetail(
            email: email, client: client, mailbox: mailbox, initialBody: initialBody,
            onMarkedRead: onMarkedRead),
        mailbox
    )
}

private func json(_ data: Data) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

@MainActor
struct EmailDetailTests {
    @Test func loadsBodyAndMarksRead() async throws {
        let recorder = Recorder()
        let (detail, mailbox) = try await makeDetail(recorder: recorder)

        await detail.load()

        #expect(detail.body == .loaded(MessageBody(id: "6f1c", bodyHtml: "<p>Hi</p>", bodyText: "Hi")))
        #expect(mailbox.emails.first?.isUnread == false)
        let patch = try json(#require(await recorder.bodies(for: "PATCH").first))
        #expect(patch["id"] as? String == "6f1c")
        #expect(patch["is_unread"] as? Bool == false)
    }

    @Test func alreadyReadEmailIsNotPatched() async throws {
        let recorder = Recorder()
        let (detail, _) = try await makeDetail(recorder: recorder, unread: false)
        await detail.load()
        #expect(await recorder.bodies(for: "PATCH").isEmpty)
    }

    @Test func injectedBodyAvoidsDuplicateGetAndReportsConfirmedRead() async throws {
        let recorder = Recorder()
        var markedReadIDs: [String] = []
        let body = MessageBody(id: "6f1c", bodyHtml: "<p>Seeded</p>", bodyText: "Seeded")
        let (detail, _) = try await makeDetail(
            recorder: recorder, initialBody: body, onMarkedRead: { markedReadIDs.append($0) })

        await detail.load()

        #expect(detail.body == .loaded(body))
        #expect(await recorder.requests(path: "/messages", method: "GET").isEmpty)
        #expect(markedReadIDs == ["6f1c"])
    }

    @Test(.timeLimit(.minutes(1))) func bodyIsPublishedBeforeMarkReadCompletes() async throws {
        let recorder = Recorder()
        let patchGate = RequestGate()
        let (detail, mailbox) = try await makeDetail(recorder: recorder, patchGate: patchGate)
        let loadTask = Task { await detail.load() }

        await patchGate.waitForArrival()
        let expectedBody = MessageBody(id: "6f1c", bodyHtml: "<p>Hi</p>", bodyText: "Hi")
        while detail.body != .loaded(expectedBody) {
            guard !Task.isCancelled else { return }
            await Task.yield()
        }
        #expect(detail.body == .loaded(expectedBody))
        #expect(mailbox.emails.first?.isUnread == true)

        await patchGate.release()
        await loadTask.value
        #expect(mailbox.emails.first?.isUnread == false)
    }

    @Test func failedMarkReadRestoresUnread() async throws {
        let recorder = Recorder()
        let (detail, mailbox) = try await makeDetail(patchStatus: 500, recorder: recorder)
        await detail.load()
        #expect(mailbox.emails.first?.isUnread == true)
        await detail.load()
        #expect(await recorder.bodies(for: "PATCH").count == 2)
    }

    @Test func bodyFailureIsReported() async throws {
        let recorder = Recorder()
        let (detail, _) = try await makeDetail(bodyStatus: 404, recorder: recorder)
        await detail.load()
        #expect(detail.body == .failed)
    }

    @Test func sendSuccessClearsTextAndReportsSent() async throws {
        let recorder = Recorder()
        let (detail, _) = try await makeDetail(recorder: recorder)
        await detail.load()
        detail.openReply()
        detail.replyText = "Thanks, Jordan."

        await detail.send()

        #expect(detail.reply == .sent)
        #expect(detail.replyText.isEmpty)
        let sent = try json(#require(await recorder.bodies(for: "POST").first))
        #expect(sent["to"] as? String == "jordan@example.com")
        #expect(sent["subject"] as? String == "Re: Final terms")
        #expect((sent["text"] as? String)?.hasPrefix("Thanks, Jordan.\n\nOn ") == true)
        #expect((sent["text"] as? String)?.hasSuffix("wrote:\n> Hi") == true)
        #expect(sent["replyToMessageId"] as? String == "6f1c")
    }

    @Test func sendFailureKeepsTextAndReusesRequestID() async throws {
        let recorder = Recorder()
        let (detail, _) = try await makeDetail(sendStatus: 502, recorder: recorder)
        detail.openReply()
        detail.replyText = "Thanks"

        await detail.send()
        #expect(detail.reply == .failed)
        #expect(detail.replyText == "Thanks")
        await detail.send()

        let bodies = await recorder.bodies(for: "POST")
        #expect(bodies.count == 2)
        let ids = try bodies.map { try json($0)["requestId"] as? String }
        #expect(ids.first != nil)
        #expect(ids.first == ids.last)
    }

    @Test func inFlightSendFreezesPayloadAndPreservesNewEditorText() async throws {
        let recorder = Recorder()
        let sendGate = RequestGate()
        let (detail, _) = try await makeDetail(recorder: recorder, sendGate: sendGate)
        detail.openReply()
        detail.replyText = "Original text"

        let sendTask = Task { await detail.send() }
        await sendGate.waitForArrival()

        detail.replyText = "Edited while sending"
        detail.closeReply()
        detail.openReply()
        #expect(detail.reply == .sending)

        await sendGate.release()
        await sendTask.value

        #expect(detail.reply == .composing)
        #expect(detail.replyText == "Edited while sending")
        let sent = try json(#require(await recorder.bodies(for: "POST").first))
        #expect((sent["text"] as? String)?.hasPrefix("Original text") == true)
    }

    @Test func blankReplyDoesNotSend() async throws {
        let recorder = Recorder()
        let (detail, _) = try await makeDetail(recorder: recorder)
        detail.openReply()
        detail.replyText = "   "
        await detail.send()
        #expect(detail.reply == .composing)
        #expect(await recorder.bodies(for: "POST").isEmpty)
    }

    @Test func showRemoteImagesFlips() async throws {
        let recorder = Recorder()
        let (detail, _) = try await makeDetail(recorder: recorder)
        #expect(!detail.showsRemoteImages)
        detail.showRemoteImages()
        #expect(detail.showsRemoteImages)
    }
}
