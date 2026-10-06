# Cookie iOS: AI Today

Date: 2026-10-06
Status: approved design, not yet implemented

## Context

The last sub-project. The design shows only a sidebar entry for AI Today;
the screen layout here is the maintainer-approved proposal. Branch
`ai-today` from `main`.

## Goal

The user opens AI Today from the sidebar and reads the latest inbox
triage: an overview, topic groups citing emails that open the detail
screen, and a Noise summary. They can rebuild the triage with Refresh.

## Out of scope (maintainer chose "triage only")

- Suggested to-dos and completing them.
- The news round-up (retired on the backend).
- Any new design for the triage beyond the layout below.

## API

- `GET https://tasks-api.infinitywave.online/tasks` →
  `{ "tasks": [...], "digest": Digest | null, "news": ... }`. Only `digest`
  is decoded:

```json
{ "overview": "Two things need a reply today…", "created_at": "2026-10-06T08:00:00.000Z",
  "topics": [{ "emoji": "✉️", "title": "Reply Needed",
               "items": [{ "message_id": "6f1c…", "headline": "Jordan needs sign-off", "note": "By Thursday.", "unread": true }] }],
  "noise": { "count": 17, "categories": [{ "category": "Newsletters", "count": 12 }, { "category": "Promotions", "count": 5 }] } }
```

- `POST https://tasks-api.infinitywave.online/tasks/refresh` with an empty
  JSON object → `200 { "ok": true }`; `429` when rate-limited; `502`/`503`
  otherwise.
- `GET messages-api/messages?id=<id>&calendar=deferred` (existing) also
  decodes `subject` and `thread: [{ "id", "from_name", "from_address", "snippet", "sent_at", "is_sent" }]`.

## Models (`Cookie/Today`)

```swift
struct TriageItem: Decodable, Hashable, Identifiable, Sendable { let messageId: String; let headline: String; let note: String; var unread: Bool; var id: String { messageId } }
struct TriageTopic: Decodable, Hashable, Identifiable, Sendable { let emoji: String; let title: String; var items: [TriageItem]; var id: String { title } }
struct NoiseCategory: Decodable, Hashable, Sendable { let category: String; let count: Int }
struct TriageNoise: Decodable, Hashable, Sendable { let count: Int; let categories: [NoiseCategory] }
struct TriageDigest: Decodable, Hashable, Sendable { let overview: String; let createdAt: Date; var topics: [TriageTopic]; let noise: TriageNoise }
struct TodayResponse: Decodable, Sendable { let digest: TriageDigest? }
```

`MessageBody` gains `subject: String?` and `thread: [ThreadMessage]`
(`id`, `fromName`, `fromAddress`, `snippet`, `sentAt`), both tolerant of
absence.

### `TodayModel` (`@MainActor @Observable`)

```swift
enum Phase: Equatable { case loading, loaded(TriageDigest), empty, failed }
enum RefreshState: Equatable { case idle, refreshing, rateLimited, failed }
final class TodayModel {
    private(set) var phase: Phase
    private(set) var refreshState: RefreshState
    init(client: APIClient)
    func load() async                 // GET /tasks; null digest → .empty
    func refresh() async              // POST refresh, then load(); 429 → .rateLimited, other → .failed; success → .idle
    func markRead(_ messageID: String) // clears unread on the matching item
}
```

A refresh failure keeps the current digest on screen. Cancellation leaves
state untouched.

### `EmailReference`

```swift
enum EmailReference {
    static func summary(for messageID: String, unread: Bool, from body: MessageBody) -> EmailSummary?
}
```

Returns `nil` when the thread has no row with that id. The summary has the
body's subject, the row's sender, address, snippet and sent time, the given
unread flag, nil priority and category, and no labels.

## UI

- **Sidebar:** "AI Today" row first under Views, symbol `sparkles` tinted
  the design's green (#138A5E, dark #4FBF8E), selection `.today`.
- **`TodayView`:** the single-tab strip reads "AI Today" (reusing
  `InboxTabStrip` with one tab). Content is a `ScrollView` with
  `.refreshable` (calls `load()`):
  1. Status row: "Updated <RelativeSentTime>" and a bordered "Refresh"
     button (disabled while refreshing, with a progress indicator). Below
     it, when relevant: "Too many refreshes. Try again shortly." or
     "Couldn't refresh."
  2. Overview in Figtree 17pt.
  3. For each topic: header "<emoji> <title>" in Figtree SemiBold 19pt;
     items as `NavigationLink(value: item)` rows showing the headline
     (semibold with the unread dot when unread) and the note in secondary
     colour, separated by hairlines.
  4. Noise: "Cookie filtered <count> emails as noise" (plural-aware) and one
     line per category "<category> · <count>", in secondary colour. Hidden
     when the count is zero.
  - Empty: `ContentUnavailableView("No triage yet", systemImage: "sparkles")`
    with a Refresh action. Failed: unavailable view with Retry. Loading:
    progress.
- **`EmailReferenceView(item:)`:** loads the body, builds the summary, then
  shows `EmailDetailView`; on a missing row shows "Message unavailable". On
  appear it calls `today.markRead(item.messageId)`.
- **`HomeView`:** `.today` shows `TodayView`; adds
  `navigationDestination(for: TriageItem.self)`.

## Testing

- `TodayResponse` decoding: full digest, `"digest": null`, empty topics.
- `MessageBody` decoding with and without `thread` and `subject`.
- `TodayModel`: load → loaded; null → empty; 500 → failed; refresh success
  reloads; 429 → rateLimited and digest kept; 503 → failed and digest kept;
  `markRead`.
- `EmailReference.summary`: builds from a matching thread row; nil when
  missing.

## Verification

Lint, build and CI tests on the final SHA; previews for loaded, empty,
failed and rate-limited states; the maintainer checks live triage, Refresh
and opening a cited email.
