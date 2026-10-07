import SwiftUI

/// Opens an email cited by AI Today: loads the body once, resolves mailbox
/// metadata when needed, then shows the normal detail screen.
struct EmailReferenceView: View {
    let item: TriageItem
    let client: APIClient
    let mailbox: Mailbox
    let today: TodayModel

    private enum Phase: Equatable {
        case loading
        case found(EmailSummary, MessageBody, Bool?)
        case metadataUnavailable(MessageBody)
        case failed
    }

    @State private var phase: Phase = .loading
    @State private var cachedBody: MessageBody?

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .found(let email, let body, let isInboxMessage):
                EmailDetailView(
                    email: email,
                    client: client,
                    mailbox: mailbox,
                    initialBody: body,
                    isInboxMessage: isInboxMessage,
                    onMarkedRead: { messageID in
                        today.markRead(messageID)
                    })
            case .metadataUnavailable(let body):
                VStack(spacing: 0) {
                    MetadataUnavailableBodyView(message: body)
                    Button("Retry sender details") {
                        phase = .loading
                    }
                    .buttonStyle(.bordered)
                    .padding(.vertical, 12)
                }
            case .failed:
                ContentUnavailableView {
                    Label("Message unavailable", systemImage: "envelope.open")
                } description: {
                    Text("Check your connection and try again.")
                } actions: {
                    retryButton
                }
            }
        }
        .background(Color(.surface))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.visible, for: .navigationBar)
        .task(id: phase == .loading) {
            guard phase == .loading else { return }
            await resolve()
        }
    }

    @MainActor
    private func resolve() async {
        do {
            let body: MessageBody
            if let cachedBody {
                body = cachedBody
            } else {
                let fetched: MessageBody = try await client.get(CookieAPIEndpoints.message(id: item.messageId))
                cachedBody = fetched
                body = fetched
            }
            let resolution = try await EmailReference.resolve(
                for: item.messageId, unread: item.unread, from: body, mailbox: mailbox, client: client)
            switch resolution {
            case .found(let email, let resolvedBody, let isInboxMessage):
                phase = .found(email, resolvedBody, isInboxMessage)
            case .metadataUnavailable(let resolvedBody):
                phase = .metadataUnavailable(resolvedBody)
            }
        } catch is CancellationError {
            return
        } catch {
            phase = .failed
        }
    }

    private var retryButton: some View {
        Button("Retry") {
            phase = .loading
        }
        .buttonStyle(.bordered)
    }
}

/// Displays a safely fetched message body while mailbox sender/date metadata is
/// being recovered. It deliberately has no sender header, date, or reply action.
private struct MetadataUnavailableBodyView: View {
    let message: MessageBody

    @ScaledMetric(relativeTo: .body) private var bodyFontSize: CGFloat = 17
    @State private var bodyHeight: CGFloat = 44
    @State private var showsRemoteImages = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(subject)
                    .font(CookieFont.text(.bold, size: 28, relativeTo: .title))
                    .foregroundStyle(Color(.primaryText))
                Text("Sender details unavailable")
                    .font(CookieFont.text(.semibold, size: 17, relativeTo: .body))
                    .foregroundStyle(Color(.primaryText))
                Text("Cookie loaded the message body, but sender and date details are unavailable.")
                    .font(CookieFont.text(.regular, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color(.secondaryText))
                Color(.hairline).frame(height: 1)
                content
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .padding(.bottom, 24)
        }
        .background(Color(.surface))
    }

    private var subject: String {
        guard let subject = message.subject?.trimmingCharacters(in: .whitespacesAndNewlines), !subject.isEmpty else {
            return String(localized: "(No subject)")
        }
        return subject
    }

    @ViewBuilder private var content: some View {
        if let html = message.bodyHtml, !html.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if !showsRemoteImages {
                    Button("Show images", systemImage: "photo") {
                        showsRemoteImages = true
                    }
                    .buttonStyle(.bordered)
                }
                EmailBodyView(
                    html: html,
                    blocksRemoteContent: !showsRemoteImages,
                    baseFontSize: bodyFontSize,
                    contentHeight: $bodyHeight
                )
                .frame(height: bodyHeight)
            }
        } else if let text = message.bodyText, !text.isEmpty {
            Text(text)
                .font(CookieFont.text(.regular, size: 17, relativeTo: .body))
                .foregroundStyle(Color(.primaryText))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ContentUnavailableView {
                Label("No message content", systemImage: "doc.text")
            }
        }
    }
}
