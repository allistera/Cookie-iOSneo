# Foundation and Sign-in Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new native SwiftUI app that signs in through Auth0, shows a signed-in screen proving one authenticated API call works, and has enforced lint, build and test gates.

**Architecture:** One `@Observable` `Session` owns authentication state behind a small `CredentialsSource` protocol, so Auth0 is imported in exactly one file. A `Sendable` `APIClient` attaches the bearer token, maps failures to typed errors and retries once after a 401. Views receive both by initialiser injection.

**Tech Stack:** Swift 6 language mode, SwiftUI, Observation, Swift Testing, Auth0.swift 3.1.0, XcodeGen 2.46.0, swift-format (Xcode toolchain), SwiftLint 0.65.1, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-05-foundation-sign-in-design.md`. Read it and `AGENTS.md` before starting.

## Global Constraints

- Xcode 27.0, build 27A266a. Swift 6 language mode. Minimum iOS 27.0. iPhone only.
- Bundle identifier `com.cookie.ios`; development team `88SL72L38P`.
- Auth0 domain `auth.infinitywave.online`; client ID `4y2MEvoi8vzmzKdRniBiyIuUdD1WNMc2`; audience `https://cookie-web/api`; scopes `openid profile email offline_access`.
- The only runtime dependency is Auth0.swift, exact version 3.1.0. Add no others.
- `import Auth0` appears only in `Cookie/Auth/Auth0CredentialsSource.swift`.
- No force unwraps, forced casts, `try!`, `fatalError`, `Task.detached`, `@unchecked Sendable`, inline lint suppressions or weakened lint rules.
- Every user-facing string has an entry in `Cookie/Resources/Localizable.xcstrings`.
- **Never run tests locally.** `xcodebuild build` and `xcodebuild build-for-testing` are allowed; `xcodebuild test` runs only in GitHub Actions.
- Before every commit: `scripts/format.sh`, then `scripts/lint.sh` must exit 0.
- All work after Task 1 Step 1 happens on branch `foundation-sign-in`. Do not merge the pull request; the maintainer merges.
- End every commit message with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

## Deviations from the spec

These simplify the spec without changing behaviour. Each was chosen while writing the plan.

- `scripts/toolchain.env` replaces `.xcode-version`, so tool pins and download checksums live in one file read by both the scripts and CI.
- `Session` reads stored credentials synchronously in its initialiser, so there is no `restoring` state or launch spinner.
- `APIClient` takes a transport closure instead of a `URLSession`, so tests need no global `URLProtocol` state.
- `APIError` gains `invalidRequest` for an endpoint that cannot form a URL, which avoids force-unwrapping URL literals.
- Only the colours and font weights used by this sub-project's screens are added. Tag tones, avatar tones and the hairline colour arrive with the sub-project that first uses them.

## File Structure

| Path | Responsibility |
| --- | --- |
| `project.yml` | XcodeGen project definition |
| `scripts/toolchain.env` | Pinned tool versions and checksums |
| `scripts/swift-sources.sh` | Enumerates first-party Swift files |
| `scripts/format.sh`, `scripts/lint.sh` | Format and fail-closed lint commands |
| `scripts/ci/setup.sh` | Selects Xcode and installs pinned tools on a CI runner |
| `.github/workflows/ci.yml` | Lint, build and test jobs |
| `Cookie/App/CookieApp.swift` | App entry point; builds `Session` and `APIClient` |
| `Cookie/App/RootView.swift` | Switches between signed-out and signed-in |
| `Cookie/Auth/UserProfile.swift` | Signed-in user's name, email and initial |
| `Cookie/Auth/CredentialsSource.swift` | Protocol and `CredentialsFailure` |
| `Cookie/Auth/Auth0CredentialsSource.swift` | Auth0-backed `CredentialsSource` |
| `Cookie/Auth/Session.swift` | Authentication state |
| `Cookie/Auth/SignInView.swift` | Sign-in screen |
| `Cookie/Networking/Endpoint.swift` | `Endpoint` and `CookieAPIEndpoints` |
| `Cookie/Networking/APIError.swift` | Typed API failures |
| `Cookie/Networking/TokenProvider.swift` | Token closures handed to `APIClient` |
| `Cookie/Networking/APIClient.swift` | Authenticated GET with one renew-and-retry |
| `Cookie/Networking/MailboxState.swift` | `GET /emails/state` response |
| `Cookie/Design/CookieFont.swift` | Font helpers |
| `Cookie/Home/HomeView.swift` | Header and unread-count proof |
| `Cookie/Home/AccountMenu.swift` | Account button and menu |
| `Cookie/Resources/` | Asset catalog, fonts, `Auth0.plist`, String Catalog |
| `CookieTests/` | Swift Testing unit tests |

---

### Task 1: Repository, tooling and CI

**Files:**
- Create: `.gitignore`, `CLAUDE.md`, `README.md`, `project.yml`, `.swift-format`, `.swiftlint.yml`
- Create: `scripts/toolchain.env`, `scripts/swift-sources.sh`, `scripts/format.sh`, `scripts/lint.sh`, `scripts/ci/setup.sh`
- Create: `.github/workflows/ci.yml`
- Create: `Cookie/App/CookieApp.swift`, `Cookie/Resources/Auth0.plist`, `Cookie/Resources/Localizable.xcstrings`, `Cookie/Resources/Assets.xcassets/Contents.json`
- Commit as-is: `AGENTS.md`, `Cookie iOS.html`

**Interfaces:**
- Consumes: nothing.
- Produces: `scripts/format.sh`, `scripts/lint.sh`, the `Cookie` scheme, branch `foundation-sign-in`, and a pull request whose CI runs lint and build.

- [ ] **Step 1: Create the GitHub repository and the working branch**

The maintainer approved a new public repository named `allistera/Cookie-iOSneo`. `main` currently holds only the spec and this plan.

```bash
git add docs/superpowers/plans/2026-10-05-foundation-sign-in.md
git commit -m "Add foundation and sign-in implementation plan

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
gh repo create allistera/Cookie-iOSneo --public --source . --remote origin --push
git switch -c foundation-sign-in
```

Expected: the repository exists and `git branch --show-current` prints `foundation-sign-in`. If the plan is already committed, skip the first two commands.

- [ ] **Step 2: Write `.gitignore`**

The generated project is ignored except for the package lockfile inside it.

```gitignore
.DS_Store
build/
*.xcresult
xcuserdata/
Cookie/Info.plist

Cookie.xcodeproj/*
!Cookie.xcodeproj/project.xcworkspace/
Cookie.xcodeproj/project.xcworkspace/*
!Cookie.xcodeproj/project.xcworkspace/xcshareddata/
Cookie.xcodeproj/project.xcworkspace/xcshareddata/*
!Cookie.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/
Cookie.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/*
!Cookie.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

- [ ] **Step 3: Write `CLAUDE.md`**

```markdown
@AGENTS.md
```

- [ ] **Step 4: Write `scripts/toolchain.env`**

The checksums are the SHA-256 of the official release archives, computed on 2026-10-05.

```bash
# Pinned toolchain. Read by scripts/lint.sh and scripts/ci/setup.sh.
XCODE_VERSION=27.0
XCODE_BUILD=27A266a
SWIFTLINT_VERSION=0.65.1
SWIFTLINT_SHA256=c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0
XCODEGEN_VERSION=2.46.0
XCODEGEN_SHA256=4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806
```

- [ ] **Step 5: Write `scripts/swift-sources.sh`**

```bash
#!/bin/bash
# Sourced by format.sh and lint.sh. Fills `swift_sources` with every
# first-party Swift file: tracked or new, never ignored build output.
swift_sources=()
while IFS= read -r -d '' file; do
    if [[ -f "$file" ]]; then
        swift_sources+=("$file")
    fi
done < <(git ls-files -z --cached --others --exclude-standard -- '*.swift')

