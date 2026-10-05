import Foundation
import Testing

@testable import Cookie

struct MailboxStateTests {
    @Test func decodesUnreadCountAndIgnoresOtherFields() throws {
        let json = """
            {"unreadCount":3,"spamCount":0,"snoozedCount":1,"scheduledCount":0,"starredCount":2,
             "screeningCount":0,"blockedCount":0,"userId":"6f1c2f0e-8a54-4d0c-9a59-2f5f4c1f7f10"}
            """
        let state = try JSONDecoder().decode(MailboxState.self, from: Data(json.utf8))
        #expect(state == MailboxState(unreadCount: 3))
    }
}
