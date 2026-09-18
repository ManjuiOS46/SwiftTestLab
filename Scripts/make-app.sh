#!/bin/bash
# Wraps the built executable in a minimal .app bundle, so SwiftTestLab gets a Dock
# icon and a proper menu bar. `swift run SwiftTestLab` works without this.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="1.0"
APP="$PWD/SwiftTestLab.app"

echo "Building release binary…"
swift build -c release --product SwiftTestLab

echo "Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/SwiftTestLab" "$APP/Contents/MacOS/SwiftTestLab"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SwiftTestLab</string>
    <key>CFBundleIdentifier</key>
    <string>com.swifttestlab.app</string>
    <key>CFBundleName</key>
    <string>SwiftTestLab</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "Done. Open it with: open '$APP'"
