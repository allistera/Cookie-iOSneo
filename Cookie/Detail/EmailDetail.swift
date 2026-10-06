import Foundation
import OSLog
import Observation

/// One open email: its body, read state and reply.
@MainActor
@Observable
final class EmailDetail {
    enum BodyPhase: Equatable {
        case loading
        case loaded(MessageBody)
        case failed
    }

    enum ReplyPhase: Equatable {
        case closed
        case composing
        case sending
        case sent
        case failed
    }

    let email: EmailSummary
    private(set) var body: BodyPhase = .loading
    private(set) var reply: ReplyPhase = .closed
    var replyText = ""
    private(set) var showsRemoteImages = false

    private let client: APIClient
    private let mailbox: Mailbox
    private var draft: ReplyDraft?
    private var hasMarkedRead = false
    private static let logger = Logger(subsystem: "com.cookie.ios", category: "detail")

    init(email: EmailSummary, client: APIClient, mailbox: Mailbox) {
        self.email = email
        self.client = client
        self.mailbox = mailbox
    }

    /// Fetches the body and, on first open of an unread email, marks it read.
    func load() async {
        body = .loading
        let needsMarkRead = !hasMarkedRead && email.isUnread
        hasMarkedRead = true
        if needsMarkRead { mailbox.markRead(email.id) }
        do {
            async let fetched: MessageBody = client.get(CookieAPIEndpoints.message(id: email.id))
            if needsMarkRead { await markRead() }
            body = .loaded(try await fetched)
        } catch is CancellationError {
            return
        } catch {
            body = .failed
        }
    }

    private func markRead() async {
        do {
            let _: EmptyResponse = try await client.patch(
                CookieAPIEndpoints.messages, body: MarkReadRequest(id: email.id, isUnread: false))
        } catch is CancellationError {
            mailbox.markUnread(email.id)
        } catch {
            Self.logger.error("Mark read failed: \(String(describing: type(of: error)), privacy: .public)")
            mailbox.markUnread(email.id)
        }
    }

    func showRemoteImages() {
        showsRemoteImages = true
    }

    func openReply() {
        if draft == nil { draft = ReplyDraft() }
        reply = .composing
    }

    func closeReply() {
        reply = .closed
    }

    func send() async {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let draft, reply != .sending else { return }
        reply = .sending
        var bodyText: String?
        if case .loaded(let loaded) = body { bodyText = loaded.bodyText }
        let request = draft.request(replyText: text, original: email, bodyText: bodyText)
        do {
            let _: EmptyResponse = try await client.post(CookieAPIEndpoints.send, body: request, encoder: JSONEncoder())
            replyText = ""
            self.draft = nil
            reply = .sent
        } catch is CancellationError {
            reply = .composing
        } catch {
            Self.logger.error("Send failed: \(String(describing: type(of: error)), privacy: .public)")
            reply = .failed
        }
    }
}
