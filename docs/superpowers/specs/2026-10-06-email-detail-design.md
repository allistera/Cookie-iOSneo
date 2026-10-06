# Cookie iOS: email detail and reply

Date: 2026-10-06
Status: approved design, not yet implemented

## Context

Sub-project 2 delivered the inbox with non-tappable rows. This sub-project
makes rows navigate to the design's email detail screen, renders the
message body, marks the message read, and sends a reply. Branch
`email-detail` is based on `inbox` (pull request #2) and targets `main`
once that is merged.

## Goal

Tapping an inbox row opens the email. The body renders safely, the row
becomes read, and the user can send a reply from the screen and see that it
was sent.

## Out of scope

- The "More actions" button, archiving, starring, labels, spam, unsubscribe.
- Conversation history (`thread`), attachments, calendar invites, the AI
  thread summary, AI Compose.
- Rich-text or HTML replies: the reply is plain text.
- Scheduling, follow-ups, Sent folder (sub-project 4).

## Approved decision

The maintainer chose on 2026-10-06 to render `body_html` in a bounded
`WKWebView` rather than plain text only. The bridge is the one isolated
UIKit adapter in the app and the only file importing WebKit.

## API

### Message body

`GET https://messages-api.infinitywave.online/messages?id=<uuid>&calendar=deferred`
(Cookie-Worker `workers/cookie-web-messages/src/messages.js`, `getMessage`).

```json
{ "id": "6f1c…", "subject": "Final terms", "body_html": "<p>…</p>", "body_text": "…",
  "thread_summary": null, "thread": [], "attachments": [], "unsubscribe": null,
  "calendar_invite": null, "calendar_invite_pending": false }
```

Only `id`, `bodyHtml` and `bodyText` are decoded; both bodies may be null.
Sender, time and subject come from the already loaded `EmailSummary`.

### Mark read

`PATCH https://messages-api.infinitywave.online/messages` with
`{ "id": "<uuid>", "is_unread": false }`. Returns the updated flags; the app
checks only the status code.

### Send

`POST https://send-api.infinitywave.online/send` with

```json
{ "to": "jordan@example.com", "subject": "Re: Final terms", "text": "…",
  "replyToMessageId": "6f1c…", "requestId": "<uuid>" }
```

`to`, `subject` and `text` are required and must be non-empty. `requestId`
(1–128 of `A-Za-z0-9._:-`) makes a retried request idempotent. Success is
`200 { "id", "messageId" }`; failures are `400` (validation), `429` (quota)
and `502` (provider).

## Models and logic (`Cookie/Detail`)

```swift
struct MessageBody: Decodable, Equatable, Sendable { let id: String; let bodyHtml: String?; let bodyText: String? }

struct ReplyDraft: Equatable, Sendable {
    let requestID: String                        // UUID string, fixed for the draft's life
    static func subject(replyingTo subject: String?) -> String   // "Re: " prefix unless already present (case-insensitive)
    static func quotedText(original: EmailSummary, bodyText: String?) -> String
    func body(reply: String, original: EmailSummary, bodyText: String?) -> SendRequest
}

struct SendRequest: Encodable, Equatable, Sendable { let to, subject, text, replyToMessageId, requestId: String }
struct MarkReadRequest: Encodable { let id: String; let isUnread: Bool }   // encoded snake_case
```

`quotedText` produces `"\n\nOn <date>, <sender> wrote:\n> line\n> line"`
from `bodyText`, with the date in the user's locale (abbreviated date and
short time); with no `bodyText` the quote is omitted.

### `EmailDetail` (`@MainActor @Observable`)

```swift
enum BodyPhase: Equatable { case loading, loaded(MessageBody), failed }
enum ReplyPhase: Equatable { case closed, composing, sending, sent, failed }
final class EmailDetail {
    let email: EmailSummary
    private(set) var body: BodyPhase
    private(set) var reply: ReplyPhase
    var replyText: String
    private(set) var showsRemoteImages: Bool
    init(email: EmailSummary, client: APIClient, inbox: Inbox)
    func load() async           // GET body; also marks read once
    func showRemoteImages()
    func openReply(); func closeReply()
    func send() async
}
```

- `load()` fetches the body and, the first time it runs for an unread
  email, calls `inbox.markRead(email.id)` and PATCHes the server. A PATCH
  failure is logged (OSLog, no content) and the local flag is restored.
