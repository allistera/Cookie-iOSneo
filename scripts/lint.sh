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