if [[ ${#swift_sources[@]} -eq 0 ]]; then
    echo "error: no Swift sources found" >&2
    exit 1
fi
```

- [ ] **Step 6: Write `scripts/format.sh`**

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/swift-sources.sh

xcrun swift-format format --in-place --configuration .swift-format "${swift_sources[@]}"
echo "Formatted ${#swift_sources[@]} Swift files."
```

- [ ] **Step 7: Write `scripts/lint.sh`**

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.env
source scripts/swift-sources.sh

xcode_build="$(xcodebuild -version | awk '/Build version/ { print $3 }')"
if [[ "$xcode_build" != "$XCODE_BUILD" ]]; then
    echo "error: Xcode build $xcode_build does not match pinned $XCODE_BUILD" >&2
    exit 1
fi

swiftlint_version="$(swiftlint version)"
if [[ "$swiftlint_version" != "$SWIFTLINT_VERSION" ]]; then
    echo "error: SwiftLint $swiftlint_version does not match pinned $SWIFTLINT_VERSION" >&2
    exit 1
fi

xcrun swift-format lint --strict --configuration .swift-format "${swift_sources[@]}"
swiftlint lint --strict --config .swiftlint.yml -- "${swift_sources[@]}"
echo "Linted ${#swift_sources[@]} Swift files."
```

- [ ] **Step 8: Write `scripts/ci/setup.sh` and make the scripts executable**

```bash
#!/bin/bash
# Selects the pinned Xcode and installs the pinned SwiftLint and XcodeGen
# on a GitHub Actions macOS runner. Fails if a checksum does not match.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/toolchain.env

sudo xcode-select -s "/Applications/Xcode_${XCODE_VERSION}.app"

tools="$RUNNER_TEMP/tools"
mkdir -p "$tools/bin"

curl -fsSL -o "$tools/swiftlint.zip" \
    "https://github.com/realm/SwiftLint/releases/download/${SWIFTLINT_VERSION}/portable_swiftlint.zip"
echo "${SWIFTLINT_SHA256}  $tools/swiftlint.zip" | shasum -a 256 -c -
unzip -q -o "$tools/swiftlint.zip" swiftlint -d "$tools/bin"

curl -fsSL -o "$tools/xcodegen.zip" \
    "https://github.com/yonaskolb/XcodeGen/releases/download/${XCODEGEN_VERSION}/xcodegen.zip"
echo "${XCODEGEN_SHA256}  $tools/xcodegen.zip" | shasum -a 256 -c -
unzip -q -o "$tools/xcodegen.zip" -d "$tools"

echo "$tools/bin" >> "$GITHUB_PATH"
echo "$tools/xcodegen/bin" >> "$GITHUB_PATH"
```

```bash
chmod +x scripts/format.sh scripts/lint.sh scripts/ci/setup.sh
```

- [ ] **Step 9: Write `.swift-format`**

```json
{
    "version": 1,
    "indentation": { "spaces": 4 },
    "tabWidth": 4,
    "lineLength": 120,
    "maximumBlankLines": 1
}
```

- [ ] **Step 10: Write `.swiftlint.yml`**

`trailing_comma` is set to agree with swift-format, which adds trailing commas to multi-line collections.

```yaml
strict: true
opt_in_rules:
  - force_unwrapping
  - implicitly_unwrapped_optional
line_length: 120
trailing_comma:
  mandatory_comma: true
```

- [ ] **Step 11: Write `project.yml`**

```yaml
name: Cookie
options:
  bundleIdPrefix: com.cookie
  deploymentTarget:
    iOS: "27.0"
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "6.0"
    SWIFT_TREAT_WARNINGS_AS_ERRORS: YES
    MARKETING_VERSION: "1.0"
    CURRENT_PROJECT_VERSION: "1"
    TARGETED_DEVICE_FAMILY: "1"
    ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
packages:
  Auth0:
    url: https://github.com/auth0/Auth0.swift
    exactVersion: 3.1.0
targets:
  Cookie:
    type: application
    platform: iOS
    sources:
      - path: Cookie
        excludes:
          - Info.plist
    dependencies:
      - package: Auth0
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.cookie.ios
        PRODUCT_NAME: Cookie
        DEVELOPMENT_TEAM: 88SL72L38P
    info:
      path: Cookie/Info.plist
      properties:
        CFBundleDisplayName: Cookie
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
        CFBundleShortVersionString: $(MARKETING_VERSION)
        ITSAppUsesNonExemptEncryption: false
        UILaunchScreen: {}
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
          - UIInterfaceOrientationLandscapeLeft
          - UIInterfaceOrientationLandscapeRight
        CFBundleURLTypes:
          - CFBundleTypeRole: Editor
            CFBundleURLSchemes:
              - $(PRODUCT_BUNDLE_IDENTIFIER)
schemes:
  Cookie:
    build:
      targets:
        Cookie: all
    run:
      config: Debug
    archive:
      config: Release
```

- [ ] **Step 12: Write the minimal app and resources**

`Cookie/App/CookieApp.swift` (Task 5 replaces the body):

```swift
import SwiftUI

@main
struct CookieApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Cookie")
        }
    }
}
```

`Cookie/Resources/Auth0.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>ClientId</key>
    <string>4y2MEvoi8vzmzKdRniBiyIuUdD1WNMc2</string>
    <key>Domain</key>
    <string>auth.infinitywave.online</string>
</dict>
</plist>
```

`Cookie/Resources/Localizable.xcstrings`:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "Cookie" : {}
  },
  "version" : "1.0"
}
```

`Cookie/Resources/Assets.xcassets/Contents.json`:

```json
{
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 13: Write `.github/workflows/ci.yml`**

Actions are pinned to commit SHAs. The test job is added in Task 3, when the first tests exist.

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint:
    name: Lint
    runs-on: xcode-27
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - name: Set up toolchain
        run: scripts/ci/setup.sh
      - name: Lint
        run: scripts/lint.sh

  build:
    name: Build
    runs-on: xcode-27
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - name: Set up toolchain
        run: scripts/ci/setup.sh
      - name: Generate project
        run: xcodegen generate
      - name: Build
        run: |
          xcodebuild build \
            -project Cookie.xcodeproj \
            -scheme Cookie \
            -destination 'generic/platform=iOS Simulator' \
            -onlyUsePackageVersionsFromResolvedFile \
            CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 14: Write `README.md`**

````markdown
# Cookie iOS

Native SwiftUI email client for Cookie. See `AGENTS.md` for working rules and
`docs/superpowers/specs/` for design specs.

## Requirements

- Xcode 27.0 (build 27A266a)
- XcodeGen 2.46.0 and SwiftLint 0.65.1 (`brew install xcodegen swiftlint`)

Pinned versions live in `scripts/toolchain.env`.

## Commands

```sh
xcodegen generate     # create Cookie.xcodeproj from project.yml
scripts/format.sh     # format every first-party Swift file
scripts/lint.sh       # strict swift-format and SwiftLint checks
```

Regenerate the project after adding, moving or removing files. Tests run in
GitHub Actions, not locally.
````

- [ ] **Step 15: Generate, resolve packages and build**

```bash
xcodegen generate
xcodebuild -resolvePackageDependencies -project Cookie.xcodeproj -scheme Cookie
xcodegen generate
ls Cookie.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
xcodebuild build -project Cookie.xcodeproj -scheme Cookie \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath build \
    -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO -quiet
```

Expected: `Package.resolved` still exists after the second `xcodegen generate`, and the build ends with no errors or warnings. If `Package.resolved` is removed by regeneration, stop and report it; do not work around it.

- [ ] **Step 16: Prove the lint gate fails closed, then passes**

```bash
scripts/format.sh
scripts/lint.sh
printf 'let  broken = 1\n' > "Cookie/App/Lint Probe.swift"
scripts/lint.sh; echo "exit=$?"
rm "Cookie/App/Lint Probe.swift"
scripts/lint.sh
```

Expected: the first and last runs print `Linted 1 Swift files.` and exit 0. The middle run reports a finding in `Lint Probe.swift` (a new, untracked file whose path contains a space) and prints a non-zero `exit=`. If swift-format and SwiftLint give conflicting instructions for the same line, stop and report the rule names; do not disable a rule.

- [ ] **Step 17: Commit, push and open the pull request**

```bash
git add -A
git status --short
git commit -m "Add project skeleton, lint scripts and CI

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push -u origin foundation-sign-in
gh pr create --base main --head foundation-sign-in \
    --title "Foundation and sign-in" \
    --body "Implements docs/superpowers/specs/2026-10-05-foundation-sign-in-design.md.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

