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
