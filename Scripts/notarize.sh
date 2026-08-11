#!/usr/bin/env bash
# Notarizes dist/Replier.app (must already be signed with a Developer ID
# Application identity via `REPLIER_SIGN_IDENTITY="Developer ID Application"
# Scripts/build-app.sh`), staples the ticket, regenerates the DMG, and staples
# that too.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DIST_DIR="dist"
APP_NAME="Replier.app"
APP_PATH="$DIST_DIR/$APP_NAME"
ZIP_PATH="$DIST_DIR/Replier-notarize.zip"
DMG_PATH="$DIST_DIR/Replier.dmg"
NOTARY_PROFILE="replier-notary"
TEAM_ID="NV829FZHNX"

echo "==> checking prerequisites"

if [ ! -d "$APP_PATH" ]; then
  echo "error: $APP_PATH が見つかりません。先に Scripts/build-app.sh を実行してください" >&2
  exit 1
fi

SIGN_INFO="$(codesign -dvvv "$APP_PATH" 2>&1 || true)"
if ! echo "$SIGN_INFO" | grep -q "Authority=Developer ID Application"; then
  echo "error: ad-hoc署名のままです。REPLIER_SIGN_IDENTITY='Developer ID Application' Scripts/build-app.sh で再ビルドしてください" >&2
  exit 1
fi

if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "error: notarytoolのキーチェーンプロファイル '$NOTARY_PROFILE' が見つかりません。以下のコマンドで作成してください:" >&2
  echo "  xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <Apple IDのメールアドレス> --team-id $TEAM_ID --password <Appサインイン用Appleパスワード>" >&2
  echo "  (App用Appleパスワードは https://account.apple.com/account/manage で発行)" >&2
  exit 1
fi

cleanup() {
  rm -f "$ZIP_PATH"
}
trap cleanup EXIT

echo "==> creating zip for submission"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "==> submitting for notarization (this can take a few minutes)"
SUBMIT_EXIT=0
SUBMIT_OUTPUT="$(xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1)" || SUBMIT_EXIT=$?
echo "$SUBMIT_OUTPUT"

SUBMIT_ID="$(echo "$SUBMIT_OUTPUT" | grep -m1 '^  *id:' | awk '{print $2}')"

if [ "$SUBMIT_EXIT" -ne 0 ] || ! echo "$SUBMIT_OUTPUT" | grep -q "status: Accepted"; then
  echo "error: notarizationが失敗しました" >&2
  if [ -n "$SUBMIT_ID" ]; then
    echo "詳細ログを確認するには:" >&2
    echo "  xcrun notarytool log $SUBMIT_ID --keychain-profile $NOTARY_PROFILE" >&2
  fi
  exit 1
fi

echo "==> stapling ticket to app"
xcrun stapler staple "$APP_PATH"

echo "==> verifying with spctl"
SPCTL_OUTPUT="$(spctl -a -vv "$APP_PATH" 2>&1)" || true
echo "$SPCTL_OUTPUT"
if ! echo "$SPCTL_OUTPUT" | grep -q "accepted"; then
  echo "error: spctlがacceptedを返しませんでした" >&2
  exit 1
fi

echo "==> regenerating DMG"
Scripts/make-dmg.sh

echo "==> stapling ticket to DMG"
xcrun stapler staple "$DMG_PATH"

echo "==> done"
echo "Notarized app: $ROOT_DIR/$APP_PATH"
echo "Notarized DMG: $ROOT_DIR/$DMG_PATH"