Check `git status --short` before committing: it must list only the files named in this task plus `Package.resolved`. `Cookie.xcodeproj/project.pbxproj`, `build/` and `Cookie/Info.plist` must not appear.

- [ ] **Step 18: Verify CI for the pushed commit**

```bash
gh run list --commit "$(git rev-parse HEAD)"
gh run watch "$(gh run list --commit "$(git rev-parse HEAD)" --json databaseId --jq '.[0].databaseId')" --exit-status
```

Expected: the Lint and Build jobs pass for this exact SHA. On failure, read the log with `gh run view --log-failed`, fix the cause, re-run format and lint, commit and push again.

---

### Task 2: Colours, fonts and app icon

**Files:**
- Create: `Cookie/Resources/Assets.xcassets/{Surface,PrimaryText,SecondaryText,AvatarRing,AccentColor}.colorset/Contents.json`
- Create: `Cookie/Resources/Assets.xcassets/AppIcon.appiconset/{Contents.json,AppIcon.png}`
- Create: `Cookie/Resources/Assets.xcassets/Logo.imageset/{Contents.json,Logo.png}`
- Create: `Cookie/Resources/Fonts/{Figtree-Regular,Figtree-SemiBold,Figtree-Bold,JetBrainsMono-Medium}.ttf`, `Cookie/Resources/Fonts/{Figtree-OFL,JetBrainsMono-OFL}.txt`
- Create: `Cookie/Design/CookieFont.swift`
- Modify: `project.yml` (add `UIAppFonts`)

**Interfaces:**
- Consumes: the project from Task 1.
- Produces: asset symbols `Color(.surface)`, `Color(.primaryText)`, `Color(.secondaryText)`, `Color(.avatarRing)`, `Image(.logo)`, and:

```swift
enum CookieFont {
    enum Weight: String { case regular, semibold, bold }
    static func text(_ weight: Weight, size: CGFloat, relativeTo style: Font.TextStyle) -> Font
    static func mono(size: CGFloat, relativeTo style: Font.TextStyle) -> Font
}
```

- [ ] **Step 1: Generate the colour sets**

Light values come from the design; dark values are derived and reviewed in Task 5. Run once from the repository root; the loop is not committed.

```bash
catalog=Cookie/Resources/Assets.xcassets
while read -r name light dark; do
    mkdir -p "$catalog/$name.colorset"
    component() { printf '"red":"0x%s","green":"0x%s","blue":"0x%s","alpha":"1.000"' "${1:0:2}" "${1:2:2}" "${1:4:2}"; }
    cat > "$catalog/$name.colorset/Contents.json" <<EOF
{
  "colors" : [
    { "idiom" : "universal",
      "color" : { "color-space" : "srgb", "components" : { $(component "$light") } } },
    { "idiom" : "universal",
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : { "color-space" : "srgb", "components" : { $(component "$dark") } } }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF
done <<'COLOURS'
Surface FBFAF5 0F1A15
PrimaryText 0E271D F2F0E6
SecondaryText 5D6B63 A3B0A8
AvatarRing D7E1DC 2C4038
AccentColor 327056 6FB896
COLOURS
```

- [ ] **Step 2: Extract the icon from the design export**

The export embeds a 1024-pixel PNG of a rounded dark square on a transparent margin. iOS needs a full-bleed opaque square, so the script scales the inner square to fill the canvas over the icon's own background colour. Run from the repository root; the two helper files go in a temporary directory and are not committed.

```bash
tmp="$(mktemp -d)"
python3 - "$tmp" <<'EOF'
import base64, json, re, sys
html = open("Cookie iOS.html", encoding="utf-8").read()
manifest = json.loads(re.search(r'<script type="__bundler/manifest">(.*?)</script>', html, re.S).group(1))
png = manifest["edc46787-e36f-4b9c-95fe-24a981b12626"]["data"]
open(sys.argv[1] + "/source.png", "wb").write(base64.b64decode(png))
EOF
cat > "$tmp/icon.swift" <<'EOF'
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 3,
    let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: arguments[1]) as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
    let context = CGContext(
        data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else {
    FileHandle.standardError.write(Data("usage: icon.swift <source.png> <output.png>\n".utf8))
    exit(1)
}
// The dark square spans pixels 96...928 of the 1024-pixel source.
let inset: CGFloat = 96
let scale = 1024 / (1024 - 2 * inset)
context.setFillColor(CGColor(srgbRed: 0x10 / 255, green: 0x27 / 255, blue: 0x1F / 255, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
context.draw(image, in: CGRect(x: -inset * scale, y: -inset * scale, width: 1024 * scale, height: 1024 * scale))
guard let output = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: arguments[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)
else { exit(1) }
CGImageDestinationAddImage(destination, output, nil)
exit(CGImageDestinationFinalize(destination) ? 0 : 1)
EOF
catalog=Cookie/Resources/Assets.xcassets
mkdir -p "$catalog/AppIcon.appiconset" "$catalog/Logo.imageset"
xcrun swift "$tmp/icon.swift" "$tmp/source.png" "$catalog/AppIcon.appiconset/AppIcon.png"
cp "$catalog/AppIcon.appiconset/AppIcon.png" "$catalog/Logo.imageset/Logo.png"
sips -g pixelWidth -g pixelHeight -g hasAlpha "$catalog/AppIcon.appiconset/AppIcon.png"
```

Expected: `pixelWidth: 1024`, `pixelHeight: 1024`, `hasAlpha: no`. Open the PNG with the Read tool and confirm the dark green reaches all four corners with the "C" mark centred. If the corners show a different shade from the square, sample the square's colour from `source.png` and replace the three fill components.

- [ ] **Step 3: Write the icon and logo catalog entries**

