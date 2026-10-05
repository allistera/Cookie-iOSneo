# Cookie iOS: foundation and sign-in

Date: 2026-10-05
Status: approved design, not yet implemented

## Context

Cookie iOS is a new native SwiftUI email client built to the design in
`Cookie iOS.html`. It reads mail from Cookie's existing Cloudflare Worker
APIs, which all require an Auth0 access token. The work is split into five
sub-projects, each with its own spec, plan and CI-verified delivery:

1. Foundation and sign-in (this spec)
2. Inbox: category pager, rows, pagination, pull to refresh, unread state
3. Sidebar: views, More/Less, labels, folder switching, Drafts
4. Email detail and reply
5. AI Today

This is a brand-new repository, `allistera/Cookie-iOSneo` (public). Nothing is
inherited from the earlier `allistera/Cookie-iOS` app except the identifiers
listed under "Identity".

## Goal

A signed-out user can launch the app, sign in through Auth0, and land on a
signed-in screen that proves an authenticated API call works. A signed-in
user can sign out. The repository has enforced formatting, linting, build and
test gates.

## Out of scope

- The inbox list, sidebar, email detail, reply and AI Today (sub-projects 2-5).
- TestFlight, fastlane and signing for distribution.
- iPad layouts.
- Persistence, caching, analytics, notifications and widgets.

## Decisions

| Item | Decision |
| --- | --- |
| Xcode | 27.0, build 27A266a, pinned locally and in CI |
| Swift | 6.4 compiler, Swift 6 language mode |
| SDK | iOS 27.0 |
| Minimum OS | iOS 27.0 (product assumption: latest major only) |
| Devices | iPhone only; portrait and landscape |
| Project definition | XcodeGen 2.46.0; `project.yml` is the source of truth and the generated `.xcodeproj` is not committed |
| Runtime dependency | Auth0.swift, exact version 3.1.0, through Swift Package Manager; `Package.resolved` committed. Approved by the maintainer on 2026-10-05 |
| Formatter | swift-format from the pinned Xcode toolchain |
| Linter | SwiftLint 0.65.1 |
| Version control | Git |
| CI | GitHub Actions on the `xcode-27` runner image |

Auth0.swift was chosen over a hand-written `ASWebAuthenticationSession` and
PKCE flow so that the app does not own security-sensitive token exchange,
refresh and Keychain code.

## Identity

Reused from the earlier app so the existing Auth0 Native application and its
allow-listed callback keep working. These are public identifiers, not secrets.

| Setting | Value |
| --- | --- |
| Bundle identifier | `com.cookie.ios` |
| Development team | `88SL72L38P` |
| Auth0 domain | `auth.infinitywave.online` |
| Auth0 client ID | `4y2MEvoi8vzmzKdRniBiyIuUdD1WNMc2` |
| API audience | `https://cookie-web/api` |
| Scopes | `openid profile email offline_access` |
| Callback URL scheme | the bundle identifier (custom scheme) |

## Repository layout

```text
project.yml
.swift-format
.swiftlint.yml
.xcode-version
scripts/format.sh
scripts/lint.sh
.github/workflows/ci.yml
Cookie/
  App/          CookieApp, RootView
  Auth/         Session, CredentialsSource, SignInView
  Networking/   CookieAPIEndpoints, APIClient, APIError, MailboxState
  Design/       font helpers
  Home/         HomeView, AccountMenu
  Resources/    Assets.xcassets, Fonts/, Auth0.plist, Localizable.xcstrings
CookieTests/
```

## Components

### Session (`Cookie/Auth`)

One `@MainActor @Observable` class, `Session`, owns authentication state:

```swift
enum SessionState: Equatable {
    case restoring
    case signedOut
    case signedIn(UserProfile)
}
```

- `restore()` runs once at launch. Stored renewable credentials produce
  `signedIn`; otherwise `signedOut`. A transient renewal failure (offline,
  Auth0 5xx) keeps the user signed in using the stored profile.
- `signIn()` opens Auth0's web login. User cancellation returns to
  `signedOut` without showing an error. Other failures set a user-facing
  error message on the sign-in screen.
- `signOut()` clears stored credentials and the Auth0 browser session.
- `accessToken()` returns a valid access token, renewing when needed.
- `renewAccessToken()` forces a renewal; used after a 401.

