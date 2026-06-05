#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Decaf"
BUNDLE_ID="com.decaf.menu"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/apple/Products/Release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE="$BUILD_DIR/$APP_NAME"
ICON_FILE="$ROOT_DIR/Resources/Decaf.icns"

cd "$ROOT_DIR"

swift scripts/prepare-app-icons.swift

swift build -c release --arch arm64 --arch x86_64

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
cp "$ICON_FILE" "$RESOURCES_DIR/Decaf.icns"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>Decaf</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSFocusStatusUsageDescription</key>
    <string>Decaf can use Shared Focus Status as an optional Night Mode override.</string>
    <key>NSUserNotificationUsageDescription</key>
    <string>Decaf sends notifications when automatic schedule or focus changes switch modes.</string>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

echo "Built $APP_DIR"