`Cookie/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images" : [
    { "filename" : "AppIcon.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`Cookie/Resources/Assets.xcassets/Logo.imageset/Contents.json`:

```json
{
  "images" : [
    { "filename" : "Logo.png", "idiom" : "universal" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 4: Download the fonts and their licences**

Both families are under the SIL Open Font License. They are resource files, not code dependencies.

```bash
fonts=Cookie/Resources/Fonts
mkdir -p "$fonts"
raw() { gh api "repos/$1/contents/$2" -H "Accept: application/vnd.github.raw" > "$3"; }
for weight in Regular SemiBold Bold; do
    raw erikdkennedy/figtree "fonts/ttf/Figtree-$weight.ttf" "$fonts/Figtree-$weight.ttf"
done
raw google/fonts ofl/figtree/OFL.txt "$fonts/Figtree-OFL.txt"
raw JetBrains/JetBrainsMono fonts/ttf/JetBrainsMono-Medium.ttf "$fonts/JetBrainsMono-Medium.ttf"
raw JetBrains/JetBrainsMono OFL.txt "$fonts/JetBrainsMono-OFL.txt"
mdls -name com_apple_ats_name_postscript "$fonts"/*.ttf
```

Expected PostScript names: `Figtree-Regular`, `Figtree-SemiBold`, `Figtree-Bold`, `JetBrainsMono-Medium`. If any differs, use the printed name in Step 6.

- [ ] **Step 5: Register the fonts in `project.yml`**

Add under `targets.Cookie.info.properties`, after `UISupportedInterfaceOrientations`:

```yaml
        UIAppFonts:
          - Figtree-Regular.ttf
          - Figtree-SemiBold.ttf
          - Figtree-Bold.ttf
          - JetBrainsMono-Medium.ttf
```

- [ ] **Step 6: Write `Cookie/Design/CookieFont.swift`**

```swift
import SwiftUI

/// The app's bundled typefaces. Sizes follow the design and scale with
/// Dynamic Type relative to the given system text style.
enum CookieFont {
    enum Weight: String {
        case regular = "Figtree-Regular"
        case semibold = "Figtree-SemiBold"
        case bold = "Figtree-Bold"
    }

    static func text(_ weight: Weight, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }

    /// JetBrains Mono Medium, used for counts and times.
    static func mono(size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom("JetBrainsMono-Medium", size: size, relativeTo: style)
    }
}
```

- [ ] **Step 7: Regenerate, build, format and lint**

```bash
xcodegen generate
xcodebuild build -project Cookie.xcodeproj -scheme Cookie \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath build \
    -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO -quiet
scripts/format.sh
scripts/lint.sh
```

Expected: the build succeeds with no asset-catalog warnings; lint exits 0.

- [ ] **Step 8: Commit and push**

```bash
git add -A
git commit -m "Add colour tokens, bundled fonts and app icon

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push
```

---

### Task 3: Networking

**Files:**
- Create: `Cookie/Networking/Endpoint.swift`, `Cookie/Networking/APIError.swift`, `Cookie/Networking/TokenProvider.swift`, `Cookie/Networking/APIClient.swift`, `Cookie/Networking/MailboxState.swift`
- Test: `CookieTests/EndpointTests.swift`, `CookieTests/MailboxStateTests.swift`, `CookieTests/APIClientTests.swift`
- Modify: `project.yml` (test target and scheme), `.github/workflows/ci.yml` (test job)

**Interfaces:**
- Consumes: nothing from earlier tasks beyond the project.
- Produces:

```swift
struct Endpoint: Equatable, Sendable {
    let host: String
    let path: String
    var url: URL? { get }
}
enum CookieAPIEndpoints { static let mailboxState: Endpoint }

enum APIError: Error, Equatable { case invalidRequest, transport, unauthorised, server(status: Int), decoding }

struct TokenProvider: Sendable {
    let current: @Sendable () async throws -> String
    let renewed: @Sendable () async throws -> String
    let invalidate: @Sendable () async -> Void
}

struct APIClient: Sendable {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    init(tokens: TokenProvider, transport: @escaping Transport = ...)
    func get<Response: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> Response
}

struct MailboxState: Decodable, Equatable, Sendable { let unreadCount: Int }
```

- [ ] **Step 1: Add the test target, scheme test action and CI test job**

In `project.yml`, add under `targets:` after the `Cookie` target:

```yaml
  CookieTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: CookieTests
    dependencies:
      - target: Cookie
```

and in `schemes.Cookie`, between `run:` and `archive:`:

```yaml
    test:
      config: Debug
      targets:
        - CookieTests
```

In `.github/workflows/ci.yml`, add this job after `build`:

```yaml
  test:
    name: Test
    runs-on: xcode-27
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - name: Set up toolchain
        run: scripts/ci/setup.sh
      - name: Generate project
        run: xcodegen generate
      - name: Test
        run: |
          xcodebuild test \
            -project Cookie.xcodeproj \
            -scheme Cookie \
            -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' \
            -resultBundlePath TestResults.xcresult \
            -onlyUsePackageVersionsFromResolvedFile \
            CODE_SIGNING_ALLOWED=NO
      - name: Upload test results
        if: failure()
        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1
        with:
          name: test-results
          path: TestResults.xcresult
```

- [ ] **Step 2: Write the failing tests**

`CookieTests/EndpointTests.swift`:

```swift
import Foundation
import Testing

@testable import Cookie

struct EndpointTests {
    @Test func mailboxStatePinsOriginAndPath() {
        #expect(CookieAPIEndpoints.mailboxState.url?.absoluteString == "https://emails-api.infinitywave.online/emails/state")
    }

    @Test func pathWithoutLeadingSlashHasNoURL() {
        #expect(Endpoint(host: "example.com", path: "emails").url == nil)
    }
}
```

`CookieTests/MailboxStateTests.swift` (the JSON is the shape `handleState` returns in Cookie-Worker's `workers/cookie-web-emails/src/emails.js`):

```swift
import Foundation
import Testing

@testable import Cookie

struct MailboxStateTests {
    @Test func decodesUnreadCountAndIgnoresOtherFields() throws {
        let json = """
            {"unreadCount":3,"spamCount":0,"snoozedCount":1,"scheduledCount":0,"starredCount":2,
             "screeningCount":0,"blockedCount":0,"userId":"6f1c2f0e-8a54-4d0c-9a59-2f5f4c1f7f10"}
            """
        let state = try JSONDecoder().decode(MailboxState.self, from: Data(json.utf8))
        #expect(state == MailboxState(unreadCount: 3))
    }
}
```

`CookieTests/APIClientTests.swift`:

```swift
import Foundation
import Testing

@testable import Cookie

/// Records what the client asked for, without shared global state.
private actor CallLog {
    private(set) var requests: [URLRequest] = []
    private(set) var renewals = 0
    private(set) var invalidations = 0

    func record(_ request: URLRequest) -> Int {
        requests.append(request)
        return requests.count
    }

    func recordRenewal() { renewals += 1 }
    func recordInvalidation() { invalidations += 1 }
}

private struct StubResponse: Sendable {
    let status: Int
    let body: String
}

struct APIClientTests {
    /// A client whose transport answers the nth request with the nth stub,
    /// repeating the last stub for any further requests.
    private func makeClient(_ stubs: [StubResponse], log: CallLog) -> APIClient {
        let tokens = TokenProvider(
            current: { "first-token" },
            renewed: {
                await log.recordRenewal()
                return "renewed-token"
            },
            invalidate: { await log.recordInvalidation() }
        )
        return APIClient(tokens: tokens) { request in
            let index = await log.record(request) - 1
            let stub = stubs[min(index, stubs.count - 1)]
            guard let url = request.url,
                let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: nil, headerFields: nil)
            else { throw URLError(.badURL) }
            return (Data(stub.body.utf8), response)
        }
    }

    @Test func attachesBearerTokenAndDecodesSuccess() async throws {
        let log = CallLog()
        let client = makeClient([StubResponse(status: 200, body: #"{"unreadCount":7}"#)], log: log)

        let state: MailboxState = try await client.get(CookieAPIEndpoints.mailboxState)

        #expect(state == MailboxState(unreadCount: 7))
        let requests = await log.requests
        #expect(requests.count == 1)
        #expect(requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer first-token")
        #expect(requests.first?.url?.absoluteString == "https://emails-api.infinitywave.online/emails/state")
    }

    @Test func renewsTokenAndRetriesOnceAfterUnauthorised() async throws {
        let log = CallLog()
        let client = makeClient(
            [StubResponse(status: 401, body: "{}"), StubResponse(status: 200, body: #"{"unreadCount":2}"#)],
            log: log
        )

        let state: MailboxState = try await client.get(CookieAPIEndpoints.mailboxState)

        #expect(state == MailboxState(unreadCount: 2))
        let requests = await log.requests
        #expect(requests.count == 2)
        #expect(requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer renewed-token")
        #expect(await log.renewals == 1)
        #expect(await log.invalidations == 0)
    }

    @Test func secondUnauthorisedInvalidatesSessionAndThrows() async {
        let log = CallLog()
        let client = makeClient([StubResponse(status: 401, body: "{}")], log: log)

        await #expect(throws: APIError.unauthorised) {
            let _: MailboxState = try await client.get(CookieAPIEndpoints.mailboxState)
        }
        #expect(await log.requests.count == 2)
        #expect(await log.invalidations == 1)
    }

    @Test func serverErrorIsNotRetried() async {
        let log = CallLog()
        let client = makeClient([StubResponse(status: 500, body: #"{"error":"Failed to load inbox state"}"#)], log: log)

        await #expect(throws: APIError.server(status: 500)) {
            let _: MailboxState = try await client.get(CookieAPIEndpoints.mailboxState)
        }
        #expect(await log.requests.count == 1)
    }

    @Test func malformedBodyThrowsDecoding() async {
        let log = CallLog()
        let client = makeClient([StubResponse(status: 200, body: "not json")], log: log)

        await #expect(throws: APIError.decoding) {
            let _: MailboxState = try await client.get(CookieAPIEndpoints.mailboxState)
        }
    }

    @Test func transportFailureThrowsTransport() async {
        let tokens = TokenProvider(current: { "token" }, renewed: { "token" }, invalidate: {})
        let client = APIClient(tokens: tokens) { _ in throw URLError(.notConnectedToInternet) }

        await #expect(throws: APIError.transport) {
            let _: MailboxState = try await client.get(CookieAPIEndpoints.mailboxState)
        }
    }

    @Test func cancelledRequestThrowsCancellationNotTransport() async {
        let tokens = TokenProvider(current: { "token" }, renewed: { "token" }, invalidate: {})
        let client = APIClient(tokens: tokens) { _ in throw URLError(.cancelled) }

        await #expect(throws: CancellationError.self) {
            let _: MailboxState = try await client.get(CookieAPIEndpoints.mailboxState)
        }
    }

    @Test func endpointWithoutURLThrowsInvalidRequest() async {
        let log = CallLog()
        let client = makeClient([StubResponse(status: 200, body: "{}")], log: log)

        await #expect(throws: APIError.invalidRequest) {
            let _: MailboxState = try await client.get(Endpoint(host: "example.com", path: "no-slash"))
        }
        #expect(await log.requests.isEmpty)
    }
}
```

- [ ] **Step 3: Confirm the tests do not compile yet**

```bash
xcodegen generate
xcodebuild build-for-testing -project Cookie.xcodeproj -scheme Cookie \
    -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max,OS=27.0' -derivedDataPath build \
    -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO -quiet
```

Expected: compilation fails with "cannot find 'CookieAPIEndpoints' in scope" and similar. This is a compile failure, not an observed test failure; do not describe it as one. If no "iPhone 18 Pro Max" simulator exists locally, pick a name from `xcrun simctl list devices available`.

- [ ] **Step 4: Write `Cookie/Networking/Endpoint.swift`**

```swift
import Foundation

/// One HTTPS route on a Cookie Worker.
struct Endpoint: Equatable, Sendable {
    let host: String
    let path: String

    /// `nil` when the host and path cannot form a URL, for example a path
    /// without a leading slash.
    var url: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        return components.url
    }
}

/// Every production route the app calls. A contract test pins each one.
enum CookieAPIEndpoints {
    static let mailboxState = Endpoint(host: "emails-api.infinitywave.online", path: "/emails/state")
}
```

- [ ] **Step 5: Write `Cookie/Networking/APIError.swift`**

```swift
/// Why an API call failed. Cancellation is never an `APIError`; it surfaces
/// as `CancellationError` so callers do not show it as a failure.
enum APIError: Error, Equatable {
    /// The endpoint could not form a URL.
    case invalidRequest
    /// The request did not reach the server or returned a non-HTTP response.
    case transport
    /// The server rejected the token even after one renewal.
    case unauthorised
    /// The server answered with a status outside 200-299.
    case server(status: Int)
    /// The response body did not match the expected shape.
    case decoding
}
```

- [ ] **Step 6: Write `Cookie/Networking/TokenProvider.swift`**

```swift
/// How `APIClient` obtains access tokens and reports a rejected session.
struct TokenProvider: Sendable {
    /// A token believed valid, renewed first if it has expired.
    let current: @Sendable () async throws -> String
    /// A token from a forced renewal, used after the server answers 401.
    let renewed: @Sendable () async throws -> String
    /// Called when the server rejects a freshly renewed token.
    let invalidate: @Sendable () async -> Void
}
```

- [ ] **Step 7: Write `Cookie/Networking/MailboxState.swift`**

```swift
/// The part of `GET /emails/state` this app reads.
struct MailboxState: Decodable, Equatable, Sendable {
    let unreadCount: Int
}
```

- [ ] **Step 8: Write `Cookie/Networking/APIClient.swift`**

```swift
import Foundation

/// Authenticated JSON requests to Cookie's Worker APIs.
struct APIClient: Sendable {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let tokens: TokenProvider
    private let transport: Transport

    init(
        tokens: TokenProvider,
        transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }
    ) {
        self.tokens = tokens
        self.transport = transport
    }

    /// Fetches and decodes `endpoint`. A 401 forces one token renewal and one
    /// retry; a second 401 invalidates the session.
    func get<Response: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> Response {
        guard let url = endpoint.url else { throw APIError.invalidRequest }

        var (data, status) = try await send(url, token: try await tokens.current())
        if status == 401 {
            (data, status) = try await send(url, token: try await tokens.renewed())
            if status == 401 {
                await tokens.invalidate()
                throw APIError.unauthorised
            }
        }
        guard (200..<300).contains(status) else { throw APIError.server(status: status) }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func send(_ url: URL, token: String) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await transport(request)
            guard let http = response as? HTTPURLResponse else { throw APIError.transport }
            return (data, http.statusCode)
        } catch let error as APIError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw APIError.transport
        }
    }
}
```

- [ ] **Step 9: Confirm everything compiles, then format and lint**

```bash
xcodegen generate
xcodebuild build-for-testing -project Cookie.xcodeproj -scheme Cookie \
    -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max,OS=27.0' -derivedDataPath build \
    -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO -quiet
scripts/format.sh
scripts/lint.sh
```

Expected: the app and test bundle compile with no warnings; lint exits 0. Do not run the tests.

- [ ] **Step 10: Commit, push and verify CI**

```bash
git add -A
git commit -m "Add authenticated API client with typed errors

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push
gh run watch "$(gh run list --commit "$(git rev-parse HEAD)" --json databaseId --jq '.[0].databaseId')" --exit-status
```

Expected: Lint, Build and Test pass for this SHA, with 11 tests run. On a test failure, download the log with `gh run view --log-failed`, diagnose the cause, and fix the code or the test's wrong assumption; never weaken an assertion to pass.

---

### Task 4: Session and Auth0

**Files:**
- Create: `Cookie/Auth/UserProfile.swift`, `Cookie/Auth/CredentialsSource.swift`, `Cookie/Auth/Session.swift`, `Cookie/Auth/Auth0CredentialsSource.swift`
- Test: `CookieTests/SessionTests.swift`, `CookieTests/UserProfileTests.swift`
- Modify: `Cookie/Networking/TokenProvider.swift` (add `init(session:)`), `Cookie/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `TokenProvider` from Task 3.
- Produces:

```swift
struct UserProfile: Equatable, Sendable {
    let name: String
    let email: String?
    var initial: String { get }
}

enum CredentialsFailure: Error, Equatable { case cancelled, signInRequired, transient }

@MainActor protocol CredentialsSource: AnyObject {
    var hasStoredCredentials: Bool { get }
    func storedProfile() -> UserProfile?
    func signIn() async throws
    func accessToken() async throws -> String
    func renewedAccessToken() async throws -> String
    func clear()
    func endWebSession() async
}

enum SessionState: Equatable { case signedOut, signedIn(UserProfile) }

@MainActor @Observable final class Session {
    private(set) var state: SessionState
    private(set) var signInError: String?
    init(source: any CredentialsSource)
    func signIn() async
    func signOut() async
    func accessToken() async throws -> String
    func renewAccessToken() async throws -> String
    func invalidate()
}

@MainActor final class Auth0CredentialsSource: CredentialsSource { init() }

extension TokenProvider { init(session: Session) }
```

- [ ] **Step 1: Write the failing tests**

`CookieTests/UserProfileTests.swift`:

```swift
import Testing

@testable import Cookie

struct UserProfileTests {
    @Test func initialIsFirstLetterUppercased() {
        #expect(UserProfile(name: "allister", email: nil).initial == "A")
    }

    @Test func initialIsEmptyForEmptyName() {
        #expect(UserProfile(name: "", email: nil).initial.isEmpty)
    }
}
```

`CookieTests/SessionTests.swift`:

```swift
import Testing

@testable import Cookie

@MainActor
private final class FakeCredentialsSource: CredentialsSource {
    var hasStoredCredentials = false
    var profile: UserProfile?
    /// The profile that becomes stored when `signIn()` succeeds.
    var profileAfterSignIn: UserProfile?
    var signInFailure: CredentialsFailure?
    var tokenFailure: CredentialsFailure?
    private(set) var clearCount = 0
    private(set) var endWebSessionCount = 0

    func storedProfile() -> UserProfile? { profile }

    func signIn() async throws {
        if let signInFailure { throw signInFailure }
        hasStoredCredentials = true
        profile = profileAfterSignIn
    }

    func accessToken() async throws -> String {
        if let tokenFailure { throw tokenFailure }
        return "access-token"
    }

    func renewedAccessToken() async throws -> String {
        if let tokenFailure { throw tokenFailure }
        return "renewed-token"
    }

    func clear() {
        clearCount += 1
        hasStoredCredentials = false
        profile = nil
    }

    func endWebSession() async { endWebSessionCount += 1 }
}

@MainActor
struct SessionTests {
    private let allister = UserProfile(name: "Allister", email: "allister@example.com")

    private func signedInSource() -> FakeCredentialsSource {
        let source = FakeCredentialsSource()
        source.hasStoredCredentials = true
        source.profile = allister
        return source
    }

    @Test func startsSignedOutWithoutStoredCredentials() {
        let session = Session(source: FakeCredentialsSource())
        #expect(session.state == .signedOut)
    }

    @Test func startsSignedInFromStoredCredentials() {
        let session = Session(source: signedInSource())
        #expect(session.state == .signedIn(allister))
    }

    @Test func storedCredentialsWithoutReadableProfileAreCleared() {
        let source = FakeCredentialsSource()
        source.hasStoredCredentials = true

        let session = Session(source: source)

        #expect(session.state == .signedOut)
        #expect(source.clearCount == 1)
    }

    @Test func signInSuccessSignsIn() async {
        let source = FakeCredentialsSource()
        source.profileAfterSignIn = allister
        let session = Session(source: source)

        await session.signIn()

        #expect(session.state == .signedIn(allister))
        #expect(session.signInError == nil)
    }

    @Test func cancelledSignInShowsNoError() async {
        let source = FakeCredentialsSource()
        source.signInFailure = .cancelled
        let session = Session(source: source)

        await session.signIn()

        #expect(session.state == .signedOut)
        #expect(session.signInError == nil)
    }

    @Test func failedSignInShowsErrorAndStaysSignedOut() async {
        let source = FakeCredentialsSource()
        source.signInFailure = .transient
        let session = Session(source: source)

        await session.signIn()

        #expect(session.state == .signedOut)
        #expect(session.signInError != nil)
    }

    @Test func retryingSignInClearsThePreviousError() async {
        let source = FakeCredentialsSource()
        source.signInFailure = .transient
        let session = Session(source: source)
        await session.signIn()

        source.signInFailure = nil
        source.profileAfterSignIn = allister
        await session.signIn()

        #expect(session.signInError == nil)
        #expect(session.state == .signedIn(allister))
    }

    @Test func signOutClearsCredentialsAndWebSession() async {
        let source = signedInSource()
        let session = Session(source: source)

        await session.signOut()

        #expect(session.state == .signedOut)
        #expect(source.clearCount == 1)
        #expect(source.endWebSessionCount == 1)
    }

    @Test func accessTokenComesFromTheSource() async throws {
        let session = Session(source: signedInSource())
        #expect(try await session.accessToken() == "access-token")
        #expect(try await session.renewAccessToken() == "renewed-token")
    }

    @Test func tokenFailureRequiringSignInSignsOut() async {
        let source = signedInSource()
        source.tokenFailure = .signInRequired
        let session = Session(source: source)

        await #expect(throws: CredentialsFailure.signInRequired) {
            _ = try await session.accessToken()
        }
        #expect(session.state == .signedOut)
        #expect(source.clearCount == 1)
    }

    @Test func transientTokenFailureKeepsTheSession() async {
        let source = signedInSource()
        source.tokenFailure = .transient
        let session = Session(source: source)

        await #expect(throws: CredentialsFailure.transient) {
            _ = try await session.renewAccessToken()
        }
        #expect(session.state == .signedIn(allister))
        #expect(source.clearCount == 0)
    }

    @Test func invalidateSignsOutWithoutTouchingTheWebSession() {
        let source = signedInSource()
        let session = Session(source: source)

        session.invalidate()

        #expect(session.state == .signedOut)
        #expect(source.clearCount == 1)
        #expect(source.endWebSessionCount == 0)
    }
}
```

- [ ] **Step 2: Confirm the tests do not compile yet**

```bash
xcodegen generate
xcodebuild build-for-testing -project Cookie.xcodeproj -scheme Cookie \
    -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max,OS=27.0' -derivedDataPath build \
    -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO -quiet
```

Expected: compilation fails with "cannot find 'UserProfile' in scope" and similar.

- [ ] **Step 3: Write `Cookie/Auth/UserProfile.swift`**

```swift
/// The signed-in user, read from the stored ID token.
struct UserProfile: Equatable, Sendable {
    let name: String
    let email: String?

    /// The letter shown on the account button.
    var initial: String {
        String(name.prefix(1)).uppercased()
    }
}
```

- [ ] **Step 4: Write `Cookie/Auth/CredentialsSource.swift`**

```swift
/// Why a credentials operation failed, independent of the identity provider.
enum CredentialsFailure: Error, Equatable {
    /// The user dismissed the login screen.
    case cancelled
    /// The stored session is unusable; the user must sign in again.
    case signInRequired
    /// A network, provider or keychain problem that may succeed later.
    case transient
}

/// The identity provider and credential store behind `Session`.
/// Throwing members throw `CredentialsFailure`.
@MainActor
protocol CredentialsSource: AnyObject {
    /// Whether credentials are stored that are valid or can be renewed.
    var hasStoredCredentials: Bool { get }
    /// The user from the stored ID token, read without a network call.
    func storedProfile() -> UserProfile?
    /// Presents the web login and stores the resulting credentials.
    func signIn() async throws
    /// A valid access token, renewed first if it has expired.
    func accessToken() async throws -> String
    /// An access token from a forced renewal.
    func renewedAccessToken() async throws -> String
    /// Removes stored credentials from this device.
    func clear()
    /// Ends the provider's browser session. Best effort.
    func endWebSession() async
}
```

- [ ] **Step 5: Write `Cookie/Auth/Session.swift`**

```swift
import Foundation
import Observation

enum SessionState: Equatable {
    case signedOut
    case signedIn(UserProfile)
}

/// Owns whether the user is signed in, and hands out access tokens.
@MainActor
@Observable
final class Session {
    private(set) var state: SessionState
    /// A message for the sign-in screen after a failed attempt.
    private(set) var signInError: String?

    private let source: any CredentialsSource

    /// Restores a stored session without a network call, so an offline launch
    /// still lands signed in. The first API call validates the token.
    init(source: any CredentialsSource) {
        self.source = source
        if source.hasStoredCredentials, let profile = source.storedProfile() {
            state = .signedIn(profile)
        } else {
            if source.hasStoredCredentials { source.clear() }
            state = .signedOut
        }
    }

    func signIn() async {
        signInError = nil
        do {
            try await source.signIn()
        } catch CredentialsFailure.cancelled {
            return
        } catch {
            signInError = String(localized: "Sign-in failed. Check your connection and try again.")
            return
        }
        guard let profile = source.storedProfile() else {
            signInError = String(localized: "Signed in, but your profile could not be read. Please try again.")
            return
        }
        state = .signedIn(profile)
    }

    /// Always signs out on this device, even if ending the browser session fails.
    func signOut() async {
        await source.endWebSession()
        signOutLocally()
    }

    func accessToken() async throws -> String {
        try await token { try await self.source.accessToken() }
    }

    func renewAccessToken() async throws -> String {
        try await token { try await self.source.renewedAccessToken() }
    }

    /// The API rejected a freshly renewed token, so the session is over.
    func invalidate() {
        signOutLocally()
    }

    private func token(_ fetch: () async throws -> String) async throws -> String {
        do {
            return try await fetch()
        } catch CredentialsFailure.signInRequired {
            signOutLocally()
            throw CredentialsFailure.signInRequired
        }
    }

    private func signOutLocally() {
        source.clear()
        signInError = nil
        state = .signedOut
    }
}
```

- [ ] **Step 6: Add `init(session:)` to `Cookie/Networking/TokenProvider.swift`**

Append to the file:

```swift
extension TokenProvider {
    init(session: Session) {
        self.init(
            current: { try await session.accessToken() },
            renewed: { try await session.renewAccessToken() },
            invalidate: { await session.invalidate() }
        )
    }
}
```

- [ ] **Step 7: Write `Cookie/Auth/Auth0CredentialsSource.swift`**

The Auth0 calls below (`webAuth().scope().audience().useCredentialsManager().start()`, `logout()`, `credentials()`, `renew()`, `clear()`, `canRenew()`, `hasValid()`, `userProfile()`, `WebAuthError.userCancelled`, and the `CredentialsManagerError` cases) are the ones the earlier Cookie-iOS compiled against Auth0.swift 3.1.0. If any no longer compiles, check the SDK source in `build/SourcePackages/checkouts/Auth0.swift` rather than guessing.

```swift
import Auth0
import OSLog
import SimpleKeychain

/// `CredentialsSource` backed by Auth0 and its Keychain credentials manager.
/// Client ID and domain come from `Auth0.plist`.
@MainActor
final class Auth0CredentialsSource: CredentialsSource {
    /// Must match the audience the Cookie Workers verify, so Auth0 issues a
    /// signed JWT access token rather than an opaque one.
    private static let audience = "https://cookie-web/api"
    private static let scope = "openid profile email offline_access"
    private static let logger = Logger(subsystem: "com.cookie.ios", category: "auth")

    private let manager = CredentialsManager(authentication: Auth0.authentication())

    var hasStoredCredentials: Bool {
        manager.canRenew() || manager.hasValid()
    }

    func storedProfile() -> UserProfile? {
        do {
            let user = try manager.userProfile()
            return UserProfile(name: user.name ?? user.nickname ?? user.email ?? "", email: user.email)
        } catch {
            Self.logger.error("Stored profile unreadable: \(String(describing: type(of: error)), privacy: .public)")
            return nil
        }
    }

    func signIn() async throws {
        do {
            _ = try await Auth0.webAuth()
                .scope(Self.scope)
                .audience(Self.audience)
                .useCredentialsManager(manager)
                .start()
        } catch WebAuthError.userCancelled {
            throw CredentialsFailure.cancelled
        } catch {
            Self.logger.error("Sign-in failed: \(String(describing: type(of: error)), privacy: .public)")
            throw CredentialsFailure.transient
        }
    }

    func accessToken() async throws -> String {
        do {
            return try await manager.credentials().accessToken
        } catch {
            throw Self.failure(for: error)
        }
    }

    func renewedAccessToken() async throws -> String {
        do {
            return try await manager.renew().accessToken
        } catch {
            throw Self.failure(for: error)
        }
    }

    func clear() {
        do {
            try manager.clear()
        } catch {
            Self.logger.error("Clearing credentials failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    func endWebSession() async {
        do {
            try await Auth0.webAuth().logout()
        } catch {
            // Best effort: the user may cancel the sheet. Local sign-out still happens.
            Self.logger.info("Web session not cleared: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    /// Only a missing session or a rejected refresh token ends the session.
    /// Network, rate-limit, Auth0 5xx and other keychain failures are transient.
    private static func failure(for error: Error) -> CredentialsFailure {
        guard let error = error as? CredentialsManagerError else { return .transient }
        switch error {
        case .noCredentials, .noRefreshToken, .sessionExpired:
            return .signInRequired
        case .renewFailed, .storeFailed:
            return causeEndsSession(error.cause) ? .signInRequired : .transient
        default:
            return .transient
        }
    }

    private static func causeEndsSession(_ cause: Error?) -> Bool {
        switch cause {
        case let cause as AuthenticationError:
            return (400..<500).contains(cause.statusCode) && cause.statusCode != 429
        case let cause as SimpleKeychainError:
            return cause == .itemNotFound
        default:
            return false
        }
    }
}
```

- [ ] **Step 8: Add the two error strings to `Cookie/Resources/Localizable.xcstrings`**

Add these keys inside `"strings"`, keeping keys in alphabetical order:

```json
    "Sign-in failed. Check your connection and try again." : {},
    "Signed in, but your profile could not be read. Please try again." : {}
```

- [ ] **Step 9: Compile, format and lint**

```bash
xcodegen generate
xcodebuild build-for-testing -project Cookie.xcodeproj -scheme Cookie \
    -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max,OS=27.0' -derivedDataPath build \
    -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO -quiet
scripts/format.sh
scripts/lint.sh
grep -rl "import Auth0" Cookie CookieTests
```

Expected: no compile warnings; lint exits 0; the `grep` prints only `Cookie/Auth/Auth0CredentialsSource.swift`. If the compiler rejects sending `manager` across isolation, stop and report the exact diagnostic; do not add `@unchecked Sendable`, `nonisolated(unsafe)` or `@preconcurrency`.

- [ ] **Step 10: Commit, push and verify CI**

```bash
git add -A
git commit -m "Add session state and Auth0 credentials source

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push
gh run watch "$(gh run list --commit "$(git rev-parse HEAD)" --json databaseId --jq '.[0].databaseId')" --exit-status
```

Expected: Lint, Build and Test pass for this SHA, with 25 tests run.

---

### Task 5: Sign-in and signed-in screens

**Files:**
- Create: `Cookie/Auth/SignInView.swift`, `Cookie/Home/AccountMenu.swift`, `Cookie/Home/HomeView.swift`, `Cookie/App/RootView.swift`
- Modify: `Cookie/App/CookieApp.swift`, `Cookie/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `Session`, `SessionState`, `UserProfile`, `CredentialsSource`, `Auth0CredentialsSource`, `TokenProvider(session:)`, `APIClient`, `CookieAPIEndpoints.mailboxState`, `MailboxState`, `CookieFont`, and the asset symbols from Task 2.
- Produces: the running app. No later task in this plan depends on these views.

- [ ] **Step 1: Write `Cookie/Home/AccountMenu.swift`**

```swift
import SwiftUI

/// The circular account button from the design's header, opening a menu
/// with the signed-in address and Sign out.
struct AccountMenu: View {
    let profile: UserProfile
    let signOut: () async -> Void

    var body: some View {
        Menu {
            if let email = profile.email {
                Section(email) {
                    signOutButton
                }
            } else {
                signOutButton
            }
        } label: {
            Text(profile.initial)
                .font(CookieFont.text(.semibold, size: 17, relativeTo: .body))
                .foregroundStyle(Color(.surface))
                .frame(width: 44, height: 44)
                .background(Color(.primaryText), in: .circle)
                .overlay(Circle().strokeBorder(Color(.avatarRing), lineWidth: 2))
        }
        .accessibilityLabel("Account")
    }

    private var signOutButton: some View {
        Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
            Task { await signOut() }
        }
    }
}

#Preview {
    AccountMenu(profile: UserProfile(name: "Allister", email: "allister@example.com")) {}
        .padding()
}
```

- [ ] **Step 2: Write `Cookie/Home/HomeView.swift`**

```swift
import SwiftUI

/// The signed-in screen for this sub-project: the design's header, and the
/// unread count from `GET /emails/state` as proof that authenticated API
/// calls work. The inbox replaces the body in the next sub-project.
struct HomeView: View {
    let profile: UserProfile
    let client: APIClient
    let signOut: () async -> Void

    private enum Phase: Equatable {
        case loading
        case loaded(MailboxState)
        case failed
    }

    @State private var phase: Phase = .loading
    @State private var attempt = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.surface))
        .task(id: attempt) {
            await load()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(.logo)
                .resizable()
                .frame(width: 34, height: 34)
                .clipShape(.rect(cornerRadius: 9))
                .accessibilityHidden(true)
            Text("Cookie")
                .font(CookieFont.text(.bold, size: 21, relativeTo: .title3))
                .foregroundStyle(Color(.primaryText))
            Text("Email")
                .font(CookieFont.text(.regular, size: 21, relativeTo: .title3))
                .foregroundStyle(Color(.secondaryText))
            Spacer()
            AccountMenu(profile: profile, signOut: signOut)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            ProgressView()
        case .loaded(let state):
            Text("\(state.unreadCount) unread")
                .font(CookieFont.mono(size: 17, relativeTo: .body))
                .foregroundStyle(Color(.primaryText))
        case .failed:
            ContentUnavailableView {
                Label("Mailbox unavailable", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Retry") { attempt += 1 }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func load() async {
        phase = .loading
        do {
            phase = .loaded(try await client.get(CookieAPIEndpoints.mailboxState))
        } catch is CancellationError {
            // The view went away or a retry superseded this request.
        } catch {
            phase = .failed
        }
    }
}

#if DEBUG
    private func previewClient(status: Int, body: String) -> APIClient {
        let tokens = TokenProvider(current: { "preview" }, renewed: { "preview" }, invalidate: {})
        return APIClient(tokens: tokens) { request in
            guard let url = request.url,
                let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
            else { throw URLError(.badURL) }
            return (Data(body.utf8), response)
        }
    }

    #Preview("Loaded") {
        HomeView(
            profile: UserProfile(name: "Allister", email: "allister@example.com"),
            client: previewClient(status: 200, body: #"{"unreadCount":3}"#),
            signOut: {}
        )
    }

    #Preview("Failed") {
        HomeView(
            profile: UserProfile(name: "Allister", email: nil),
            client: previewClient(status: 500, body: "{}"),
            signOut: {}
        )
    }
#endif
```

- [ ] **Step 3: Write `Cookie/Auth/SignInView.swift`**

```swift
import SwiftUI

/// The signed-out screen. The design has no sign-in screen, so this follows
/// its palette and wordmark with one native prominent button.
struct SignInView: View {
    let session: Session

    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(.logo)
                .resizable()
                .frame(width: 88, height: 88)
                .clipShape(.rect(cornerRadius: 22))
                .accessibilityHidden(true)
            HStack(spacing: 8) {
                Text("Cookie")
                    .font(CookieFont.text(.bold, size: 32, relativeTo: .largeTitle))
                    .foregroundStyle(Color(.primaryText))
                Text("Email")
                    .font(CookieFont.text(.regular, size: 32, relativeTo: .largeTitle))
                    .foregroundStyle(Color(.secondaryText))
            }
            .accessibilityElement(children: .combine)
            Spacer()
            if let error = session.signInError {
                Text(error)
                    .font(CookieFont.text(.regular, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Button {
                isSigningIn = true
            } label: {
                Text("Sign in")
                    .font(CookieFont.text(.semibold, size: 17, relativeTo: .body))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isSigningIn)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.surface))
        .task(id: isSigningIn) {
            guard isSigningIn else { return }
            await session.signIn()
            isSigningIn = false
        }
    }
}

#if DEBUG
    @MainActor
    private final class PreviewCredentialsSource: CredentialsSource {
        let failure: CredentialsFailure
        init(failure: CredentialsFailure) { self.failure = failure }

        var hasStoredCredentials: Bool { false }
        func storedProfile() -> UserProfile? { nil }
        func signIn() async throws { throw failure }
        func accessToken() async throws -> String { throw CredentialsFailure.signInRequired }
        func renewedAccessToken() async throws -> String { throw CredentialsFailure.signInRequired }
        func clear() {}
        func endWebSession() async {}
    }

    #Preview("Signed out") {
        SignInView(session: Session(source: PreviewCredentialsSource(failure: .cancelled)))
    }

    #Preview("Sign-in error") {
        // Tap Sign in to show the error state.
        SignInView(session: Session(source: PreviewCredentialsSource(failure: .transient)))
    }
#endif
```

- [ ] **Step 4: Write `Cookie/App/RootView.swift`**

```swift
import SwiftUI

/// Shows the sign-in screen or the signed-in app, following `Session`.
struct RootView: View {
    let session: Session
    let client: APIClient

    var body: some View {
        switch session.state {
        case .signedOut:
            SignInView(session: session)
        case .signedIn(let profile):
            HomeView(profile: profile, client: client, signOut: session.signOut)
        }
    }
}
```

- [ ] **Step 5: Replace `Cookie/App/CookieApp.swift`**

```swift
import SwiftUI

@main
struct CookieApp: App {
    @State private var session: Session
    private let client: APIClient

    init() {
        let session = Session(source: Auth0CredentialsSource())
        _session = State(initialValue: session)
        client = APIClient(tokens: TokenProvider(session: session))
    }

    var body: some Scene {
        WindowGroup {
            RootView(session: session, client: client)
        }
    }
}
```

- [ ] **Step 6: Replace `Cookie/Resources/Localizable.xcstrings`**

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "%lld unread" : {},
    "Account" : {},
    "Check your connection and try again." : {},
    "Cookie" : {},
    "Email" : {},
    "Mailbox unavailable" : {},
    "Retry" : {},
    "Sign in" : {},
    "Sign out" : {},
    "Sign-in failed. Check your connection and try again." : {},
    "Signed in, but your profile could not be read. Please try again." : {}
  },
  "version" : "1.0"
}
```

- [ ] **Step 7: Compile, format and lint**

```bash
xcodegen generate
xcodebuild build-for-testing -project Cookie.xcodeproj -scheme Cookie \
    -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max,OS=27.0' -derivedDataPath build \
    -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO -quiet
scripts/format.sh
scripts/lint.sh
```

Expected: no warnings; lint exits 0.

- [ ] **Step 8: Inspect the sign-in screen in the simulator**

```bash
device="iPhone 18 Pro Max"
xcrun simctl boot "$device" || true
xcrun simctl install "$device" build/Build/Products/Debug-iphonesimulator/Cookie.app
shots="$(mktemp -d)"
capture() { xcrun simctl launch --terminate-running-process "$device" com.cookie.ios; sleep 2; xcrun simctl io "$device" screenshot "$shots/$1.png"; }
xcrun simctl ui "$device" appearance light; capture light
xcrun simctl ui "$device" appearance dark; capture dark
xcrun simctl ui "$device" content_size accessibility-extra-large; capture large-text
xcrun simctl ui "$device" content_size large
xcrun simctl ui "$device" appearance light
echo "$shots"
```

Open each screenshot with the Read tool and check:

- The logo, the "Cookie Email" wordmark in Figtree (not the system font) and the Sign in button are visible and unclipped.
- Text is readable against the background in light and dark.
- At the accessibility size nothing overlaps or truncates.

If the wordmark renders in the system font, the PostScript names in `CookieFont` do not match the bundled files; recheck Task 2 Step 4.

- [ ] **Step 9: Inspect the signed-in previews**

A real Auth0 login cannot be completed by an agent. Render the `HomeView` "Loaded" and "Failed" previews and the `AccountMenu` preview with the Xcode preview tool (`mcp__xcode__RenderPreview`) and check the header matches the design: logo, bold "Cookie", secondary "Email", circular account button with the initial. Record in the handoff that the signed-in screen was checked by preview only.

- [ ] **Step 10: Commit, push and verify CI**

```bash
git add -A
git commit -m "Add sign-in screen and signed-in mailbox proof

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push
gh run watch "$(gh run list --commit "$(git rev-parse HEAD)" --json databaseId --jq '.[0].databaseId')" --exit-status
```

Expected: Lint, Build and Test pass for this SHA.

---

### Task 6: Final verification and handoff

**Files:**
- Modify: none, unless verification finds a defect.

**Interfaces:**
- Consumes: everything above.
- Produces: a pull request ready for the maintainer.

- [ ] **Step 1: Review the full diff against the spec**

```bash
git diff main...HEAD --stat
git diff main...HEAD -- . ':(exclude)Cookie iOS.html' ':(exclude)*.ttf' ':(exclude)*.png'
```

Check each spec section has matching code, and that the diff holds no secrets, debug output, commented-out code, unused declarations or files outside this plan.

- [ ] **Step 2: Confirm the final commit's CI**

```bash
git status --short
gh pr checks --watch
gh run list --commit "$(git rev-parse HEAD)" --json name,conclusion,headSha
```

Expected: a clean working tree, and Lint, Build and Test all `success` for the HEAD SHA.

- [ ] **Step 3: Hand off**

Report to the maintainer:

- What was built, with the pull request URL and final commit SHA.
- Commands run locally and their results (format, lint, build, build-for-testing).
- CI results for the final SHA, including the test count.
- What was inspected in the simulator and what was checked by preview only.
- What only the maintainer can verify: run the app, sign in with the real account, confirm the unread count matches the web app, and sign out.
- Open items: dark-mode colours are derived and need approval; the pull request is not merged.
