#!/usr/bin/env bash
# Packages dist/Replier.app into a drag-install DMG at dist/Replier.dmg (or the
# given output path). Requires dist/Replier.app to already exist (run
# Scripts/build-app.sh first).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DIST_DIR="dist"
APP_NAME="Replier.app"
APP_PATH="$DIST_DIR/$APP_NAME"
VOLUME_NAME="Replier"
OUTPUT_PATH="${1:-$DIST_DIR/Replier.dmg}"

if [ ! -d "$APP_PATH" ]; then
  echo "error: $APP_PATH not found. Run Scripts/build-app.sh first." >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d -t replier-dmg)"
cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

echo "==> staging DMG contents"
ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME"
ln -s /Applications "$STAGING_DIR/Applications"

mkdir -p "$(dirname "$OUTPUT_PATH")"
rm -f "$OUTPUT_PATH"

echo "==> creating $OUTPUT_PATH"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$OUTPUT_PATH"

# Apple recommends signing the disk image itself, not just the app inside it.
# Skipped for ad-hoc dev builds, which have no Developer ID to sign with.
SIGN_IDENTITY="${REPLIER_SIGN_IDENTITY:--}"
if [ "$SIGN_IDENTITY" != "-" ]; then
  echo "==> signing DMG ($SIGN_IDENTITY)"
  codesign --sign "$SIGN_IDENTITY" --timestamp "$OUTPUT_PATH"
  codesign --verify --verbose=2 "$OUTPUT_PATH"
fi

echo "==> done"
echo "DMG: $ROOT_DIR/$OUTPUT_PATH"
echo "--- hdiutil imageinfo (Format) ---"
hdiutil imageinfo "$OUTPUT_PATH" | grep "Format:"
