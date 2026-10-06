import SwiftUI

/// One category page: its rows, then Load more or the category's footer line.
struct InboxPageView: View {
    let tab: InboxTab
    let inbox: Inbox
    var now: Date = .now

    var body: some View {
        List {
            ForEach(tab.emails) { email in
                NavigationLink(value: email) {
                    EmailRow(email: email, now: now)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color(.surface))
                .listRowSeparatorTint(Color(.hairline))
            }
            footer
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .listRowSeparator(.hidden)
                .listRowBackground(Color(.surface))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.surface))
        .refreshable {
            await inbox.refresh()
        }
    }

    @ViewBuilder private var footer: some View {
        VStack(spacing: 12) {
            if inbox.refreshFailed {
                Text("Couldn't refresh. Pull down to try again.")
                    .foregroundStyle(Color(.secondaryText))
            }
            if inbox.nextCursor != nil {
                if inbox.loadMoreFailed {
                    Text("Couldn't load more.")
                        .foregroundStyle(Color(.secondaryText))
                }
                Button(inbox.loadMoreFailed ? "Retry" : "Load more") {
                    Task { await inbox.loadMore() }
                }
                .buttonStyle(.bordered)
                .disabled(inbox.isLoadingMore)
            } else if tab.isImportant {
                Text("That's everything important. Cookie's watching the rest.")
                    .foregroundStyle(Color(.secondaryText))
            } else {
                Text("You're all caught up.")
                    .foregroundStyle(Color(.secondaryText))
            }
        }
        .font(CookieFont.text(.regular, size: 14, relativeTo: .footnote))
        .multilineTextAlignment(.center)
    }
}
