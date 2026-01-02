#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="LocalTranscribePaste"
SCHEME="LocalTranscribePaste"
APP_NAME="R3VIB3"
CONFIG="Release"

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun not found. Install Xcode Command Line Tools."
  exit 1
fi

BUILD_ROOT="$(pwd)/build"
ARCHIVE_PATH="$BUILD_ROOT/${APP_NAME}.xcarchive"
EXPORT_PATH="$BUILD_ROOT/Export"
ZIP_PATH="$BUILD_ROOT/${APP_NAME}-macOS.zip"

rm -rf "$BUILD_ROOT"

xcodebuild \
  -project "${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration "$CONFIG" \
  -archivePath "$ARCHIVE_PATH" \
  clean archive

cat > "$BUILD_ROOT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>compileBitcode</key>
  <false/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$BUILD_ROOT/ExportOptions.plist"

APP_PATH="$EXPORT_PATH/${APP_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
  echo "Export failed: app not found at $APP_PATH"
  exit 1
fi

if [ -z "${NOTARY_PROFILE:-}" ]; then
  echo "NOTARY_PROFILE not set. Create one with:"
  echo "  xcrun notarytool store-credentials R3VIB3_Notary --apple-id you@apple.com --team-id TEAM_ID --password app-specific-password"
  echo "Then run: NOTARY_PROFILE=R3VIB3_Notary ./scripts/release.sh"
  exit 1
fi

xcrun notarytool submit "$APP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP_PATH"

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

shasum -a 256 "$ZIP_PATH" > "$ZIP_PATH.sha256"

echo "Release ready:"
echo "  App: $APP_PATH"
echo "  Zip: $ZIP_PATH"
echo "  SHA: $(cat "$ZIP_PATH.sha256")"
