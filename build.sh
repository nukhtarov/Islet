#!/bin/zsh
# Builds Islet.app next to this script.
set -e
cd "$(dirname "$0")"
swift build -c release
APP=Islet.app
rm -rf $APP
mkdir -p $APP/Contents/MacOS
cp .build/release/Islet $APP/Contents/MacOS/
cat > $APP/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Islet</string>
  <key>CFBundleIdentifier</key><string>local.islet</string>
  <key>CFBundleExecutable</key><string>Islet</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSLocalNetworkUsageDescription</key><string>Принимать текст с телефона в локальной сети.</string>
  <key>NSBonjourServices</key><array><string>_http._tcp</string></array>
</dict></plist>
PLIST
codesign --force -s - $APP
echo "Built $(pwd)/$APP"
