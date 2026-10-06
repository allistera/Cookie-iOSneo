import SwiftUI

/// One inbox row: avatar, sender, time, subject, snippet and first label.
struct EmailRow: View {
    let email: EmailSummary
    var now: Date = .now

    private var weight: CookieFont.Weight { email.isUnread ? .semibold : .regular }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 6) {
                    Text(email.senderName)
                        .font(CookieFont.text(weight, size: 17, relativeTo: .body))
                        .foregroundStyle(Color(.primaryText))
                        .lineLimit(1)
                    if email.isUnread {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                            .accessibilityLabel("Unread")
                    }
                    Spacer(minLength: 4)
                    Text(RelativeSentTime.string(for: email.sentAt, now: now))
                        .font(CookieFont.mono(size: 12, relativeTo: .caption))
                        .foregroundStyle(Color(.secondaryText))
                }
                Text(email.subject ?? String(localized: "(No subject)"))
                    .font(CookieFont.text(weight, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color(.primaryText))
                    .lineLimit(1)
                if let snippet = email.snippet, !snippet.isEmpty {
                    Text(snippet)
                        .font(CookieFont.text(.regular, size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Color(.secondaryText))
                        .lineLimit(2)
                }
                if let label = email.labels.first {
                    Text(label.name)
                        .font(CookieFont.text(.semibold, size: 13, relativeTo: .footnote))
                        .foregroundStyle(Color(.tagSageText))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color(.tagSageBackground), in: .capsule)
                        .padding(.top, 3)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var avatar: some View {
        let tone = AvatarTone.index(for: email.senderName)
        return Text(email.senderName.prefix(1).uppercased())
            .font(CookieFont.text(.semibold, size: 16, relativeTo: .body))
            .foregroundStyle(Color(Self.avatarText[tone]))
            .frame(width: 40, height: 40)
            .background(Color(Self.avatarBackground[tone]), in: .circle)
            .accessibilityHidden(true)
    }

    /// Indexed by `AvatarTone.index`, which is tested to stay within `0..<6`.
    static let avatarBackground: [ColorResource] = [
        .avatar1Background, .avatar2Background, .avatar3Background,
        .avatar4Background, .avatar5Background, .avatar6Background,
    ]
    static let avatarText: [ColorResource] = [
        .avatar1Text, .avatar2Text, .avatar3Text, .avatar4Text, .avatar5Text, .avatar6Text,
    ]
}

#if DEBUG
    #Preview {
        List {
            ForEach(InboxPreviewData.emails) { EmailRow(email: $0, now: InboxPreviewData.now) }
        }
        .listStyle(.plain)
    }
#endif
