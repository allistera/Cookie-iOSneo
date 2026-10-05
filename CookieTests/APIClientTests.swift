import Foundation
import Testing

@testable import Cookie

/// Records what the client asked for, without shared global state.
private actor CallLog {
    private(set) var requests: [URLRequest] = []
    private(set) var renewals = 0
    private(set) var invalidations = 0

    func record(_ request: URLRequest) -> Int {
        requests.append(request)
        return requests.count
    }

    func recordRenewal() { renewals += 1 }
    func recordInvalidation() { invalidations += 1 }
}

private struct StubResponse: Sendable {
    let status: Int
    let body: String
}

struct APIClientTests {
    /// A client whose transport answers the nth request with the nth stub,
    /// repeating the last stub for any further requests.
    private func makeClient(_ stubs: [StubResponse], log: CallLog) -> APIClient {
        let tokens = TokenProvider(
            current: { "first-token" },
            renewed: {
                await log.recordRenewal()
                return "renewed-token"
            },
            invalidate: { await log.recordInvalidation() }
        )
        return APIClient(tokens: tokens) { request in
            let index = await log.record(request) - 1
            let stub = stubs[min(index, stubs.count - 1)]
            guard let url = request.url,
                let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: nil, headerFields: nil)
            else { throw URLError(.badURL) }
            return (Data(stub.body.utf8), response)
        }
    }

    @Test func attachesBearerTokenAndDecodesSuccess() async throws {
        let log = CallLog()
        let client = makeClient([StubResponse(status: 200, body: #"{"unreadCount":7}"#)], log: log)

        let state: MailboxState = try await client.get(CookieAPIEndpoints.mailboxState)

        #expect(state == MailboxState(unreadCount: 7))
        let requests = await log.requests
        #expect(requests.count == 1)
        #expect(requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer first-token")
        #expect(requests.first?.url?.absoluteString == "https://emails-api.infinitywave.online/emails/state")
    }

    @Test func renewsTokenAndRetriesOnceAfterUnauthorised() async throws {
        let log = CallLog()
        let client = makeClient(
            [StubResponse(status: 401, body: "{}"), StubResponse(status: 200, body: #"{"unreadCount":2}"#)],
            log: log
        )

        let state: MailboxState = try await client.get(CookieAPIEndpoints.mailboxState)

        #expect(state == MailboxState(unreadCount: 2))
        let requests = await log.requests
        #expect(requests.count == 2)
        #expect(requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer renewed-token")
        #expect(await log.renewals == 1)
        #expect(await log.invalidations == 0)
    }

    @Test func secondUnauthorisedInvalidatesSessionAndThrows() async {
        let log = CallLog()
        let client = makeClient([StubResponse(status: 401, body: "{}")], log: log)

        await #expect(throws: APIError.unauthorised) {
            let _: MailboxState = try await client.get(CookieAPIEndpoints.mailboxState)
        }
        #expect(await log.requests.count == 2)
        #expect(await log.invalidations == 1)
    }

    @Test func serverErrorIsNotRetried() async {
        let log = CallLog()
        let stub = StubResponse(status: 500, body: #"{"error":"Failed to load inbox state"}"#)
        let client = makeClient([stub], log: log)

        await #expect(throws: APIError.server(status: 500)) {
            let _: MailboxState = try await client.get(CookieAPIEndpoints.mailboxState)
        }
        #expect(await log.requests.count == 1)
    }

    @Test func malformedBodyThrowsDecoding() async {
        let log = CallLog()
        let client = makeClient([StubResponse(status: 200, body: "not json")], log: log)

        await #expect(throws: APIError.decoding) {
            let _: MailboxState = try await client.get(CookieAPIEndpoints.mailboxState)
        }
    }

    @Test func transportFailureThrowsTransport() async {
        let tokens = TokenProvider(current: { "token" }, renewed: { "token" }, invalidate: {})
        let client = APIClient(tokens: tokens) { _ in throw URLError(.notConnectedToInternet) }

        await #expect(throws: APIError.transport) {
            let _: MailboxState = try await client.get(CookieAPIEndpoints.mailboxState)
        }
    }

    @Test func cancelledRequestThrowsCancellationNotTransport() async {
        let tokens = TokenProvider(current: { "token" }, renewed: { "token" }, invalidate: {})
        let client = APIClient(tokens: tokens) { _ in throw URLError(.cancelled) }

        await #expect(throws: CancellationError.self) {
            let _: MailboxState = try await client.get(CookieAPIEndpoints.mailboxState)
        }
    }

    @Test func endpointWithoutURLThrowsInvalidRequest() async {
        let log = CallLog()
        let client = makeClient([StubResponse(status: 200, body: "{}")], log: log)

        await #expect(throws: APIError.invalidRequest) {
            let _: MailboxState = try await client.get(Endpoint(host: "example.com", path: "no-slash"))
        }
        #expect(await log.requests.isEmpty)
    }
}
