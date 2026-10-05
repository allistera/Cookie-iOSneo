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
