#!/bin/bash
set -e

APP_NAME="VideoNotes"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building release binary..."
swift build -c release

echo "Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

cp "$BUILD_DIR/$APP_NAME" "$MACOS/$APP_NAME"
cp "Sources/VideoNotes/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "Sources/VideoNotes/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"

echo "Done! Created $APP_BUNDLE"
echo "You can now run: open $APP_BUNDLE"
