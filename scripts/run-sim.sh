#!/bin/sh
# Install and launch the built app on the Simulator, then save a screenshot.
# Usage: scripts/run-sim.sh [screenshot.png] [launch args...]
cd "$(dirname "$0")/.."
SIM="${SIM_NAME:-iPhone 17 Pro}"
OUT="${1:-build/screenshot.png}"; shift 2>/dev/null
UDID=$(xcrun simctl list devices available | grep "$SIM (" | grep -m1 -v Max | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')
xcrun simctl boot "$UDID" 2>/dev/null
xcrun simctl install "$UDID" build/Build/Products/Debug-iphonesimulator/PlayIt.app
xcrun simctl terminate "$UDID" com.greggman.playit 2>/dev/null
xcrun simctl launch "$UDID" com.greggman.playit "$@" >/dev/null
sleep "${WAIT:-3}"
xcrun simctl io "$UDID" screenshot "$OUT" >/dev/null 2>&1 && echo "$OUT"
