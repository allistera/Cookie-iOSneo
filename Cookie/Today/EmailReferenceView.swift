import SwiftUI

/// Opens an email cited by AI Today: loads the body once to learn its
/// sender and subject, then shows the normal detail screen.
struct EmailReferenceView: View {
    let item: TriageItem
    let client: APIClient
    let mailbox: Mailbox
    let today: TodayModel

    private enum Phase: Equatable {
        case loading
        case found(EmailSummary)
        case missing
    }

    @State private var phase: Phase = .loading

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .found(let email):
                EmailDetailView(email: email, client: client, mailbox: mailbox)
            case .missing:
                ContentUnavailableView {
                    Label("Message unavailable", systemImage: "envelope.open")
                } description: {
                    Text("Check your connection and try again.")
                } actions: {
                    Button("Retry") {
                        phase = .loading
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .background(Color(.surface))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: phase == .loading) {
            guard phase == .loading else { return }
            await resolve()
        }
    }

    private func resolve() async {
        do {
            let body: MessageBody = try await client.get(CookieAPIEndpoints.message(id: item.messageId))
            if let email = EmailReference.summary(for: item.messageId, unread: item.unread, from: body) {
                today.markRead(item.messageId)
                phase = .found(email)
            } else {
                phase = .missing
            }
        } catch is CancellationError {
            return
        } catch {
            phase = .missing
        }
    }
}
