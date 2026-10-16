#!/usr/bin/env bash
# Run tests on the first available iPhone simulator.
# Usage: scripts/test.sh            package unit tests (parity, geometry, password, ...)
#        scripts/test.sh example    Example app UI tests (drag, delete, scrolling under the overlay)
set -euo pipefail

cd "$(dirname "$0")/.."
if [[ "${1:-}" == "example" ]]; then
  TARGET=(-project Example/PdfSignatureExample.xcodeproj -scheme PdfSignatureExample CODE_SIGNING_ALLOWED=NO)
else
  TARGET=(-scheme "${1:-PdfSignatureSDK}")
fi

DEVICE_ID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
data = json.load(sys.stdin)["devices"]
runtimes = sorted((r for r in data if "iOS" in r), reverse=True)
for runtime in runtimes:
    for device in data[runtime]:
        if device["name"].startswith("iPhone"):
            print(device["udid"]); sys.exit(0)
sys.exit("No iPhone simulator available")
')

echo "Using simulator $DEVICE_ID"
# A freshly booted simulator can drop the first touches of a UI test, so wait until it is ready
xcrun simctl bootstatus "$DEVICE_ID" -b > /dev/null
xcodebuild test \
  "${TARGET[@]}" \
  -destination "id=$DEVICE_ID" \
  -skipPackagePluginValidation \
  -quiet && echo "TESTS PASSED"
