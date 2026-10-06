import Foundation
import Testing

@testable import Cookie

struct SidebarModelsTests {
    @Test func decodesLabels() throws {
        let json = """
            {"labels":[{"id":"l1","name":"Newsletters","color":"#B3792A","kind":"user","description":null,
            "auto_apply":true,"message_count":12},{"id":"l2","name":"Work","color":null}]}
            """
        let list = try JSONDecoder.cookieAPI().decode(LabelList.self, from: Data(json.utf8))
        #expect(
            list.labels == [
                MailLabel(id: "l1", name: "Newsletters", color: "#B3792A"),
                MailLabel(id: "l2", name: "Work", color: nil),
            ])
    }

    @Test func decodesDrafts() throws {
        let json = """
            {"drafts":[{"id":"d1","to":"jordan@example.com","subject":"Re: terms","preview":"Thanks",
            "replyToMessageId":"6f1c","updatedAt":"2026-10-05T09:48:12.345Z","isAiGenerated":false,
            "isSummary":true,"attachmentCount":0},{"id":"d2","to":null,"subject":null,"preview":null,
            "replyToMessageId":null,"updatedAt":"2026-10-04T18:02:11Z"}]}
            """
        let list = try JSONDecoder.cookieAPI().decode(DraftList.self, from: Data(json.utf8))
        #expect(list.drafts.count == 2)
        #expect(list.drafts.first?.recipients == "jordan@example.com")
        #expect(list.drafts.first?.subject == "Re: terms")
        #expect(list.drafts.last?.recipients == nil)
        #expect(list.drafts.last?.updatedAt == Date(timeIntervalSince1970: 1_791_136_931))
    }
}
