#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "🍅 PomodoroAuto - Build & Install"
echo ""

# Check if Swift is available
if ! command -v swift &> /dev/null; then
    echo "❌ Error: Swift is not installed"
    echo "   Install Xcode or Swift toolchain from https://swift.org"
    exit 1
fi

# Build
echo "📦 Building..."
swift build --configuration release

# Resolve build output path for resources
BUILD_BIN_DIR="$(swift build --configuration release --show-bin-path)"

# Get architecture
ARCH=$(uname -m)
BUILD_DIR=".build/release"
BUILD_VERSION=$(date +"%Y%m%d.%H%M%S")

VOLUME_DEVICE="$(df "$SCRIPT_DIR" | tail -1 | awk '{print $1}')"
FILESYSTEM_TYPE="local"
if [[ "$VOLUME_DEVICE" == //* ]]; then
    FILESYSTEM_TYPE="smbfs"
fi
INSTALL_DIR="$SCRIPT_DIR"
if [[ "$FILESYSTEM_TYPE" == "smbfs" ]]; then
    INSTALL_DIR="$HOME/Applications"
    mkdir -p "$INSTALL_DIR"
    echo "ℹ️  Detected SMB workspace; installing app to local disk at $INSTALL_DIR"
fi

# Create app bundle
APP_PATH="$INSTALL_DIR/PomodoroAuto.app"
APP_CONTENTS="$APP_PATH/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_MODULE_BUNDLE_PARENT="$APP_PATH"
APP_ICON="$SCRIPT_DIR/Assets/Icons/AppIcon.icns"

echo "📁 Creating app bundle..."
rm -rf "$APP_PATH"
mkdir -p "$APP_MACOS"
mkdir -p "$APP_RESOURCES"

# Copy executable
cp "$BUILD_DIR/PomodoroAuto" "$APP_MACOS/"

# Copy SwiftPM resource bundle (localizations, assets).
# SwiftPM's generated Bundle.module accessor for this executable target
# resolves from Bundle.main.bundleURL, which points at the .app root.
RESOURCE_BUNDLE=$(find "$BUILD_BIN_DIR" -maxdepth 1 -name "PomodoroAuto_*.bundle" -print -quit)
if [[ -n "$RESOURCE_BUNDLE" ]]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_MODULE_BUNDLE_PARENT/"
else
    echo "⚠️  Warning: Resource bundle not found; localized strings may not load."
fi

# Copy app icon
if [[ ! -f "$APP_ICON" ]]; then
    echo "❌ Error: App icon not found at $APP_ICON"
    echo "   Generate the icon at Assets/Icons/AppIcon.icns before installing."
    exit 1
fi
cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"

# Create Info.plist
cat > "$APP_CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PomodoroAuto</string>
    <key>CFBundleIdentifier</key>
    <string>com.pomodoroauto.app</string>
    <key>CFBundleName</key>
    <string>PomodoroAuto</string>
    <key>CFBundleDisplayName</key>
    <string>PomodoroAuto</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$BUILD_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# Set executable permission
chmod +x "$APP_MACOS/PomodoroAuto"

echo ""
echo "✅ Build complete!"
echo "📦 App created at: $APP_PATH"
if [[ "$FILESYSTEM_TYPE" == "smbfs" ]]; then
    echo "ℹ️  SMB volume detected; run the local copy above to avoid network volume launch failures."
fi
echo ""
echo "🚀 To run: open $APP_PATH"
echo ""
echo "⚠️  First time setup:"
echo "   1. Open System Settings → Privacy & Security"
echo "   2. Go to Accessibility"
echo "   3. Add PomodoroAuto or click 'Open Anyway' if prompted"
echo ""

# Offer to launch immediately
read -p "Launch PomodoroAuto now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$APP_PATH"
fi
