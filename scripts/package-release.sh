#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="PomodoroAuto"
BUNDLE_ID="com.pomodoroauto.app"
VERSION_INPUT="${1:-$(date +"%Y%m%d.%H%M%S")}"
SAFE_VERSION="${VERSION_INPUT//\//-}"
OUTPUT_DIR="${2:-dist}"

if ! command -v swift >/dev/null 2>&1; then
    echo "Error: swift is not available in PATH"
    exit 1
fi

if ! command -v ditto >/dev/null 2>&1; then
    echo "Error: ditto is not available in PATH"
    exit 1
fi

if ! command -v hdiutil >/dev/null 2>&1; then
    echo "Error: hdiutil is not available in PATH"
    exit 1
fi

echo "Building release binary..."
swift build --configuration release
BUILD_BIN_DIR="$(swift build --configuration release --show-bin-path)"
EXECUTABLE_PATH="$BUILD_BIN_DIR/$APP_NAME"

if [[ ! -f "$EXECUTABLE_PATH" ]]; then
    echo "Error: executable not found at $EXECUTABLE_PATH"
    exit 1
fi

APP_PATH="$OUTPUT_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_PATH/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
DMG_STAGING_DIR="$OUTPUT_DIR/dmg-staging"

mkdir -p "$OUTPUT_DIR"

rm -rf "$APP_PATH"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"

cp "$EXECUTABLE_PATH" "$APP_MACOS/$APP_NAME"
chmod +x "$APP_MACOS/$APP_NAME"

RESOURCE_BUNDLE="$(find "$BUILD_BIN_DIR" -maxdepth 1 -name "${APP_NAME}_*.bundle" -print -quit || true)"
if [[ -n "$RESOURCE_BUNDLE" ]]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_PATH/"
else
    echo "Warning: SwiftPM resource bundle not found; localized resources may be missing."
fi

APP_ICON="$ROOT_DIR/Assets/Icons/AppIcon.icns"
if [[ -f "$APP_ICON" ]]; then
    cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"
else
    echo "Warning: AppIcon.icns not found at $APP_ICON"
fi

cat > "$APP_CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$SAFE_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$SAFE_VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

ZIP_NAME="$APP_NAME-$SAFE_VERSION-macOS.zip"
ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

DMG_NAME="$APP_NAME-$SAFE_VERSION-macOS.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
rm -f "$DMG_PATH"
rm -rf "$DMG_STAGING_DIR"
mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_PATH" "$DMG_STAGING_DIR/"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"
rm -rf "$DMG_STAGING_DIR"

echo "Release packages created:"
echo "- $ZIP_PATH"
echo "- $DMG_PATH"
