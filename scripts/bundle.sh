#!/bin/zsh
# Build and create a proper macOS .app bundle for Rancage

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Rancage"
BUILD_DIR="$PROJECT_DIR/.build/debug"
BUNDLE_DIR="$PROJECT_DIR/build/${APP_NAME}.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_SOURCE="$PROJECT_DIR/assets/logo.png"

echo "Building Rancage..."
cd "$PROJECT_DIR"
swift build

echo "Creating app bundle..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"

# Generate app icon from logo.png
if [ -f "$ICON_SOURCE" ]; then
    echo "Generating app icon..."
    ICONSET="/tmp/rancage_icon.iconset"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"

    sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" > /dev/null 2>&1
    sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" > /dev/null 2>&1
    sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" > /dev/null 2>&1
    sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" > /dev/null 2>&1
    sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" > /dev/null 2>&1
    sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" > /dev/null 2>&1
    sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" > /dev/null 2>&1
    sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" > /dev/null 2>&1
    sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" > /dev/null 2>&1
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" > /dev/null 2>&1

    iconutil -c icns "$ICONSET" -o "$RESOURCES_DIR/AppIcon.icns"
    rm -rf "$ICONSET"
    echo "App icon generated."
else
    echo "⚠️  No icon source found at $ICON_SOURCE, skipping icon generation."
fi

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Rancage</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.rancage.app</string>
    <key>CFBundleName</key>
    <string>Rancage</string>
    <key>CFBundleDisplayName</key>
    <string>Rancage</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
</dict>
</plist>
PLIST

echo ""
echo "✅ Done! App bundle created at: $BUNDLE_DIR"
echo ""
echo "To run:"
echo "  open $BUNDLE_DIR"
echo ""
echo "To install to /Applications:"
echo "  cp -r $BUNDLE_DIR /Applications/"
