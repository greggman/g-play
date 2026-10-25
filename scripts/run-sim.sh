#!/bin/sh
# Install and launch the built app on the Simulator, then save a screenshot.
# Usage: scripts/run-sim.sh [screenshot.png] [launch args...]
cd "$(dirname "$0")/.."
SIM="${SIM_NAME:-iPhone 17 Pro}"
OUT="${1:-build/screenshot.png}"; shift 2>/dev/null
OS="${SIM_OS:-26.5}"
UDID=$(xcrun simctl list devices available -j | python3 -c "
import json, sys
d = json.load(sys.stdin)['devices']
print(next(x['udid'] for k, v in d.items() if k.endswith('iOS-' + '$OS'.replace('.', '-')) for x in v if x['name'] == '$SIM'))")
xcrun simctl boot "$UDID" 2>/dev/null
xcrun simctl install "$UDID" build/Build/Products/Debug-iphonesimulator/PlayIt.app
xcrun simctl terminate "$UDID" com.greggman.playit 2>/dev/null
xcrun simctl launch "$UDID" com.greggman.playit "$@" >/dev/null
sleep "${WAIT:-3}"
xcrun simctl io "$UDID" screenshot "$OUT" >/dev/null 2>&1 && echo "$OUT"
