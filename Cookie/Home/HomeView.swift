import SwiftUI

/// The signed-in screen for this sub-project: the design's header, and the
/// unread count from `GET /emails/state` as proof that authenticated API
/// calls work. The inbox replaces the body in the next sub-project.
struct HomeView: View {
    let profile: UserProfile
    let client: APIClient
    let signOut: () async -> Void

    private enum Phase: Equatable {
        case loading
        case loaded(MailboxState)
        case failed
    }

    @State private var phase: Phase = .loading
    @State private var attempt = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.surface))
        .task(id: attempt) {
            await load()
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

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            ProgressView()
        case .loaded(let state):
            Text("\(state.unreadCount) unread")
                .font(CookieFont.mono(size: 17, relativeTo: .body))
                .foregroundStyle(Color(.primaryText))
        case .failed:
            ContentUnavailableView {
                Label("Mailbox unavailable", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Retry") { attempt += 1 }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func load() async {
        phase = .loading
        do {
            phase = .loaded(try await client.get(CookieAPIEndpoints.mailboxState))
        } catch is CancellationError {
            // The view went away or a retry superseded this request.
        } catch {
            phase = .failed
        }
    }
}

#if DEBUG
    private func previewClient(status: Int, body: String) -> APIClient {
        let tokens = TokenProvider(current: { "preview" }, renewed: { "preview" }, invalidate: {})
        return APIClient(tokens: tokens) { request in
            guard let url = request.url,
                let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
            else { throw URLError(.badURL) }
            return (Data(body.utf8), response)
        }
    }

    #Preview("Loaded") {
        HomeView(
            profile: UserProfile(name: "Allister", email: "allister@example.com"),
            client: previewClient(status: 200, body: #"{"unreadCount":3}"#),
            signOut: {}
        )
    }

    #Preview("Failed") {
        HomeView(
            profile: UserProfile(name: "Allister", email: nil),
            client: previewClient(status: 500, body: "{}"),
            signOut: {}
        )
    }
#endif
