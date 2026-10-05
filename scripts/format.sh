#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/swift-sources.sh

xcrun swift-format format --in-place --configuration .swift-format "${swift_sources[@]}"
echo "Formatted ${#swift_sources[@]} Swift files."
