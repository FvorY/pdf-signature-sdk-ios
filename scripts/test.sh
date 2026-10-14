#!/usr/bin/env bash
# Build and run the package tests on the first available iPhone simulator.
# Usage: scripts/test.sh [scheme]
set -euo pipefail

SCHEME="${1:-PdfSignatureSDK}"
cd "$(dirname "$0")/.."

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
xcodebuild test \
  -scheme "$SCHEME" \
  -destination "id=$DEVICE_ID" \
  -skipPackagePluginValidation \
  -quiet && echo "TESTS PASSED"
