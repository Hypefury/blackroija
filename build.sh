#!/bin/sh
# Builds "Session Status.app" next to this script.
# Compiles into a staging folder first, so a failed build leaves the
# current app in place.
set -e
cd "$(dirname "$0")"
APP="Session Status.app"
STAGE=".build-staging"
rm -rf "./$STAGE"
mkdir -p "./$STAGE/$APP/Contents/MacOS"
cat > "./$STAGE/$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Session Status</string>
  <key>CFBundleIdentifier</key><string>local.session-status</string>
  <key>CFBundleExecutable</key><string>SessionStatus</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
</dict>
</plist>
EOF
swiftc -O -parse-as-library SessionStatus.swift -o "./$STAGE/$APP/Contents/MacOS/SessionStatus"
rm -rf "./$APP"
mv "./$STAGE/$APP" "./$APP"
rm -rf "./$STAGE"
echo "Built $(pwd)/$APP"
