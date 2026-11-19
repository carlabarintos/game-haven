#!/bin/zsh
# Double-click in Finder to build Game Haven and play it in the iPhone simulator.
# The first run downloads the simulator (several GB); after that it takes about a minute.
set -e
cd "$(dirname "$0")/ios"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer  # use Xcode without changing the system setting

if ! xcrun simctl list runtimes | grep -q "iOS"; then
  echo "Downloading the iPhone simulator (one time only)..."
  xcodebuild -downloadPlatform iOS
fi

device=$(xcrun simctl list devices available | grep -m1 -E "iPhone [0-9]+ \(" | grep -oE '[0-9A-F-]{36}' || true)
if [[ -z $device ]]; then
  runtime=$(xcrun simctl list runtimes | grep "iOS" | tail -1 | grep -oE 'com\.apple\.CoreSimulator\.SimRuntime\.iOS[^ ]*')
  type=$(xcrun simctl list devicetypes | grep "iPhone" | tail -1 | grep -oE 'com\.apple\.CoreSimulator\.SimDeviceType\.[^)]*')
  device=$(xcrun simctl create "Game Haven iPhone" "$type" "$runtime")
fi

echo "Building..."
xcodegen -q
xcodebuild build -quiet -project GameHaven.xcodeproj -scheme GameHaven -destination "id=$device" \
  -clonedSourcePackagesDirPath .build/spm -derivedDataPath .build/dd

echo "Starting the simulator..."
xcrun simctl bootstatus "$device" -b >/dev/null
# Xcode 27 shows simulators in DeviceHub; older Xcode has Simulator.app.
open "$DEVELOPER_DIR/../Applications/DeviceHub.app" 2>/dev/null || open "$DEVELOPER_DIR/Applications/Simulator.app"
xcrun simctl install "$device" .build/dd/Build/Products/Debug-iphonesimulator/GameHaven.app
xcrun simctl launch "$device" com.gamehaven.GameHaven
echo "Game Haven is running. You can close this window."
