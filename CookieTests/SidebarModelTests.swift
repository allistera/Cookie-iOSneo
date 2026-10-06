import Foundation
import SwiftUI
import Testing

@testable import Cookie

private let draftJSON =
    #"{"drafts":[{"id":"d1","to":null,"subject":null,"preview":null,"#
    + #""updatedAt":"2026-10-05T10:02:00Z"}]}"#

@MainActor
private func makeSidebar(labelsStatus: Int = 200, draftsStatus: Int = 200) -> SidebarModel {
    let tokens = TokenProvider(current: { "t" }, renewed: { "t" }, invalidate: {})
    let client = APIClient(tokens: tokens) { request in
        guard let url = request.url else { throw URLError(.badURL) }
        let (status, body): (Int, String) =
            switch url.path {
            case "/labels": (labelsStatus, #"{"labels":[{"id":"l1","name":"Work","color":null}]}"#)
            case "/drafts": (draftsStatus, draftJSON)
            default: (404, "{}")
            }
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else {
            throw URLError(.badURL)
        }
        return (Data(body.utf8), response)
    }
    return SidebarModel(client: client)
}

@MainActor
struct SidebarModelTests {
    @Test func startsClosedOnInboxWithMoreExpanded() {
        let sidebar = makeSidebar()
        #expect(!sidebar.isOpen)
        #expect(sidebar.showsMore)
        #expect(sidebar.selection == .folder(.inbox))
    }

    @Test func loadListsFillsLabelsAndDrafts() async {
        let sidebar = makeSidebar()
        await sidebar.loadLists()
        #expect(sidebar.labels.map(\.name) == ["Work"])
        #expect(sidebar.drafts.map(\.id) == ["d1"])
        #expect(!sidebar.labelsFailed)
        #expect(!sidebar.draftsFailed)
    }

    @Test func eachFailureAffectsOnlyItsSection() async {
        let sidebar = makeSidebar(labelsStatus: 500)
        await sidebar.loadLists()
        #expect(sidebar.labelsFailed)
        #expect(sidebar.labels.isEmpty)
        #expect(!sidebar.draftsFailed)
        #expect(sidebar.drafts.count == 1)
    }

    @Test func selectClosesTheDrawer() {
        let sidebar = makeSidebar()
        sidebar.open()
        #expect(sidebar.isOpen)
        sidebar.select(.drafts)
        #expect(!sidebar.isOpen)
        #expect(sidebar.selection == .drafts)
    }

    @Test func drawerWidthRule() {
        #expect(DrawerContainer<EmptyView, EmptyView>.width(for: 390) == 320)
        #expect(DrawerContainer<EmptyView, EmptyView>.width(for: 360) == 312)
    }
}
