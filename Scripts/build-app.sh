#!/usr/bin/env bash
# Builds Replier.app via XcodeGen + xcodebuild and stages it at dist/Replier.app.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT="Replier.xcodeproj"
SCHEME="Replier"
CONFIGURATION="Release"
DERIVED_DATA=".build/xcode"
DIST_DIR="dist"
APP_NAME="Replier.app"

echo "==> xcodegen generate"
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen not found on PATH. Install it (e.g. 'brew install xcodegen')." >&2
  exit 1
fi
xcodegen generate --spec project.yml

echo "==> xcodebuild build ($CONFIGURATION)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

BUILT_APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME"
if [ ! -d "$BUILT_APP" ]; then
  echo "error: expected app bundle not found at $BUILT_APP" >&2
  exit 1
fi

echo "==> staging to $DIST_DIR/$APP_NAME"
rm -rf "$DIST_DIR/$APP_NAME"
mkdir -p "$DIST_DIR"
cp -R "$BUILT_APP" "$DIST_DIR/$APP_NAME"

echo "==> done"
echo "App bundle: $ROOT_DIR/$DIST_DIR/$APP_NAME"
echo "--- codesign -dv ---"
codesign -dv "$DIST_DIR/$APP_NAME"
