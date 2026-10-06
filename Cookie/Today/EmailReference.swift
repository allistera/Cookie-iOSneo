/// Builds the row the detail screen needs from a message id alone, using the
/// body endpoint's subject and the thread row for that message.
enum EmailReference {
    static func summary(for messageID: String, unread: Bool, from body: MessageBody) -> EmailSummary? {
        guard let row = body.thread.first(where: { $0.id == messageID }) else { return nil }
        return EmailSummary(
            id: messageID, fromName: row.fromName, fromAddress: row.fromAddress, subject: body.subject,
            snippet: row.snippet, sentAt: row.sentAt, isUnread: unread, priority: nil, labels: [], category: nil)
    }
}
