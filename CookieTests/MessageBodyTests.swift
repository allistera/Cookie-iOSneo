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
