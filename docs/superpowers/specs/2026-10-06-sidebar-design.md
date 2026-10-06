# Cookie iOS: sidebar

Date: 2026-10-06
Status: approved design, not yet implemented

## Context

Sub-projects 1–3 delivered sign-in, the inbox and the email detail screen.
This sub-project adds the design's sidebar: views (folders), labels, a
read-only Drafts list, and the slide-over drawer that reveals it. Branch
`sidebar` from `main`.

## Goal

The user opens the sidebar from the header, switches between Inbox, New
senders, Done, Sent, Drafts, Spam, Blocked and any label, and sees that
folder's mail with the same list behaviour as the inbox.

## Out of scope

- AI Today (sub-project 5). Its row is omitted until it exists.
- Editing or creating drafts, and any composer beyond the reply box.
- Starred and Snoozed folders (not in the design).
- Label management, rules, settings, search.
- Opening the drawer by swiping right past the first category.

## Approved exceptions

1. The maintainer chose on 2026-10-06 the slide-over drawer as designed
   over a native sheet: the main view slides right to reveal the sidebar,
   with a scrim. This is the app's second hand-built navigation exception,
   limited to the drawer container.
2. Drafts is a read-only list; tapping a draft does nothing until a
   composer exists.

## API

- `GET emails-api/emails?folder=<f>&limit=50[&before=…][&label=<name>]`
  with `f` in `inbox`, `screening` (New senders), `done`, `sent`, `spam`,
  `blocked`, `label`. The first page of any folder carries `unreadCount`
  (always the inbox's). Rows add `is_sent` and `recipients`
  (`{ "to": [{ "name", "address" }], "cc": [...] }`, possibly null).
- `GET labels-api/labels` → `{ "labels": [{ "id", "name", "color", "kind", "description", "auto_apply", "message_count" }] }`,
  ordered by name. Decoded: `id`, `name`, `color`.
- `GET drafts-api.infinitywave.online/drafts` →
  `{ "drafts": [{ "id", "to", "subject", "preview", "replyToMessageId", "updatedAt", "isAiGenerated", "isSummary", "attachmentCount" }] }`,
  newest first. Decoded: `id`, `to`, `subject`, `preview`, `updatedAt`
  (all but `id` and `updatedAt` may be null or empty). Note these keys
  are camelCase; the decoder's snake_case conversion leaves them intact.

## Models

```swift
enum MailboxFolder: Equatable, Hashable, Sendable {
    case inbox, screening, done, sent, spam, blocked
    case label(String)
    var title: String               // localised: "Inbox", "New senders", "Done", "Sent", "Spam", "Blocked", or the label name
    var queryItems: [URLQueryItem]  // folder=…[&label=…]
}

struct Recipient: Decodable, Hashable, Sendable { let name: String?; let address: String? }
struct Recipients: Decodable, Hashable, Sendable { let to: [Recipient]? }
// EmailSummary gains: let isSent: Bool (default false when absent), let recipients: Recipients?
// EmailSummary.displayName: "To: <name or address>" for sent rows, else senderName.

struct MailLabel: Decodable, Hashable, Identifiable, Sendable { let id: String; let name: String; let color: String? }
struct Draft: Decodable, Hashable, Identifiable, Sendable { let id: String; let to: String?; let subject: String?; let preview: String?; let updatedAt: Date }
```

`EmailSummary.isUnread` on sent rows is always false server-side; no
special handling.

### `Mailbox` (renamed from `Inbox`)

Adds `private(set) var folder: MailboxFolder = .inbox` and
`func select(_ folder: MailboxFolder) async`, which sets the folder, clears
rows, cursor and failure flags, and runs `refresh()`. `refresh()` and
`loadMore()` use `CookieAPIEndpoints.mailbox(folder:before:)` and fetch
categories only for `.inbox`. `unreadCount` is stored from the first page.
`tabs` returns the category tabs for `.inbox` and a single tab
(`id: "folder"`, `name: folder.title`, `isImportant: false`) otherwise.
`markRead`/`markUnread` unchanged.

### `SidebarModel` (`@MainActor @Observable`)

```swift
enum Selection: Hashable { case folder(MailboxFolder); case drafts }
final class SidebarModel {
    var isOpen: Bool
    var showsMore: Bool                    // design default: expanded
    private(set) var selection: Selection  // starts .folder(.inbox)
    private(set) var labels: [MailLabel]
    private(set) var labelsFailed: Bool
    private(set) var drafts: [Draft]
    private(set) var draftsFailed: Bool
    init(client: APIClient)
    func open()           // sets isOpen and starts loadLists()
    func close()
    func select(_ selection: Selection)   // sets selection and closes
    func loadLists() async                // labels and drafts concurrently; failures set the flags
}
```

## UI

### `DrawerContainer`

A `ZStack`: the sidebar beneath, the main content above. When open, the
main content is offset by `drawerWidth` (320pt, or width − 48 when the
container is narrower than 368pt, read from `GeometryReader`), clipped to a
28pt rounded rectangle on its leading corners, given the design's shadow,
and overlaid by a scrim `Button` ("Close sidebar") at 32% primary colour.
A `DragGesture` on the main content while open closes on a leftward drag
past 60pt. Animations use `.default` unless Reduce Motion is on, in which
case state changes apply without animation.

Accessibility: while open, the main content is `accessibilityHidden`; the
sidebar is marked `.isModal`, and focus moves to the selected row via
`AccessibilityFocusState`; closing moves focus back to the header button.
`onKeyPress(.escape)` closes.

### `SidebarView`

Matches the design: 60pt top inset, two sections with 13pt semibold
secondary headers "Views" and "Labels"; rows are 46pt `Button`s with a
22pt SF Symbol, 17pt Figtree label, optional JetBrains Mono count, 12pt
corner radius, and the selected row filled with the design's selected
tone. Symbols: Inbox `tray`, New senders `person`, Done `checkmark.circle`,
Sent `paperplane`, Drafts `doc`, Spam `exclamationmark.octagon`, Blocked
`eye.slash`, More/Less `chevron.down`/`chevron.up`, labels `tag` tinted
with the label's colour (falls back to secondary). Inbox count is the
mailbox's `unreadCount` when non-zero; Drafts count is `drafts.count` when
non-zero. Selected row: `accessibilityAddTraits(.isSelected)`;
More/Less: `accessibilityValue` expanded/collapsed. A failed labels load
shows "Couldn't load labels." in the section; drafts likewise affect only
the count.

### `HomeView`

Owns `Mailbox` and `SidebarModel`. The header button "Cookie Email ▾"
opens the drawer (accessibility label "Open sidebar", `.isButton`, expanded
value). Content below the header switches on `sidebar.selection`:
`.folder` shows `InboxView` (renamed `MailboxView`); `.drafts` shows
`DraftsView`. Selecting a folder calls `mailbox.select(folder)`.
`NavigationStack` and the detail destination are unchanged; the drawer
container wraps the stack so detail pages also slide.

### `DraftsView`

A `List` of drafts: "To: <to>" (or "No recipient"), subject (or
"(No subject)"), preview (two lines), and the updated time via
`RelativeSentTime`. States: progress, "No drafts" (`ContentUnavailableView`),
failed with Retry. Pull to refresh reloads.

### Colours

Added: `SidebarBackground` (#F6F4EC / dark #15201B), `SelectedRow`
(#ECE8DC / dark #26352D), `Scrim` uses primary text at 32% opacity.

## Testing

- `MailboxFolder.queryItems` for each case and `CookieAPIEndpoints.mailbox(folder:before:)` URLs.
- `EmailSummary` decodes `is_sent` and `recipients` (object, null, missing) and `displayName` for sent rows.
- `Mailbox.select` clears rows and requests the folder; non-inbox folders skip categories and produce one tab; `unreadCount` stored.
- `MailLabel` and `Draft` decoding from recorded shapes.
- `SidebarModel`: `open()` loads lists; failures set flags; `select` closes.
- `DrawerContainer.width(for:)` pure function: 320 at 390pt, width − 48 at 360pt.

## Verification

- Lint, build and CI tests pass on the final SHA.
- Previews: drawer open and closed; sidebar with labels and counts; Drafts
  populated, empty and failed; a Sent row.
- Simulator inspection is limited to the signed-out screen; the maintainer
  checks the drawer live, including VoiceOver focus and Reduce Motion.

## Known limitations

- Edge-swipe to open is not implemented (would conflict with page swiping).
- Folder switches refetch; no per-folder cache.
