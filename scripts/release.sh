#!/bin/bash
# Berth release: build (Developer ID), notarize, staple, package, and
# generate a signed Sparkle appcast entry into ./appcast.xml
#
# Version rule: MARKETING_VERSION = major.minor.patch (e.g. 0.1.0);
# CURRENT_PROJECT_VERSION = monotonically increasing integer for Sparkle.
#
# Prerequisites (one-time):
#   1. Developer ID Application certificate in the login keychain.
#   2. Notarization credentials:
#        xcrun notarytool store-credentials berth-notary
#      (Apple ID + app-specific password, or App Store Connect API key.)
#   3. Sparkle EdDSA private key in the keychain (created via generate_keys).
set -euo pipefail
cd "$(dirname "$0")/.."

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
[ -d "$DEVELOPER_DIR" ] || DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export DEVELOPER_DIR

SIGN_HASH="${SIGN_HASH:-72D4152463BB1992518F65C66E8569D29746478B}" # Developer ID Application: Yi Xu
NOTARY_PROFILE="${NOTARY_PROFILE:-berth-notary}"
R2_BUCKET="${R2_BUCKET:-berth-releases}"
PUBLIC_BASE_URL="${PUBLIC_BASE_URL:-https://pub-aa21c73b26d444688ef7db7de0c5f129.r2.dev}"
APP_NAME="Berth"

echo "==> Generating project"
xcodegen generate

echo "==> Building (Release, Developer ID)"
xcodebuild -project Berth.xcodeproj -scheme Berth \
  -configuration Release \
  -derivedDataPath .build/DerivedData \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="$SIGN_HASH" \
  build

APP=".build/DerivedData/Build/Products/Release/$APP_NAME.app"

echo "==> Re-signing nested Sparkle helpers (innermost first)"
FW="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
codesign --force --options runtime --timestamp --sign "$SIGN_HASH" "$FW/Updater.app"
codesign --force --options runtime --timestamp --sign "$SIGN_HASH" "$FW/XPCServices/Installer.xpc"
codesign --force --options runtime --timestamp --sign "$SIGN_HASH" "$FW/XPCServices/Downloader.xpc"
codesign --force --options runtime --timestamp --sign "$SIGN_HASH" "$FW/Autoupdate"
codesign --force --options runtime --timestamp --sign "$SIGN_HASH" "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --options runtime --timestamp --sign "$SIGN_HASH" "$APP"

echo "==> Verifying code signature"
codesign --verify --deep --strict --verbose=2 "$APP"

VERSION=$(defaults read "$PWD/$APP/Contents/Info" CFBundleShortVersionString)
BUILD=$(defaults read "$PWD/$APP/Contents/Info" CFBundleVersion)
echo "==> Version: $VERSION ($BUILD)"

ZIP="Berth-$VERSION.zip"

echo "==> Packaging (pre-notarization)"
rm -rf .build/release && mkdir -p .build/release
ditto -c -k --keepParent "$APP" ".build/release/$ZIP"

echo "==> Notarizing (this can take a few minutes)"
xcrun notarytool submit ".build/release/$ZIP" \
  --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling ticket"
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose=2 "$APP"

echo "==> Repackaging (stapled zip for Sparkle updates)"
rm ".build/release/$ZIP"
ditto -c -k --keepParent "$APP" ".build/release/$ZIP"

echo "==> Building DMG (for manual download/install)"
DMG="Berth-$VERSION.dmg"
STAGING=$(mktemp -d)
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$STAGING" -ov -format UDZO \
  ".build/release/$DMG" >/dev/null
rm -rf "$STAGING"

echo "==> Notarizing DMG"
xcrun notarytool submit ".build/release/$DMG" \
  --keychain-profile "$NOTARY_PROFILE" --wait
echo "==> Stapling DMG"
xcrun stapler staple ".build/release/$DMG"
xcrun stapler validate ".build/release/$DMG"

echo "==> Generating signed appcast"
SPARKLE_BIN=".build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin"
cp appcast.xml .build/release/appcast.xml
"$SPARKLE_BIN/generate_appcast" \
  --download-url-prefix "$PUBLIC_BASE_URL/" \
  .build/release
cp .build/release/appcast.xml appcast.xml
xmllint --noout appcast.xml

cat <<EOF

==> Uploading to R2 ($R2_BUCKET)
EOF
wrangler r2 object put "$R2_BUCKET/$ZIP" --file ".build/release/$ZIP" --content-type application/zip --remote
wrangler r2 object put "$R2_BUCKET/$DMG" --file ".build/release/$DMG" --content-type application/x-apple-diskimage --remote
wrangler r2 object put "$R2_BUCKET/appcast.xml" --file ".build/release/appcast.xml" --content-type application/xml --remote

cat <<EOF

Done. Published:
  - $PUBLIC_BASE_URL/$ZIP (Sparkle updates)
  - $PUBLIC_BASE_URL/$DMG (manual download/install)
  - $PUBLIC_BASE_URL/appcast.xml

Optional:
  git add appcast.xml && git commit -m "chore: appcast for v$VERSION"
EOF
