import SwiftUI

/// The signed-in screen: the design's header over the selected folder or
/// Drafts, with email detail on a native navigation stack and the sidebar
/// drawer around everything.
struct HomeView: View {
    let profile: UserProfile
    let client: APIClient
    let signOut: () async -> Void

    @State private var mailbox: Mailbox
    @State private var sidebar: SidebarModel
    @State private var today: TodayModel
    @AccessibilityFocusState private var headerButtonFocused: Bool

    init(profile: UserProfile, client: APIClient, signOut: @escaping () async -> Void) {
        self.profile = profile
        self.client = client
        self.signOut = signOut
        _mailbox = State(initialValue: Mailbox(client: client))
        _sidebar = State(initialValue: SidebarModel(client: client))
        _today = State(initialValue: TodayModel(client: client))
    }

    var body: some View {
        DrawerContainer(isOpen: $sidebar.isOpen) {
            SidebarView(sidebar: sidebar, unreadCount: mailbox.unreadCount) { selection in
                select(selection)
            }
        } content: {
            NavigationStack {
                VStack(spacing: 0) {
                    header
                    switch sidebar.selection {
                    case .today:
                        TodayView(today: today)
                    case .folder:
                        MailboxView(mailbox: mailbox)
                    case .drafts:
                        DraftsView(sidebar: sidebar)
                    }
                }
                .background(Color(.surface))
                .toolbarVisibility(.hidden, for: .navigationBar)
                .navigationDestination(for: EmailSummary.self) { email in
                    EmailDetailView(email: email, client: client, mailbox: mailbox, onMarkedRead: today.markRead)
                }
                .navigationDestination(for: TriageItem.self) { item in
                    EmailReferenceView(item: item, client: client, mailbox: mailbox, today: today)
                }
            }
        }
        .onChange(of: sidebar.isOpen) { _, open in
            if !open { headerButtonFocused = true }
        }
    }

    private func select(_ selection: SidebarSelection) {
        sidebar.select(selection)
        if case .folder(let folder) = selection {
            Task { await mailbox.select(folder) }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                sidebar.open()
            } label: {
                HStack(spacing: 10) {
                    Image(.logo)
                        .resizable()
                        .frame(width: 34, height: 34)
                        .clipShape(.rect(cornerRadius: 9))
                    Text("Cookie")
                        .font(CookieFont.text(.bold, size: 21, relativeTo: .title3))
                        .foregroundStyle(Color(.primaryText))
                    Text("Email")
                        .font(CookieFont.text(.regular, size: 21, relativeTo: .title3))
                        .foregroundStyle(Color(.secondaryText))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(.secondaryText))
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open sidebar")
            .accessibilityIdentifier("openSidebar")
            .accessibilityValue(sidebar.isOpen ? Text("Expanded") : Text("Collapsed"))
            .accessibilityFocused($headerButtonFocused)
            Spacer()
            AccountMenu(profile: profile, signOut: signOut)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

#if DEBUG
    #Preview {
        HomeView(
            profile: UserProfile(name: "Allister", email: "allister@example.com"),
            client: InboxPreviewData.client(emailsStatus: 200),
            signOut: {}
        )
    }
#endif
