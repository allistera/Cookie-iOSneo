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
