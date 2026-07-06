#!/usr/bin/env bash
set -euo pipefail

VERSION="1.1.1"
APP_NAME="Typofix"
BUNDLE_ID="dev.ehrax.typofix"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BINARY_NAME="typofix"

cd "$ROOT_DIR"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"

swift build --disable-sandbox -c release

rm -rf "$APP_DIR" "$DIST_DIR/$APP_NAME-$VERSION.zip"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp ".build/release/$BINARY_NAME" "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
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
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 ehrax. All rights reserved.</string>
</dict>
</plist>
PLIST

developer_id_identity="$(
    security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' \
        | head -n 1
)"

if [[ -n "$developer_id_identity" ]]; then
    echo "Signing with Developer ID Application identity: $developer_id_identity"
    codesign --force --deep --options runtime --timestamp -s "$developer_id_identity" "$APP_DIR"
else
    echo "Signing with ad-hoc identity"
    codesign --force --deep -s - "$APP_DIR"
fi

NOTARY_PROFILE="${NOTARY_PROFILE:-typofix-notary}"
if [[ -n "$developer_id_identity" ]] && xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "Notarizing with keychain profile: $NOTARY_PROFILE"
    ditto -c -k --keepParent "$APP_DIR" "$DIST_DIR/$APP_NAME-notary.zip"
    xcrun notarytool submit "$DIST_DIR/$APP_NAME-notary.zip" --keychain-profile "$NOTARY_PROFILE" --wait
    rm -f "$DIST_DIR/$APP_NAME-notary.zip"
    xcrun stapler staple "$APP_DIR"
else
    echo "Skipping notarization (no Developer ID identity or notary profile '$NOTARY_PROFILE' not found)"
fi

ditto -c -k --keepParent "$APP_DIR" "$DIST_DIR/$APP_NAME-$VERSION.zip"

echo "Built $APP_DIR"
echo "Created $DIST_DIR/$APP_NAME-$VERSION.zip"

open "$DIST_DIR"