- `send()` requires non-blank `replyText`; it moves to `sending`, posts the
  draft, then `sent` (clearing `replyText`) or `failed` (keeping it). The
  draft's `requestID` is created when the composer opens and reused across
  retries until a send succeeds.
- `CancellationError` leaves state untouched.

### `Inbox.markRead(_ id: String)`

Sets `isUnread = false` on the matching row so tab counts and row weight
update immediately. `EmailSummary.isUnread` becomes `var`.

### `APIClient`

Adds `post<Body: Encodable & Sendable, Response: Decodable & Sendable>(_:body:)`
and `patch(...)`, sharing the token, retry and error mapping with `get`.
Bodies encode with `.convertToSnakeCase` except `SendRequest`, whose keys
are camelCase on the wire; `SendRequest` declares explicit `CodingKeys`.
A `204`/empty response decodes to `EmptyResponse`.

## UI

### Navigation

`HomeView` wraps its content in a `NavigationStack`, hides the navigation
bar on the root, and declares `navigationDestination(for: EmailSummary.self)`.
`EmailRow` is wrapped in `NavigationLink(value:)`. `EmailSummary` becomes
`Hashable`.

### `EmailDetailView`

Native navigation bar (inline, empty title, system back). Content in a
`ScrollView`:

1. Subject in Figtree Bold 28pt (relative to `.title`), hairline below.
2. Sender block: avatar (same tone rule as rows), sender name, "to me",
   time at the right.
3. "Show images" bordered button when the HTML references remote content
   and images are still blocked.
4. The body: `EmailBodyView` for HTML, or `Text(bodyText)` in Figtree 17pt
   when there is no HTML; `ProgressView` while loading; a compact
   unavailable message with Retry on failure.
5. The reply divider: hairline, 44pt circular reply button (filled when the
   composer is open), hairline. Accessibility label "Reply to <sender>".
6. "Reply sent to <sender>." under the divider after a successful send.

The composer is attached with `safeAreaInset(edge: .bottom)` while the
reply phase is composing, sending or failed: a `TextField` with vertical
axis (1–5 lines, placeholder "Reply to <sender>"), focused when opened, and
a 44pt circular send button disabled while blank or sending. `failed` shows
"Couldn't send. Try again." above the field. Keyboard shortcuts: Cmd-Return
sends, Escape closes.

### `EmailBodyView` (WebKit bridge)

- `WKWebViewConfiguration`: JavaScript off, non-persistent data store, no
  inline media.
- Remote `http(s)` images, stylesheets, fonts, media and raw loads blocked by
  a `WKContentRuleList` compiled once per process; if compilation fails the
  view shows a placeholder instead of the message (fail closed).
- Link taps (`http`, `https`, `mailto`) open externally; all other
  navigations are cancelled except the initial `about:blank` load.
- Scrolling disabled; content height reported through KVO on the scroll
  view's `contentSize`, clamped to 12,000 points.
- HTML is wrapped in a document with a mobile viewport and CSS: Figtree
  via `@font-face` from the bundle (base URL `Bundle.main.bundleURL`),
  17px/1.55 line height, `color-scheme: light dark`, images and tables
  capped at 100% width.
- `hasBlockedRemoteContent(_ html:)` detects remote `img src`, `url()`,
  `background=`, `<link href>`, `@import` and media sources.

## Testing

Swift Testing in CI:

- `MessageBody` decodes the recorded shape with null bodies.
- `ReplyDraft`: subject prefixing ("Re: x", existing "RE: x", nil subject
  → "Re: (No subject)"), quoted text with and without body text, recipient
  is the original address.
- `EmailDetail`: load success/failure; opening an unread email marks it read
  in the inbox and PATCHes; a PATCH failure restores the flag; send success
  clears the text and reports sent; send failure keeps the text and the
  same `requestId` on retry; blank text does not send.
- `APIClient`: POST encodes the body and `Content-Type: application/json`;
  PATCH likewise; snake_case encoding for `MarkReadRequest`, camelCase for
  `SendRequest`.
- `EmailBodyView.hasBlockedRemoteContent` positive and negative cases.

## Verification

- Lint, build and CI tests pass on the final SHA.
- Previews for loaded (HTML), loaded (text only), failed, composing and
  sent states in light and dark.
- The maintainer opens a real email, confirms it becomes read in the web
  app, taps a link, shows images, and sends a reply that arrives.

## Known limitations

- The agent cannot sign in; live checks are the maintainer's.
- Replies are plain text with a quoted copy; no HTML quote.
