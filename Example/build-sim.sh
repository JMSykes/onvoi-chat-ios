#!/usr/bin/env bash
# Build the OnvoiChat example app for the iOS simulator without an Xcode project.
#   ./build-sim.sh [outDir]   → <outDir>/OnvoiHarness.app
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$HERE/build}"
APP="$OUT/OnvoiHarness.app"
ARCH="$(uname -m)"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
rm -rf "$APP" && mkdir -p "$APP"
xcrun -sdk iphonesimulator swiftc -parse-as-library -sdk "$SDK" -target "$ARCH-apple-ios15.0-simulator" \
  "$HERE"/../Sources/OnvoiChat/*.swift "$HERE/HarnessApp.swift" -o "$APP/OnvoiHarness"
cp "$HERE/Info.plist" "$APP/Info.plist"
codesign --force --sign - "$APP" >/dev/null
echo "$APP"
