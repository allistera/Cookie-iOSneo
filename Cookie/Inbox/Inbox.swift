import Foundation
import Observation

/// The loaded inbox: rows, categories and the paging cursor.
@MainActor
@Observable
final class Inbox {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed
    }

    private(set) var phase: Phase = .loading
    private(set) var emails: [EmailSummary] = []
    private(set) var categories: [EmailCategory] = []
    private(set) var nextCursor: String?
    private(set) var isLoadingMore = false
    /// The last load-more failed; the footer offers Retry.
    private(set) var loadMoreFailed = false
    /// A refresh failed while rows were already shown; they are kept.
    private(set) var refreshFailed = false

    private let client: APIClient
    /// Bumped per refresh so a slow response cannot overwrite a newer one.
    @ObservationIgnored private var generation = 0

    init(client: APIClient) {
        self.client = client
    }

    var tabs: [InboxTab] {
        InboxTab.tabs(for: emails, categories: categories)
    }

    /// Reloads the first page and the categories together.
    func refresh() async {
        generation += 1
        let current = generation
        refreshFailed = false
        if emails.isEmpty { phase = .loading }
        do {
            async let page: InboxPage = client.get(CookieAPIEndpoints.inbox(before: nil))
            async let list: CategoryList = client.get(CookieAPIEndpoints.categories)
            let (loadedPage, loadedList) = try await (page, list)
            guard current == generation else { return }
            emails = loadedPage.emails
            categories = loadedList.categories
            nextCursor = loadedPage.nextCursor
            loadMoreFailed = false
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            guard current == generation else { return }
            if emails.isEmpty {
                phase = .failed
            } else {
                refreshFailed = true
            }
        }
    }

    /// Appends the next page. Requires a user action; never runs twice at once.
    func loadMore() async {
        guard !isLoadingMore, let cursor = nextCursor else { return }
        isLoadingMore = true
        loadMoreFailed = false
        let current = generation
        defer { isLoadingMore = false }
        do {
            let page: InboxPage = try await client.get(CookieAPIEndpoints.inbox(before: cursor))
            guard current == generation else { return }
            let known = Set(emails.map(\.id))
            emails += page.emails.filter { !known.contains($0.id) }
            nextCursor = page.nextCursor
        } catch is CancellationError {
            return
        } catch {
            guard current == generation else { return }
            loadMoreFailed = true
        }
    }
}
