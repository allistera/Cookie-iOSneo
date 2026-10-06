# Cookie iOS: inbox

Date: 2026-10-06
Status: approved design, not yet implemented

## Context

Sub-project 1 delivered sign-in, the API client and a signed-in screen whose
body shows the unread count. This sub-project replaces that body with the
inbox from `Cookie iOS.html`: swipeable category pages of email rows.

Build order after this spec, revised on 2026-10-06 so rows become navigable
in the very next step: 3 email detail and reply, 4 sidebar, 5 AI Today.

## Goal

A signed-in user sees their inbox sorted into category tabs, swipes or taps
between them, pulls to refresh, loads further pages, and sees loading, empty
and failure states with recovery.

## Out of scope

- Opening an email (sub-project 3). Rows are not tappable here.
- Sidebar, folders other than the inbox, and labels navigation (sub-project 4).
- The AI hint pill. The list API has no hint text; the maintainer chose to
  leave it out until the backend provides one.
- Marking read, archiving, starring, search, notifications.
- Caching or offline persistence.

## Approved exception

`AGENTS.md` section 6 discourages hand-built navigation. The maintainer
approved, on 2026-10-06, building the design's category tab strip (large text
tabs with unread counts and page dots) from native `Button`s with tab
accessibility traits. Paging between categories uses SwiftUI's page-style
`TabView`, and each page is a native `List`. The exception covers only the
tab strip.

## API

### Inbox rows

`GET https://emails-api.infinitywave.online/emails?folder=inbox&limit=50`
with `&before=<nextCursor>` for later pages. The shape comes from
Cookie-Worker `workers/cookie-web-emails/src/emails.js`.

```json
{
  "emails": [
    {
      "id": "6f1c…",
      "from_name": "Jordan Blake",
      "from_address": "jordan@example.com",
      "subject": "Final terms for your funding round",
      "snippet": "We've outlined the final terms…",
      "sent_at": "2026-10-05T09:48:12.345Z",
      "is_unread": true,
      "priority": "high",
      "labels": [{ "name": "Funding", "color": "#327056", "kind": "user" }],
      "category": { "id": "9a2b…", "name": "Finance", "color": "#B3792A" },
      "has_ai_summary": true
    }
  ],
  "nextCursor": "2026-10-04T18:02:11.120000Z|6f1c…",
  "unreadCount": 3
}
```

`from_name`, `subject`, `snippet`, `priority`, `category` and label `color`
may be null. `unreadCount` is present only on the first page. `nextCursor`
is null on the last page. Other fields are ignored.

### Categories

`GET https://labels-api.infinitywave.online/categories` returns
`{ "categories": [{ "id", "name", "color", "description", "notifications_enabled", "message_count" }] }`
ordered by name. Only `id`, `name` and `color` are decoded.

## Models (`Cookie/Inbox`)

```swift
struct EmailLabel: Decodable, Equatable, Sendable { let name: String; let color: String? }
struct EmailCategory: Decodable, Equatable, Identifiable, Sendable { let id: String; let name: String; let color: String? }
struct EmailSummary: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let fromName: String?
    let fromAddress: String
    let subject: String?
    let snippet: String?
    let sentAt: Date
    let isUnread: Bool
    let priority: String?
    let labels: [EmailLabel]
    let category: EmailCategory?
    var senderName: String { fromName?.trimmed, else fromAddress }
    var isImportant: Bool { priority == "high" || category?.isImportant == true }
}
struct InboxPage: Decodable, Sendable { let emails: [EmailSummary]; let nextCursor: String?; let unreadCount: Int? }
struct CategoryList: Decodable, Sendable { let categories: [EmailCategory] }
```

Decoding uses `.convertFromSnakeCase` and an ISO 8601 date strategy that
accepts fractional seconds and whole seconds.

### Tab rule

Mirrors Cookie-Web `src/views/TraditionalInboxView.vue`:

- Tabs are: Important, then every category whose name is not "important"
  (case-insensitive, trimmed) in server order, then Other.
- An email is in Important when its priority is `high` or its category's
  name is "important". Otherwise it is in its category's tab if that
  category exists, else Other.
- Every email appears in exactly one tab. Tabs with no loaded mail still
  appear.
- A tab's unread count is the number of its loaded unread rows.

Implemented as a pure function `InboxTab.tabs(for: [EmailSummary], categories: [EmailCategory]) -> [InboxTab]`
where `InboxTab` has a stable `id` (`"important"`, `"category:<id>"`,
`"other"`), a `name`, `emails` and `unreadCount`.

## State (`Inbox`, `@MainActor @Observable`)

