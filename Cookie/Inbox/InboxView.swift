import SwiftUI

/// The inbox: category tabs over swipeable pages of rows.
struct InboxView: View {
    let inbox: Inbox
    @State private var selection = InboxTab.importantID

    var body: some View {
        content
            .task {
                await inbox.refresh()
            }
            .onChange(of: inbox.tabs.map(\.id)) { _, ids in
                if !ids.contains(selection), let first = ids.first {
                    selection = first
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch inbox.phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            ContentUnavailableView {
                Label("Inbox unavailable", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Retry") {
                    Task { await inbox.refresh() }
                }
                .buttonStyle(.borderedProminent)
            }
        case .loaded:
            let tabs = inbox.tabs
            VStack(spacing: 0) {
                InboxTabStrip(tabs: tabs, selection: $selection)
                TabView(selection: $selection) {
                    ForEach(tabs) { tab in
                        InboxPageView(tab: tab, inbox: inbox)
                            .tag(tab.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
    }
}

#if DEBUG
    #Preview("Populated") {
        InboxView(inbox: Inbox(client: InboxPreviewData.client(emailsStatus: 200)))
    }

    #Preview("Failed") {
        InboxView(inbox: Inbox(client: InboxPreviewData.client(emailsStatus: 500)))
    }
#endif
