#!/usr/bin/env bash
# Builds Replier.app via XcodeGen + xcodebuild and stages it at dist/Replier.app.
#
# Signing identity is controlled via REPLIER_SIGN_IDENTITY (default "-", i.e.
# ad-hoc, for the normal dev workflow). Set it to "Developer ID Application"
# (or a specific "Developer ID Application: ..." identity string) to produce a
# build ready for notarization; see Scripts/notarize.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT="Replier.xcodeproj"
SCHEME="Replier"
CONFIGURATION="Release"
DERIVED_DATA=".build/xcode"
DIST_DIR="dist"
APP_NAME="Replier.app"
TEAM_ID="NV829FZHNX"

SIGN_IDENTITY="${REPLIER_SIGN_IDENTITY:--}"

echo "==> xcodegen generate"
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen not found on PATH. Install it (e.g. 'brew install xcodegen')." >&2
  exit 1
fi
xcodegen generate --spec project.yml

XCODEBUILD_ARGS=(
  -project "$PROJECT"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -derivedDataPath "$DERIVED_DATA"
  "CODE_SIGN_IDENTITY=$SIGN_IDENTITY"
)

if [ "$SIGN_IDENTITY" != "-" ]; then
  echo "==> checking for Developer ID Application certificate"
  if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo "error: Developer ID Application証明書が見つかりません。Xcode → Settings → Accounts → Manage Certificates から作成してください" >&2
    exit 1
  fi
  # ad-hoc + --timestamp fails offline, so only apply the notarization-ready
  # signing flags when a real identity is in play.
  XCODEBUILD_ARGS+=(
    "OTHER_CODE_SIGN_FLAGS=--timestamp --options=runtime"
    "DEVELOPMENT_TEAM=$TEAM_ID"
    "CODE_SIGN_STYLE=Manual"
  )
fi

echo "==> xcodebuild build ($CONFIGURATION, identity=$SIGN_IDENTITY)"
xcodebuild "${XCODEBUILD_ARGS[@]}" build

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
