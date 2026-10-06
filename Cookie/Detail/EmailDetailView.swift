import SwiftUI

/// The design's email detail screen: subject, sender, body, and reply.
struct EmailDetailView: View {
    @State private var detail: EmailDetail
    @State private var bodyHeight: CGFloat = 44
    @FocusState private var replyFocused: Bool

    init(email: EmailSummary, client: APIClient, mailbox: Mailbox) {
        _detail = State(initialValue: EmailDetail(email: email, client: client, mailbox: mailbox))
    }

    private var email: EmailSummary { detail.email }

    private var isComposerShown: Bool {
        switch detail.reply {
        case .composing, .sending, .failed: true
        case .closed, .sent: false
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(email.subject ?? String(localized: "(No subject)"))
                    .font(CookieFont.text(.bold, size: 28, relativeTo: .title))
                    .foregroundStyle(Color(.primaryText))
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                Color(.hairline).frame(height: 1)
                sender
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                bodySection
                    .padding(.horizontal, 20)
                replyDivider
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                if detail.reply == .sent {
                    Text("Reply sent to \(email.senderName).")
                        .font(CookieFont.text(.regular, size: 14, relativeTo: .footnote))
                        .foregroundStyle(Color(.tagSageText))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                Spacer(minLength: 48)
            }
        }
        .background(Color(.surface))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if isComposerShown {
                ReplyComposer(detail: detail, focused: $replyFocused)
            }
        }
        .task {
            await detail.load()
        }
    }

    private var sender: some View {
        let tone = AvatarTone.index(for: email.senderName)
        return HStack(alignment: .top, spacing: 12) {
            Text(email.senderName.prefix(1).uppercased())
                .font(CookieFont.text(.semibold, size: 16, relativeTo: .body))
                .foregroundStyle(Color(EmailRow.avatarText[tone]))
                .frame(width: 40, height: 40)
                .background(Color(EmailRow.avatarBackground[tone]), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(email.senderName)
                    .font(CookieFont.text(.semibold, size: 17, relativeTo: .body))
                    .foregroundStyle(Color(.primaryText))
                    .lineLimit(1)
                Text("to me")
                    .font(CookieFont.text(.regular, size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color(.secondaryText))
            }
            Spacer()
            Text(RelativeSentTime.string(for: email.sentAt))
                .font(CookieFont.mono(size: 12, relativeTo: .caption))
                .foregroundStyle(Color(.secondaryText))
                .padding(.top, 3)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var bodySection: some View {
        switch detail.body {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        case .failed:
            VStack(spacing: 12) {
                Text("Message unavailable")
                    .font(CookieFont.text(.semibold, size: 17, relativeTo: .body))
                Text("Check your connection and try again.")
                    .font(CookieFont.text(.regular, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color(.secondaryText))
                Button("Retry") {
                    Task { await detail.load() }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        case .loaded(let message):
            if let html = message.bodyHtml, !html.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    if !detail.showsRemoteImages, EmailBodyView.hasBlockedRemoteContent(html) {
                        Button("Show images", systemImage: "photo") {
                            detail.showRemoteImages()
                        }
                        .buttonStyle(.bordered)
                    }
                    EmailBodyView(
                        html: html, blocksRemoteContent: !detail.showsRemoteImages, contentHeight: $bodyHeight
                    )
                    .frame(height: bodyHeight)
                }
            } else {
                Text(message.bodyText ?? "")
                    .font(CookieFont.text(.regular, size: 17, relativeTo: .body))
                    .foregroundStyle(Color(.primaryText))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var replyDivider: some View {
        let open = isComposerShown
        return HStack(spacing: 12) {
            Color(.hairline).frame(height: 1)
            Button {
                if open {
                    detail.closeReply()
                } else {
                    detail.openReply()
                    replyFocused = true
                }
            } label: {
                Image(systemName: "arrowshape.turn.up.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(open ? Color(.surface) : Color(.primaryText))
                    .frame(width: 44, height: 44)
                    .background(open ? Color(.primaryText) : Color(.surface), in: .circle)
                    .overlay(Circle().strokeBorder(open ? Color(.primaryText) : Color(.hairline)))
            }
            .accessibilityLabel(Text("Reply to \(email.senderName)"))
            .accessibilityAddTraits(open ? [.isSelected] : [])
            Color(.hairline).frame(height: 1)
        }
    }
}

#if DEBUG
    @MainActor
    private func previewDetail(bodyHTML: String?, bodyText: String?, status: Int = 200) -> some View {
        let tokens = TokenProvider(current: { "preview" }, renewed: { "preview" }, invalidate: {})
        let html = bodyHTML.map { "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" } ?? "null"
        let text = bodyText.map { "\"\($0)\"" } ?? "null"
        let client = APIClient(tokens: tokens) { request in
            guard let url = request.url,
                let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
            else { throw URLError(.badURL) }
            return (Data(#"{"id":"1","body_html":\#(html),"body_text":\#(text)}"#.utf8), response)
        }
        return NavigationStack {
            EmailDetailView(email: InboxPreviewData.emails[0], client: client, mailbox: Mailbox(client: client))
        }
    }

    #Preview("HTML body") {
        previewDetail(
            bodyHTML: "<p>Hi Allister,</p><p>We've outlined the final terms below.</p><h2>Key terms</h2>"
                + "<ul><li>Lead investor takes one board seat.</li><li>Option pool topped up to 12%.</li></ul>"
                + "<img src='https://example.com/pixel.gif' width='1' height='1'>",
            bodyText: "Hi Allister")
    }

    #Preview("Text body") {
        previewDetail(bodyHTML: nil, bodyText: "Hi Allister,\n\nAre you both still coming on Sunday?\n\nMum")
    }

    #Preview("Failed") {
        previewDetail(bodyHTML: nil, bodyText: nil, status: 500)
    }
#endif
