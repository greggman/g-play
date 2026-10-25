#!/bin/sh
# Build (Release, for real performance), install and launch on a connected iPhone.
# Usage: scripts/install-device.sh [device-id]  (default: first connected iPhone)
cd "$(dirname "$0")/.."
DEVICE="${1:-$(xcrun devicectl list devices 2>/dev/null | awk '/physical/ && /iPhone/ { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) { print $i; exit } }')}"
[ -n "$DEVICE" ] || { echo "No iPhone connected"; exit 1; }
xcodegen generate -q && \
xcodebuild -project PlayIt.xcodeproj -scheme PlayIt -configuration Release -destination "id=$DEVICE" -derivedDataPath build \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build 2>&1 | grep -E "error:|BUILD" && \
xcrun devicectl device install app --device "$DEVICE" build/Build/Products/Release-iphoneos/PlayIt.app >/dev/null && \
xcrun devicectl device process launch --device "$DEVICE" com.greggman.playit
