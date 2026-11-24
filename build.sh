#!/bin/sh
# Builds "blackroija.app" next to this script.
# Compiles into a staging folder first, so a failed build leaves the
# current app in place.
set -e
cd "$(dirname "$0")"
VERSION="${VERSION:-0.1}"
APP="blackroija.app"
STAGE=".build-staging"
rm -rf "./$STAGE"
mkdir -p "./$STAGE/$APP/Contents/MacOS"
cat > "./$STAGE/$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>blackroija</string>
  <key>CFBundleIdentifier</key><string>local.blackroija</string>
  <key>CFBundleExecutable</key><string>blackroija</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
</dict>
</plist>
EOF
swiftc -O -parse-as-library blackroija.swift -o "./$STAGE/$APP/Contents/MacOS/blackroija"
rm -rf "./$APP"
mv "./$STAGE/$APP" "./$APP"
rm -rf "./$STAGE"
echo "Built $(pwd)/$APP"