`Session` depends on a small `CredentialsSource` protocol (web login, stored
credentials, renew, clear) so tests can substitute a fake. The production
implementation wraps Auth0's `WebAuth` and `CredentialsManager`. This is the
only place that imports Auth0.

### API client (`Cookie/Networking`)

- `CookieAPIEndpoints` lists each Worker origin as a typed value. This
  sub-project needs only `emails-api.infinitywave.online`; later sub-projects
  add theirs.
- `APIClient` is a `Sendable` struct taking a `URLSession` and a token
  provider. `get(_:)` attaches `Authorization: Bearer <token>`, validates the
  HTTP status, and decodes JSON.
- `APIError` distinguishes `transport`, `unauthorised`, `server(status:)`,
  and `decoding`. Cancellation propagates as `CancellationError` and is never
  shown as a failure.
- On a 401 the client forces one token renewal and retries once. A second
  401 throws `unauthorised`, and the session signs the user out.
- No automatic retries otherwise.

### Signed-in proof (`Cookie/Home`)

`HomeView` shows the design's header: app icon, "Cookie" in bold, "Email" in
secondary colour, and a circular account button with the user's initial. The
account button is a native `Menu` showing the signed-in email address and a
Sign out action.

The body loads `GET /emails/state` with `.task` and shows explicit loading,
loaded ("N unread") and failed states, the last with a Retry button.
Sub-project 2 replaces this body with the inbox.

Response fields used:

```json
{ "unreadCount": 3 }
```

Other fields in the response are ignored for now.

### Sign-in screen (`Cookie/Auth`)

The design has no sign-in screen. `SignInView` shows the app icon, the
"Cookie Email" wordmark and one prominent "Sign in" button, with an inline
error message and the button re-enabled when sign-in fails. While `Session`
is `restoring`, `RootView` shows a `ProgressView`.

## Look and feel

- **Colours:** the design's palette as named colours in the asset catalog
  (background, surface, primary text, secondary text, accent, hairline, and
  the tag and avatar tones). The design is light-only; each colour gets a
  derived dark variant, to be reviewed in the simulator.
- **Fonts:** Figtree (variable) and JetBrains Mono Medium bundled as
  resources under their open font licences, exposed through helpers that
  scale with Dynamic Type relative to a system text style.
- **App icon:** the icon embedded in the design export.
- **Strings:** all user-facing text in a String Catalog; English only.

## Formatting and linting

- `.swift-format`: four-space indentation, 120-column line length.
- `.swiftlint.yml`: strict mode, with `force_cast`, `force_try` and
  `force_unwrapping` enabled; rules that overlap swift-format (line length,
  trailing comma, and similar) configured once to agree with it.
- `scripts/format.sh` rewrites first-party Swift sources in place.
- `scripts/lint.sh` is read-only. It runs `swift-format lint --strict` and
  `swiftlint lint --strict` over every first-party Swift file, and fails if a
  tool is missing, a version differs from the pin, or the file list is empty.

## Testing

Swift Testing unit tests, run only in CI:

- `APIClient`: bearer token attached; 2xx decodes; 401 renews and retries
  once; a second 401 throws `unauthorised`; 5xx maps to `server`; malformed
  JSON maps to `decoding`. Uses a stub `URLProtocol`.
- `CookieAPIEndpoints`: pins each origin and path.
- `Session`: restore with and without stored credentials; sign-in success,
  cancellation and failure; sign-out clears state. Uses a fake
  `CredentialsSource`.
- `MailboxState` decoding from a recorded response.

## CI

`.github/workflows/ci.yml` runs on pushes and pull requests with three
required jobs on `xcode-27`, each selecting Xcode 27.0 explicitly:

1. **Lint:** install pinned SwiftLint, run `scripts/lint.sh`.
2. **Build:** install pinned XcodeGen, generate the project, build the app
   with Swift warnings treated as errors.
3. **Test:** run the test scheme on an iPhone 18 Pro, iOS 27.0 simulator;
   upload the result bundle on failure.

## Verification

- `scripts/lint.sh` passes locally with zero violations.
- All three CI jobs pass for the final pushed commit.
- The sign-in screen and its error state are inspected in the simulator in
  light and dark appearance and at an accessibility text size.

## Known limitations

- A full Auth0 login cannot be completed by the agent in the simulator; the
  maintainer confirms real sign-in, the signed-in screen and sign-out.
- GitHub labels the `xcode-27` runner image as a preview, so queue times may
  vary.
