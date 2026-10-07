import SwiftUI

/// The reply box pinned above the keyboard, from the design's detail screen.
struct ReplyComposer: View {
    @Bindable var detail: EmailDetail
    var focused: FocusState<Bool>.Binding

    private var canSend: Bool {
        detail.reply != .sending && detail.email.canReply
            && !detail.replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 8) {
            if !detail.email.canReply {
                Text("No recipient")
                    .font(CookieFont.text(.regular, size: 14, relativeTo: .footnote))
                    .foregroundStyle(Color(.secondaryText))
            } else if detail.reply == .failed {
                Text("Couldn't send. Try again.")
                    .font(CookieFont.text(.regular, size: 14, relativeTo: .footnote))
                    .foregroundStyle(.red)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(
                    "Reply to \(detail.replyRecipientDisplayName)", text: $detail.replyText, axis: .vertical
                )
                .lineLimit(1...5)
                .font(CookieFont.text(.regular, size: 17, relativeTo: .body))
                .foregroundStyle(Color(.primaryText))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color(.surface), in: .rect(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color(.hairline)))
                .focused(focused)
                .disabled(detail.reply == .sending)
                .accessibilityIdentifier("replyText")
                .onKeyPress(.escape) {
                    detail.closeReply()
                    return .handled
                }
                Button {
                    Task { await detail.send() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(.surface))
                        .frame(width: 44, height: 44)
                        .background(canSend ? Color(.primaryText) : Color(.muted), in: .circle)
                }
                .disabled(!canSend)
                .accessibilityIdentifier("sendReply")
                .keyboardShortcut(.return, modifiers: .command)
                .accessibilityLabel("Send reply")
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background(Color(.surface))
        .overlay(alignment: .top) {
            Color(.hairline).frame(height: 1)
        }
    }
}
