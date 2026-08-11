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

# The profile lives in a data-protection keychain that `security` can't reliably
# probe, so we verify via `notarytool history` — a network call that can flap.
# Retry a few times so a transient hiccup doesn't masquerade as a missing profile;
# the authoritative check is the `submit` step, which fails clearly on bad creds.
PROFILE_OK=0
for _ in 1 2 3; do
  if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    PROFILE_OK=1
    break
  fi
  sleep 3
done
if [ "$PROFILE_OK" -eq 0 ]; then
  echo "warning: notarytoolプロファイル '$NOTARY_PROFILE' の事前確認に失敗しました(ネットワークの一時障害か、未作成)。" >&2
  echo "  未作成の場合は次で作成してください:" >&2
  echo "  xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <Apple IDのメールアドレス> --team-id $TEAM_ID --password <Appサインイン用Appleパスワード>" >&2
  echo "  作成済みならこのまま続行します(submit時に認証されます)。" >&2
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

echo "==> verifying staple"
xcrun stapler validate "$APP_PATH"

# syspolicy_check is Apple's current pre-distribution verifier (macOS 14+). It is
# far more reliable than `spctl -a`, which can fail with "Too many open files"
# when syspolicyd has exhausted its descriptors — an environment fault unrelated
# to the app.
echo "==> pre-distribution check"
if command -v syspolicy_check >/dev/null 2>&1; then
  syspolicy_check distribution "$APP_PATH"
else
  spctl -a -vv "$APP_PATH" 2>&1 ||
    echo "warning: spctlの評価に失敗(環境要因の可能性)。stapler validateが成功していれば配布可能" >&2
fi

echo "==> regenerating DMG"
# Launching the app writes Contents/com.apple.provenance into the bundle, which
# changes its hash and silently invalidates the stapled ticket. Ship that and
# Gatekeeper calls the download "damaged", so refuse to package it.
if [ -e "$APP_PATH/Contents/com.apple.provenance" ]; then
  echo "error: $APP_PATH に com.apple.provenance があります(公証後にアプリを起動した形跡)。" >&2
  echo "  stapleチケットが無効になっているため、再ビルドからやり直してください:" >&2
  echo "  REPLIER_SIGN_IDENTITY='Developer ID Application' Scripts/build-app.sh && Scripts/notarize.sh" >&2
  exit 1
fi
# The app is already Developer ID signed at this point (checked above), so sign
# the disk image with the same identity — Apple expects both to be signed.
REPLIER_SIGN_IDENTITY="${REPLIER_SIGN_IDENTITY:-Developer ID Application}" Scripts/make-dmg.sh

# A staple ticket is looked up by the target's own hash, so the DMG must be
# notarized itself before it can be stapled (the app's ticket doesn't cover it).
echo "==> notarizing DMG"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> stapling ticket to DMG"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

# Final gate: what users actually double-click is the app *inside* the DMG, so
# validate that copy rather than trusting the staging one.
echo "==> verifying the app inside the DMG"
MOUNT_POINT="$(mktemp -d)"
hdiutil attach "$DMG_PATH" -nobrowse -readonly -mountpoint "$MOUNT_POINT" >/dev/null
if ! xcrun stapler validate "$MOUNT_POINT/Replier.app" >/dev/null 2>&1; then
  hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
  rmdir "$MOUNT_POINT" 2>/dev/null || true
  echo "error: DMG内のReplier.appにstapleチケットがありません。配布してはいけません。" >&2
  exit 1
fi
codesign --verify --deep --strict "$MOUNT_POINT/Replier.app"
if command -v syspolicy_check >/dev/null 2>&1; then
  syspolicy_check distribution "$MOUNT_POINT/Replier.app"
fi
hdiutil detach "$MOUNT_POINT" >/dev/null
rmdir "$MOUNT_POINT" 2>/dev/null || true
echo "DMG内のアプリ: 署名・stapleともに検証OK"

echo "==> done"
echo "Notarized app: $ROOT_DIR/$APP_PATH"
echo "Notarized DMG: $ROOT_DIR/$DMG_PATH"
