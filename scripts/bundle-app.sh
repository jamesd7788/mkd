#!/bin/bash
set -euo pipefail

APP_NAME="mkd"
BUILD_DIR=$(swift build -c release --show-bin-path)
BINARY="$BUILD_DIR/$APP_NAME"
BUNDLE_DIR="$BUILD_DIR/$APP_NAME.app"

if [ ! -f "$BINARY" ]; then
    echo "error: binary not found at $BINARY"
    echo "run 'swift build -c release' first"
    exit 1
fi

rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

cp "$BINARY" "$BUNDLE_DIR/Contents/MacOS/$APP_NAME"

# copy resource bundle
RESOURCE_BUNDLE=$(find "$BUILD_DIR" -name "${APP_NAME}_${APP_NAME}.bundle" -type d | head -1)
if [ -n "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$BUNDLE_DIR/Contents/Resources/"
fi

cat > "$BUNDLE_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>mkd</string>
    <key>CFBundleIdentifier</key>
    <string>com.mkd.viewer</string>
    <key>CFBundleName</key>
    <string>mkd</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "bundled: $BUNDLE_DIR"
