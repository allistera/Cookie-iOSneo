import Foundation
import Observation

/// The AI Today screen's state: the stored triage and the refresh action.
@MainActor
@Observable
final class TodayModel {
    enum Phase: Equatable {
        case loading
        case loaded(TriageDigest)
        case empty
        case failed
    }

    enum RefreshState: Equatable {
        case idle
        case refreshing
        case rateLimited
        case failed
    }

    private(set) var phase: Phase = .loading
    private(set) var refreshState: RefreshState = .idle

    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    /// Reads the stored triage. A failure keeps an already shown digest.
    func load() async {
        if case .loaded = phase {} else { phase = .loading }
        do {
            let response: TodayResponse = try await client.get(CookieAPIEndpoints.tasks)
            phase = response.digest.map { .loaded($0) } ?? .empty
        } catch is CancellationError {
            return
        } catch {
            if case .loaded = phase { return }
            phase = .failed
        }
    }

    /// Asks the backend to rebuild the triage, then reloads it.
    func refresh() async {
        guard refreshState != .refreshing else { return }
        refreshState = .refreshing
        do {
            let _: EmptyResponse = try await client.post(CookieAPIEndpoints.tasksRefresh, body: EmptyBody())
            refreshState = .idle
            await load()
        } catch is CancellationError {
            refreshState = .idle
        } catch APIError.server(status: 429) {
            refreshState = .rateLimited
        } catch {
            refreshState = .failed
        }
    }

    /// Clears the unread marker on the cited item once its email is opened.
    func markRead(_ messageID: String) {
        guard case .loaded(var digest) = phase else { return }
        for topicIndex in digest.topics.indices {
            for itemIndex in digest.topics[topicIndex].items.indices
            where digest.topics[topicIndex].items[itemIndex].messageId == messageID {
                digest.topics[topicIndex].items[itemIndex].unread = false
            }
        }
        phase = .loaded(digest)
    }
}
