import Foundation
import Testing

@testable import Cookie

struct EndpointTests {
    @Test func inboxFirstPagePinsOriginAndQuery() {
        let url = CookieAPIEndpoints.inbox(before: nil).url
        #expect(url?.absoluteString == "https://emails-api.infinitywave.online/emails?folder=inbox&limit=50")
    }

    @Test func inboxLaterPageCarriesEncodedCursor() {
        let url = CookieAPIEndpoints.inbox(before: "2026-10-04T18:02:11.120000Z|6f1c", limit: 10).url
        #expect(
            url?.absoluteString
                == "https://emails-api.infinitywave.online/emails?folder=inbox&limit=10"
                + "&before=2026-10-04T18:02:11.120000Z%7C6f1c"
        )
    }

    @Test func categoriesPinsOriginAndPath() {
        #expect(
            CookieAPIEndpoints.categories.url?.absoluteString == "https://labels-api.infinitywave.online/categories")
    }

    @Test func pathWithoutLeadingSlashHasNoURL() {
        #expect(Endpoint(host: "example.com", path: "emails").url == nil)
    }

    @Test func messageBodyPinsOriginAndQuery() {
        let url = CookieAPIEndpoints.message(id: "6f1c").url
        #expect(url?.absoluteString == "https://messages-api.infinitywave.online/messages?id=6f1c&calendar=deferred")
    }

    @Test func messagesAndSendPinOrigins() {
        #expect(CookieAPIEndpoints.messages.url?.absoluteString == "https://messages-api.infinitywave.online/messages")
        #expect(CookieAPIEndpoints.send.url?.absoluteString == "https://send-api.infinitywave.online/send")
    }
}
