#!/bin/sh
# Updates the String Catalog from the last Simulator build (Xcode does this
# automatically when building in the IDE).
cd "$(dirname "$0")/.."
xcrun xcstringstool sync PlayIt/Resources/Localizable.xcstrings \
  --stringsdata $(find build/Build/Intermediates.noindex/PlayIt.build -name "*.stringsdata")