```swift
enum InboxPhase: Equatable { case loading, loaded, failed }
final class Inbox {
    private(set) var phase: InboxPhase = .loading
    private(set) var emails: [EmailSummary] = []
    private(set) var categories: [EmailCategory] = []
    private(set) var nextCursor: String?
    private(set) var isLoadingMore = false
    private(set) var loadMoreFailed = false
    var tabs: [InboxTab]
    func refresh() async
    func loadMore() async
}
```

- `refresh()` fetches page one and the categories concurrently. On success
  it replaces `emails`, `categories` and `nextCursor`. A failure of either
  request sets `failed` only when nothing is loaded yet; with rows already
  shown the previous rows stay and the failure is reported through
  `loadMoreFailed`-style inline text in the list footer.
- `loadMore()` fetches the page after `nextCursor`, appends rows whose ids
  are not already present, and updates the cursor. It is a no-op while a
  load is in flight or when there is no cursor.
- Each `refresh()` increments a generation; a response that arrives after a
  newer refresh started is discarded.
- `CancellationError` leaves state untouched and is never shown.
- The view owns the model (`@State private var inbox: Inbox`) and injects
  the `APIClient`.

## UI (`Cookie/Inbox`)

- `InboxView`: header from sub-project 1, `InboxTabStrip`, page dots, and a
  page-style `TabView` keyed by tab id with one `InboxPageView` per tab.
  Selection is `@State`; when the selected tab disappears after a refresh,
  selection falls back to the first tab.
- `InboxTabStrip`: horizontal `ScrollView` of `Button`s. Each shows the tab
  name in Figtree 32pt regular (relative to `.largeTitle`) and, when there
  are unread rows, the count in JetBrains Mono 12pt. Selected: primary text
  colour; unselected: muted colour. Buttons carry
  `.accessibilityAddTraits(.isSelected)` when selected and a label that
  includes the unread count. The strip scrolls the selected tab into view.
- Page dots: a row of small capsules, the selected one wider, as a single
  accessibility element reading "Page N of M".
- `InboxPageView`: a `List` with `.listStyle(.plain)` and `.refreshable`.
  Rows are `EmailRow`. The last element is the footer: a "Load more"
  button while `nextCursor` exists, "Couldn't load more. Retry" after a
  load-more failure, else the footer line.
- `EmailRow`: 40pt circle avatar with the sender's initial, tinted by a
  stable hash of the sender name over the six avatar tones; sender name,
  unread dot and relative time on the first line; subject; two-line snippet
  in secondary colour; and, when the row has labels, a pill with the first
  label's name. Unread rows use semibold for sender and subject. The row is
  one accessibility element whose label includes "Unread" when applicable.
- Footer lines: Important shows "That's everything important. Cookie's
  watching the rest."; every other tab shows "You're all caught up."
- First load: `ProgressView` in place of the pages. Failed first load:
  `ContentUnavailableView` with Retry. An empty tab shows only its footer.

### Time formatting

`RelativeSentTime.string(for: Date, now: Date, calendar: Calendar)`:
same day → short time ("09:48"); previous day → "Yesterday"; within the
previous six days → abbreviated weekday; otherwise abbreviated day and
month. All through `Date.FormatStyle` in the current locale.

### Colours

Added to the asset catalog with derived dark variants: `Hairline`, `Muted`
(unselected tab text), `UnreadDot`, four tag tones (`TagSage`, `TagInfo`,
`TagWarm`, `TagClay`, each with text and background), and six avatar tones
(`Avatar1`…`Avatar6`, each with text and background). Label pills use the
sage tone; the label's own hex colour is not used for text, so arbitrary
colours cannot break contrast.

## Testing

Swift Testing, run in CI:

- `EmailSummary` decodes the recorded row above, including null fields and
  both date formats.
- Tab rule: Important wins over category; an email in an unknown category
  goes to Other; empty categories still produce tabs; counts.
- `Inbox`: refresh replaces rows; load-more appends and de-duplicates;
  no-op without a cursor; superseded refresh is discarded; first-load
  failure sets `failed`; failure with rows loaded keeps them.
- `RelativeSentTime` at fixed dates and a fixed calendar.

## Verification

- `scripts/lint.sh` passes; CI lint, build and test pass on the final SHA.
- Previews with sample data for a populated tab, an empty tab, the failed
  first load, and a row in each state, inspected in light and dark and at an
  accessibility text size.
- The maintainer checks the live inbox after sign-in.

## Known limitations

- The agent cannot sign in, so the live list is checked by the maintainer.
- Tab unread counts cover loaded rows only, as in the web app.
