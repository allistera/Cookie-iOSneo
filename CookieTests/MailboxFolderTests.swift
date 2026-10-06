import Foundation
import Testing

@testable import Cookie

struct MailboxFolderTests {
    @Test func queryItemsNameEachFolder() {
        let folders: [(MailboxFolder, String)] = [
            (.inbox, "inbox"), (.screening, "screening"), (.done, "done"), (.sent, "sent"), (.spam, "spam"),
            (.blocked, "blocked"),
        ]
        for (folder, name) in folders {
            #expect(folder.queryItems == [URLQueryItem(name: "folder", value: name)])
        }
        #expect(
            MailboxFolder.label("Work").queryItems
                == [URLQueryItem(name: "folder", value: "label"), URLQueryItem(name: "label", value: "Work")])
    }

    @Test func titlesAreNonEmptyAndLabelsUseTheirName() {
        for folder in [MailboxFolder.inbox, .screening, .done, .sent, .spam, .blocked] {
            #expect(!folder.title.isEmpty)
        }
        #expect(MailboxFolder.label("Work").title == "Work")
    }
}
