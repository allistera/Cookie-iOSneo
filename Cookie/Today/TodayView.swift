import SwiftUI

/// AI Today: the stored inbox triage, with Refresh to rebuild it.
struct TodayView: View {
    let today: TodayModel
    var now: Date = .now

    @State private var selection = "today"

    var body: some View {
        VStack(spacing: 0) {
            InboxTabStrip(
                tabs: [InboxTab(id: "today", name: String(localized: "AI Today"), isImportant: false, emails: [])],
                selection: $selection)
            content
        }
        .background(Color(.surface))
        .task {
            await today.load()
        }
    }

    @ViewBuilder private var content: some View {
        switch today.phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            ContentUnavailableView {
                Label("AI Today unavailable", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Retry") {
                    Task { await today.load() }
                }
                .buttonStyle(.borderedProminent)
            }
        case .empty:
            ContentUnavailableView {
                Label("No triage yet", systemImage: "sparkles")
            } description: {
                Text("Cookie hasn't sorted your inbox yet.")
            } actions: {
                refreshButton
            }
        case .loaded(let digest):
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    status(for: digest)
                    Text(digest.overview)
                        .font(CookieFont.text(.regular, size: 17, relativeTo: .body))
                        .foregroundStyle(Color(.primaryText))
                    ForEach(digest.topics) { topic in
                        topicSection(topic)
                    }
                    if digest.noise.count > 0 {
                        noiseSection(digest.noise)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .padding(.bottom, 40)
            }
            .refreshable {
                await today.load()
            }
        }
    }

    private func status(for digest: TriageDigest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Updated \(RelativeSentTime.string(for: digest.createdAt, now: now))")
                    .font(CookieFont.mono(size: 12, relativeTo: .caption))
                    .foregroundStyle(Color(.secondaryText))
                Spacer()
                refreshButton
            }
            switch today.refreshState {
            case .rateLimited:
                Text("Too many refreshes. Try again shortly.")
                    .font(CookieFont.text(.regular, size: 14, relativeTo: .footnote))
                    .foregroundStyle(Color(.secondaryText))
            case .failed:
                Text("Couldn't refresh.")
                    .font(CookieFont.text(.regular, size: 14, relativeTo: .footnote))
                    .foregroundStyle(Color(.secondaryText))
            case .idle, .refreshing:
                EmptyView()
            }
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await today.refresh() }
        } label: {
            if today.refreshState == .refreshing {
                ProgressView()
                    .frame(minWidth: 60)
            } else {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .buttonStyle(.bordered)
        .disabled(today.refreshState == .refreshing)
    }

    private func topicSection(_ topic: TriageTopic) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "\(topic.emoji) \(topic.title)")
                .font(CookieFont.text(.semibold, size: 19, relativeTo: .title3))
                .foregroundStyle(Color(.primaryText))
                .padding(.bottom, 6)
            ForEach(topic.items) { item in
                NavigationLink(value: item) {
                    itemRow(item)
                }
                .buttonStyle(.plain)
                Color(.hairline).frame(height: 1)
            }
        }
    }

    private func itemRow(_ item: TriageItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.headline)
                    .font(CookieFont.text(item.unread ? .semibold : .regular, size: 17, relativeTo: .body))
                    .foregroundStyle(Color(.primaryText))
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(CookieFont.text(.regular, size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Color(.secondaryText))
                }
            }
            Spacer(minLength: 0)
            if item.unread {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 7)
                    .accessibilityLabel("Unread")
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(.muted))
                .padding(.top, 5)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private func noiseSection(_ noise: TriageNoise) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cookie filtered \(noise.count) emails as noise")
                .font(CookieFont.text(.semibold, size: 15, relativeTo: .subheadline))
                .foregroundStyle(Color(.primaryText))
            ForEach(noise.categories, id: \.category) { category in
                Text(verbatim: "\(category.category) · \(category.count)")
                    .font(CookieFont.text(.regular, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color(.secondaryText))
            }
        }
    }
}

#if DEBUG
    @MainActor
    private func previewToday(body: String, refreshStatus: Int = 200) -> TodayModel {
        let tokens = TokenProvider(current: { "preview" }, renewed: { "preview" }, invalidate: {})
        let client = APIClient(tokens: tokens) { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let status = url.path == "/tasks/refresh" ? refreshStatus : 200
            guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
            else { throw URLError(.badURL) }
            return (Data(body.utf8), response)
        }
        return TodayModel(client: client)
    }

    private let previewDigest = """
        {"digest":{"overview":"Two things need a reply today, and the Acme redlines are waiting for you.",
        "created_at":"2026-10-05T09:00:00Z","topics":[{"emoji":"✉️","title":"Reply Needed","items":[
        {"message_id":"1","headline":"Jordan needs sign-off on the funding terms",
        "note":"By Thursday so legal can draft.","unread":true},
        {"message_id":"2","headline":"Ricky and Jennie want a hiring decision",
        "note":"Offer window closes Friday.","unread":false}]},
        {"emoji":"👀","title":"Review","items":[{"message_id":"3","headline":"Q4 roadmap draft from Sophie",
        "note":"Comments wanted before Monday.","unread":true}]}],
        "noise":{"count":17,"categories":[{"category":"Newsletters","count":12},{"category":"Promotions","count":5}]}}}
        """

    #Preview("Loaded") {
        NavigationStack { TodayView(today: previewToday(body: previewDigest), now: InboxPreviewData.now) }
    }

    #Preview("Rate limited") {
        NavigationStack { TodayView(today: previewToday(body: previewDigest, refreshStatus: 429)) }
    }

    #Preview("Empty") {
        TodayView(today: previewToday(body: #"{"digest":null}"#))
    }

    #Preview("Failed") {
        TodayView(today: previewToday(body: "nope"))
    }
#endif
