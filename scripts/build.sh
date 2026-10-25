#!/bin/sh
# Build for the Simulator, printing only errors and warnings.
cd "$(dirname "$0")/.." && xcodegen generate -q && \
xcodebuild -project PlayIt.xcodeproj -scheme PlayIt \
  -destination "platform=iOS Simulator,name=${SIM_NAME:-iPhone 17 Pro},OS=${SIM_OS:-26.5}" \
  -derivedDataPath build "${@:-build}" 2>&1 | grep -E "error:|warning:|BUILD|TEST|Test Suite|passed|failed" | grep -v -e "^ld:" -e appintents | awk '!seen[$0]++' | head -80
