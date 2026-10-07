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
    /// The last load error is retained when an existing digest or empty state can remain visible.
    private(set) var loadError: APIError?

    private let client: APIClient
    /// Bumped for each load so a slower response cannot replace newer state.
    @ObservationIgnored private var generation = 0

    private enum LoadResult {
        case loaded
        case failed
        case cancelled
        case superseded
    }

    init(client: APIClient) {
        self.client = client
    }

    /// Reads the stored triage. A failure keeps an already shown state and exposes the error.
    func load() async {
        _ = await performLoad()
    }

    /// Asks the backend to rebuild the triage, then reloads it.
    func refresh() async {
        guard refreshState != .refreshing else { return }
        refreshState = .refreshing
        do {
            let _: EmptyResponse = try await client.post(CookieAPIEndpoints.tasksRefresh, body: EmptyBody())
            try Task.checkCancellation()
            switch await performLoad() {
            case .loaded, .superseded:
                refreshState = .idle
            case .failed:
                refreshState = .failed
            case .cancelled:
                refreshState = .idle
            }
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
        var didChange = false
        for topicIndex in digest.topics.indices {
            for itemIndex in digest.topics[topicIndex].items.indices
            where
                digest.topics[topicIndex].items[itemIndex].messageId == messageID
                && digest.topics[topicIndex].items[itemIndex].unread
            {
                digest.topics[topicIndex].items[itemIndex].unread = false
                didChange = true
            }
        }
        guard didChange else { return }
        generation += 1
        phase = .loaded(digest)
    }

    private func performLoad() async -> LoadResult {
        generation += 1
        let currentGeneration = generation
        let previousPhase = phase
        let previousError = loadError
        if case .loaded = phase {} else { phase = .loading }
        loadError = nil

        do {
            try Task.checkCancellation()
            let response: TodayResponse = try await client.get(CookieAPIEndpoints.tasks)
            try Task.checkCancellation()
            guard currentGeneration == generation else { return .superseded }
            phase = response.digest.map { .loaded($0) } ?? .empty
            loadError = nil
            return .loaded
        } catch is CancellationError {
            guard currentGeneration == generation else { return .superseded }
            phase = previousPhase
            loadError = previousError
            return .cancelled
        } catch let error as APIError {
            guard currentGeneration == generation else { return .superseded }
            finishLoad(with: error, previousPhase: previousPhase)
            return .failed
        } catch {
            guard currentGeneration == generation else { return .superseded }
            finishLoad(with: .transport, previousPhase: previousPhase)
            return .failed
        }
    }

    private func finishLoad(with error: APIError, previousPhase: Phase) {
        loadError = error
        switch previousPhase {
        case .loaded, .empty:
            phase = previousPhase
        case .loading, .failed:
            phase = .failed
        }
    }
}
