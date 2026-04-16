#!/bin/bash
set -e

APP_NAME="GoviKey"
BUNDLE_ID="com.gotiengviet.govikey"
VERSION="1.0.0"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
DMG_NAME="$APP_NAME-$VERSION.dmg"

echo "==> Building $APP_NAME..."
swift build -c release

echo "==> Assembling .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "Sources/App/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Copy resources (icon + menubar images)
cp Sources/App/Resources/AppIcon.icns         "$APP_BUNDLE/Contents/Resources/"
cp Sources/App/Resources/menubar_english.png  "$APP_BUNDLE/Contents/Resources/"
cp Sources/App/Resources/menubar_english@2x.png "$APP_BUNDLE/Contents/Resources/"
cp Sources/App/Resources/menubar_vietnamese.png "$APP_BUNDLE/Contents/Resources/"
cp Sources/App/Resources/menubar_vietnamese@2x.png "$APP_BUNDLE/Contents/Resources/"

echo "==> Setting icon..."
# Touch the bundle so Finder refreshes the icon
touch "$APP_BUNDLE"

echo "==> Creating DMG..."
rm -f "$DMG_NAME"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$APP_BUNDLE" \
    -ov \
    -format UDZO \
    "$DMG_NAME"

echo ""
echo "Done! Built: $APP_BUNDLE"
echo "Done! DMG:   $DMG_NAME"
