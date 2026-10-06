import SwiftUI

/// The signed-in screen: the design's header over the inbox.
struct HomeView: View {
    let profile: UserProfile
    let client: APIClient
    let signOut: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            InboxView(client: client)
        }
        .background(Color(.surface))
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
