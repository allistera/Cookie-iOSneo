import Foundation

/// A reply in progress. The request id is fixed for the draft's life so a
/// retried send is deduplicated by the Worker.
struct ReplyDraft: Equatable, Sendable {
    let requestID: String

    init(requestID: String = UUID().uuidString) {
        self.requestID = requestID
    }

    /// "Re: " before the original subject unless it already carries one.
    static func subject(replyingTo subject: String?) -> String {
        let trimmed = subject?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let base = trimmed.isEmpty ? String(localized: "(No subject)") : trimmed
        return base.lowercased().hasPrefix("re:") ? base : "Re: \(base)"
    }

    /// The original's plain text quoted below the reply, or empty when there is none.
    static func quotedText(
        original: EmailSummary, bodyText: String?, locale: Locale = .current, calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> String {
        guard let bodyText, !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        let date = original.sentAt.formatted(
            Date.FormatStyle(
                date: .abbreviated, time: .shortened, locale: locale, calendar: calendar, timeZone: timeZone))
        let header = String(localized: "On \(date), \(original.senderName) wrote:")
        let quoted = bodyText.split(separator: "\n", omittingEmptySubsequences: false)
            .map { "> \($0)" }
            .joined(separator: "\n")
        return "\n\n\(header)\n\(quoted)"
    }

    func request(replyText: String, original: EmailSummary, bodyText: String?) -> SendRequest {
        SendRequest(
            recipient: original.fromAddress,
            subject: Self.subject(replyingTo: original.subject),
            text: replyText + Self.quotedText(original: original, bodyText: bodyText),
            replyToMessageId: original.id,
            requestId: requestID)
    }
}
