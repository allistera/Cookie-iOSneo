import SwiftUI

/// The mailbox: category tabs over swipeable pages of rows.
struct MailboxView: View {
    let mailbox: Mailbox
    @State private var selection = InboxTab.importantID

    var body: some View {
        content
            .task {
                await mailbox.refresh()
            }
            .onChange(of: mailbox.tabs.map(\.id)) { _, ids in
                if !ids.contains(selection), let first = ids.first {
                    selection = first
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch mailbox.phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            ContentUnavailableView {
                Label("Mailbox unavailable", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Retry") {
                    Task { await mailbox.refresh() }
                }
                .buttonStyle(.borderedProminent)
            }
        case .loaded:
            let tabs = mailbox.tabs
            VStack(spacing: 0) {
                InboxTabStrip(tabs: tabs, selection: $selection)
                TabView(selection: $selection) {
                    ForEach(tabs) { tab in
                        InboxPageView(tab: tab, mailbox: mailbox)
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
        MailboxView(mailbox: Mailbox(client: InboxPreviewData.client(emailsStatus: 200)))
    }

    #Preview("Failed") {
        MailboxView(mailbox: Mailbox(client: InboxPreviewData.client(emailsStatus: 500)))
    }
#endif
