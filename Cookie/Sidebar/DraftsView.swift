import SwiftUI

/// The read-only Drafts list. Editing arrives with a general composer.
struct DraftsView: View {
    let sidebar: SidebarModel
    var now: Date = .now

    var body: some View {
        Group {
            if sidebar.drafts.isEmpty, sidebar.isLoadingLists {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sidebar.drafts.isEmpty, sidebar.draftsFailed {
                ContentUnavailableView {
                    Label("Drafts unavailable", systemImage: "wifi.exclamationmark")
                } description: {
                    Text("Check your connection and try again.")
                } actions: {
                    Button("Retry") {
                        Task { await sidebar.loadLists() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if sidebar.drafts.isEmpty {
                ContentUnavailableView("No drafts", systemImage: "doc")
            } else {
                List(sidebar.drafts) { draft in
                    row(draft)
                        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                        .listRowBackground(Color(.surface))
                        .listRowSeparatorTint(Color(.hairline))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await sidebar.loadLists()
                }
            }
        }
        .background(Color(.surface))
    }

    private func row(_ draft: Draft) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(draft.recipients.map { String(localized: "To: \($0)") } ?? String(localized: "No recipient"))
                    .font(CookieFont.text(.semibold, size: 17, relativeTo: .body))
                    .foregroundStyle(Color(.primaryText))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(RelativeSentTime.string(for: draft.updatedAt, now: now))
                    .font(CookieFont.mono(size: 12, relativeTo: .caption))
                    .foregroundStyle(Color(.secondaryText))
            }
            Text(draft.subject?.isEmpty == false ? draft.subject ?? "" : String(localized: "(No subject)"))
                .font(CookieFont.text(.regular, size: 15, relativeTo: .subheadline))
                .foregroundStyle(Color(.primaryText))
                .lineLimit(1)
            if let preview = draft.preview, !preview.isEmpty {
                Text(preview)
                    .font(CookieFont.text(.regular, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color(.secondaryText))
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
