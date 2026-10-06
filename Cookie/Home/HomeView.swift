import SwiftUI

/// The signed-in screen: the design's header over the inbox, with email
/// detail pushed on a native navigation stack.
struct HomeView: View {
    let profile: UserProfile
    let client: APIClient
    let signOut: () async -> Void

    @State private var mailbox: Mailbox

    init(profile: UserProfile, client: APIClient, signOut: @escaping () async -> Void) {
        self.profile = profile
        self.client = client
        self.signOut = signOut
        _mailbox = State(initialValue: Mailbox(client: client))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                MailboxView(mailbox: mailbox)
            }
            .background(Color(.surface))
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: EmailSummary.self) { email in
                EmailDetailView(email: email, client: client, mailbox: mailbox)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(.logo)
                .resizable()
                .frame(width: 34, height: 34)
                .clipShape(.rect(cornerRadius: 9))
                .accessibilityHidden(true)
            Text("Cookie")
                .font(CookieFont.text(.bold, size: 21, relativeTo: .title3))
                .foregroundStyle(Color(.primaryText))
            Text("Email")
                .font(CookieFont.text(.regular, size: 21, relativeTo: .title3))
                .foregroundStyle(Color(.secondaryText))
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
