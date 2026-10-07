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
    private let isInboxMessage: Bool
    private let onMarkedRead: @MainActor (String) -> Void
    private var draft: ReplyDraft?
    private var hasMarkedRead = false
    private var markReadInFlight = false
    private var inFlightSend: SendRequest?
    private var pendingSend: PendingSend?
    private static let logger = Logger(subsystem: "com.cookie.ios", category: "detail")

    private struct PendingSend: Equatable, Sendable {
        let request: SendRequest
        let normalizedText: String
        let editorText: String
    }

    init(
        email: EmailSummary, client: APIClient, mailbox: Mailbox, initialBody: MessageBody? = nil,
        isInboxMessage: Bool? = nil, onMarkedRead: @escaping @MainActor (String) -> Void = { _ in }
    ) {
        self.email = email
        body = initialBody.map(BodyPhase.loaded) ?? .loading
        self.client = client
        self.mailbox = mailbox
        self.isInboxMessage = isInboxMessage ?? (mailbox.folder == .inbox && !email.isSent)
        self.onMarkedRead = onMarkedRead
    }

    var replyRecipientDisplayName: String {
        email.replyRecipientDisplayName
    }

    /// Fetches the body and marks an unread message after the PATCH succeeds.
    /// The two requests run concurrently so the body can render without waiting
    /// for the mailbox mutation. An injected body is already fetched and avoids
    /// issuing a duplicate GET.
    func load() async {
        let markReadTask = Task { @MainActor [weak self] in
            await self?.markReadIfNeeded()
        }

        if case .loaded = body {
            await markReadTask.value
            return
        }

        body = .loading
        do {
            body = .loaded(try await client.get(CookieAPIEndpoints.message(id: email.id)))
        } catch is CancellationError {
            markReadTask.cancel()
            await markReadTask.value
            return
        } catch {
            body = .failed
        }

        await markReadTask.value
    }

    private func markReadIfNeeded() async {
        guard email.isUnread, !hasMarkedRead, !markReadInFlight else { return }
        markReadInFlight = true
        defer { markReadInFlight = false }
        do {
            let _: EmptyResponse = try await client.patch(
                CookieAPIEndpoints.messages, body: MarkReadRequest(id: email.id, isUnread: false))
            hasMarkedRead = true
            mailbox.markRead(email.id, wasUnread: email.isUnread, isInboxMessage: isInboxMessage)
            onMarkedRead(email.id)
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("Mark read failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    func showRemoteImages() {
        showsRemoteImages = true
    }

    func openReply() {
        guard inFlightSend == nil, email.canReply else { return }
        if draft == nil { draft = ReplyDraft() }
        reply = .composing
    }

    func closeReply() {
        guard inFlightSend == nil else { return }
        reply = .closed
    }

    func send() async {
        guard inFlightSend == nil, email.canReply, reply == .composing || reply == .failed else { return }
        let editorText = replyText
        let text = editorText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let currentDraft = draft else { return }

        reply = .sending
        var bodyText: String?
        if case .loaded(let loaded) = body { bodyText = loaded.bodyText }
        let request: SendRequest
        if let pendingSend, pendingSend.normalizedText == text, pendingSend.editorText == editorText {
            request = pendingSend.request
        } else {
            if pendingSend != nil { draft = ReplyDraft() }
            let attemptDraft = draft ?? currentDraft
            guard
                let builtRequest = attemptDraft.request(
                    replyText: text, original: email, bodyText: bodyText)
            else {
                reply = .composing
                return
            }
            request = builtRequest
            self.pendingSend = PendingSend(request: request, normalizedText: text, editorText: editorText)
        }
        inFlightSend = request

        do {
            let _: EmptyResponse = try await client.post(CookieAPIEndpoints.send, body: request, encoder: JSONEncoder())
            inFlightSend = nil
            pendingSend = nil
            if replyText == editorText {
                replyText = ""
                draft = nil
                reply = .sent
            } else {
                // Keep edits made while the request was in flight. A new draft
                // gets a fresh idempotency key for that distinct payload.
                draft = ReplyDraft()
                reply = .composing
            }
        } catch is CancellationError {
            inFlightSend = nil
            reply = .composing
        } catch {
            inFlightSend = nil
            Self.logger.error("Send failed: \(String(describing: type(of: error)), privacy: .public)")
            reply = .failed
        }
    }
}
