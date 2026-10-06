import Foundation
import Observation

/// The loaded mailbox: rows, categories and the paging cursor.
@MainActor
@Observable
final class Mailbox {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed
    }

    private(set) var folder: MailboxFolder = .inbox
    private(set) var phase: Phase = .loading
    /// The inbox's unread count from the first page of any folder.
    private(set) var unreadCount = 0
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

    /// The inbox is sorted into category tabs; any other folder is one page.
    var tabs: [InboxTab] {
        if folder == .inbox {
            return InboxTab.tabs(for: emails, categories: categories)
        }
        return [InboxTab(id: "folder", name: folder.title, isImportant: false, emails: emails)]
    }

    /// Switches folder, dropping the previous folder's rows, and loads it.
    func select(_ folder: MailboxFolder) async {
        guard folder != self.folder else { return }
        self.folder = folder
        emails = []
        categories = []
        nextCursor = nil
        loadMoreFailed = false
        refreshFailed = false
        phase = .loading
        await refresh()
    }

    /// Reloads the first page, with the categories for the inbox.
    func refresh() async {
        generation += 1
        let current = generation
        let folder = self.folder
        refreshFailed = false
        if emails.isEmpty { phase = .loading }
        do {
            async let page: InboxPage = client.get(CookieAPIEndpoints.mailbox(folder: folder, before: nil))
            let loadedList: CategoryList? =
                folder == .inbox ? try await client.get(CookieAPIEndpoints.categories) : nil
            let loadedPage = try await page
            guard current == generation, folder == self.folder else { return }
            emails = loadedPage.emails
            categories = loadedList?.categories ?? []
            nextCursor = loadedPage.nextCursor
            if let unread = loadedPage.unreadCount { unreadCount = unread }
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
            let page: InboxPage = try await client.get(CookieAPIEndpoints.mailbox(folder: folder, before: cursor))
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

    /// Clears the row's unread flag so tab counts and row weight update at once.
    func markRead(_ id: String) {
        setUnread(id, false)
    }

    /// Restores the unread flag after the server rejected a mark-read.
    func markUnread(_ id: String) {
        setUnread(id, true)
    }

    private func setUnread(_ id: String, _ isUnread: Bool) {
        guard let index = emails.firstIndex(where: { $0.id == id }) else { return }
        emails[index].isUnread = isUnread
    }
}
