import Foundation
import Testing

@testable import Cookie

struct EndpointTests {
    @Test func mailboxStatePinsOriginAndPath() {
        let url = CookieAPIEndpoints.mailboxState.url
        #expect(url?.absoluteString == "https://emails-api.infinitywave.online/emails/state")
    }

    @Test func pathWithoutLeadingSlashHasNoURL() {
        #expect(Endpoint(host: "example.com", path: "emails").url == nil)
    }
}
