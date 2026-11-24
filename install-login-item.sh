#!/bin/sh
# Opens "blackroija.app" every time you log in to your Mac.
# Run it once after building; run it again if you move this folder.
set -e
cd "$(dirname "$0")"
APP="$(pwd)/blackroija.app"
PLIST="$HOME/Library/LaunchAgents/local.blackroija.plist"
if [ ! -d "$APP" ]; then
  echo "Build the app first: ./build.sh" >&2
  exit 1
fi
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<!-- Opens the blackroija window when you log in to your Mac. -->
<plist version="1.0">
<dict>
  <key>Label</key><string>local.blackroija</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-a</string>
    <string>$APP</string>
  </array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF
echo "blackroija will open at login ($PLIST)."
echo "To stop that: rm \"$PLIST\""
