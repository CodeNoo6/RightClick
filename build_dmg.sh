#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEME="RightClick+"
BUNDLE_ID="gimomagic.RightClick-"
TEAM_ID="653RS235MN"
SIGN_IDENTITY="Developer ID Application: Ruben Camargo (653RS235MN)"
APPLE_ID="rubenchoortegon@gmail.com"
APPLE_PASSWORD="btzm-tfyx-pjsu-zbsf"
OUTPUT_DMG="/Users/rubencamargoortegon/Documents/GitHubGimo/rightclickplus-site/RightClick+.dmg"
ARCHIVE_PATH="/tmp/RightClickPlus.xcarchive"
EXPORT_PATH="/tmp/RightClickPlus_export"
APP_PATH="$EXPORT_PATH/RightClick+.app"
BACKGROUND_SRC="$PROJECT_DIR/dmg_bg.png"

echo "▶ Building archive..."
xcodebuild archive \
  -project "$PROJECT_DIR/RightClick+.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=macOS" \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  | grep -E "error:|warning:|Build succeeded|Build FAILED" || true

echo "▶ Exporting app..."
cat > /tmp/export_options.plist << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>teamID</key>
  <string>$TEAM_ID</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>signingCertificate</key>
  <string>$SIGN_IDENTITY</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist /tmp/export_options.plist \
  | grep -E "error:|Export succeeded|Export FAILED" || true

echo "▶ Verifying code signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "▶ Creating DMG..."
rm -f "$OUTPUT_DMG"

BG_PATH="$BACKGROUND_SRC"

create-dmg \
  --volname "RightClickPlus" \
  --background "$BG_PATH" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --text-size 16 \
  --icon "RightClick+.app" 150 200 \
  --app-drop-link 450 200 \
  --no-internet-enable \
  "$OUTPUT_DMG" \
  "$APP_PATH"

echo "▶ Signing DMG..."
codesign --sign "$SIGN_IDENTITY" --timestamp "$OUTPUT_DMG"

echo "▶ Notarizing DMG..."
xcrun notarytool submit "$OUTPUT_DMG" \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_PASSWORD" \
  --team-id "$TEAM_ID" \
  --wait

echo "▶ Stapling ticket..."
xcrun stapler staple "$OUTPUT_DMG"

echo "▶ Verifying notarization..."
spctl --assess --type open --context context:primary-signature --verbose "$OUTPUT_DMG"

echo ""
echo "✅ Done: $OUTPUT_DMG"
