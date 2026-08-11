#!/usr/bin/env bash
# Full local release flow: bumps the app version (project.yml is the single
# source of truth), commits, tags, builds + signs with a Developer ID
# identity, notarizes, packages the DMG/zip assets, then (after typing "yes"
# at a confirmation prompt) pushes the tag and creates a GitHub Release.
#
# Usage: Scripts/release.sh [--dry-run] X.Y.Z
#
# --dry-run stops after producing the signed/notarized/packaged assets,
# before pushing or creating the GitHub Release.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DRY_RUN=0
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=1
      ;;
    *)
      POSITIONAL+=("$arg")
      ;;
  esac
done

if [ "${#POSITIONAL[@]}" -ne 1 ]; then
  echo "usage: $(basename "$0") [--dry-run] X.Y.Z" >&2
  exit 1
fi

VERSION="${POSITIONAL[0]}"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: version must be in X.Y.Z format (got: '$VERSION')" >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "error: working tree is not clean. Commit or stash changes first." >&2
  exit 1
fi

if [ "$DRY_RUN" -eq 0 ] && ! command -v gh >/dev/null 2>&1; then
  echo "error: gh コマンドが見つかりません。'brew install gh' でインストールしてください" >&2
  exit 1
fi

PROJECT_YML="project.yml"
TAG="v${VERSION}"

if ! grep -qE 'CFBundleShortVersionString: "[0-9]+\.[0-9]+\.[0-9]+"' "$PROJECT_YML"; then
  echo "error: could not find CFBundleShortVersionString in $PROJECT_YML" >&2
  exit 1
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "error: tag $TAG already exists" >&2
  exit 1
fi

echo "==> updating CFBundleShortVersionString to $VERSION in $PROJECT_YML"
sed -i '' -E "s/(CFBundleShortVersionString: \")[0-9]+\.[0-9]+\.[0-9]+(\")/\\1${VERSION}\\2/" "$PROJECT_YML"

if ! grep -qE "CFBundleShortVersionString: \"${VERSION}\"" "$PROJECT_YML"; then
  echo "error: failed to update CFBundleShortVersionString in $PROJECT_YML" >&2
  exit 1
fi

# ReplierCore.version and its test track the release version too — keep them in sync.
CORE_SWIFT="Sources/ReplierCore/ReplierCore.swift"
CORE_TEST="Tests/ReplierCoreTests/ReplierCoreTests.swift"
echo "==> updating ReplierCore.version to $VERSION"
sed -i '' -E "s/(static let version = \")[0-9]+\.[0-9]+\.[0-9]+(\")/\\1${VERSION}\\2/" "$CORE_SWIFT"
sed -i '' -E "s/(ReplierCore\.version == \")[0-9]+\.[0-9]+\.[0-9]+(\")/\\1${VERSION}\\2/" "$CORE_TEST"
for f in "$CORE_SWIFT" "$CORE_TEST"; do
  if ! grep -q "${VERSION}" "$f"; then
    echo "error: failed to update version in $f" >&2
    exit 1
  fi
done

echo "==> running tests"
swift test

echo "==> committing version bump"
git add "$PROJECT_YML" "$CORE_SWIFT" "$CORE_TEST"
git commit -m "$(cat <<EOF
chore: bump version to ${VERSION}

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"

echo "==> creating annotated tag ${TAG}"
git tag -a "$TAG" -m "Release ${TAG}"

DMG_PATH="dist/Replier-${TAG}.dmg"
ZIP_PATH="dist/Replier-${TAG}.zip"

echo "==> building signed app (Developer ID Application)"
REPLIER_SIGN_IDENTITY="Developer ID Application" Scripts/build-app.sh

echo "==> notarizing"
Scripts/notarize.sh

echo "==> packaging release assets"
rm -f "$DMG_PATH" "$ZIP_PATH"
cp dist/Replier.dmg "$DMG_PATH"
ditto -c -k --keepParent dist/Replier.app "$ZIP_PATH"

echo
echo "==> release assets ready:"
echo "  $ROOT_DIR/$DMG_PATH"
echo "  $ROOT_DIR/$ZIP_PATH"

if [ "$DRY_RUN" -eq 1 ]; then
  echo
  echo "==> --dry-run: stopping before push / GitHub Release creation."
  exit 0
fi

echo
echo "${TAG} を origin へpushし、GitHub Releaseを作成します。"
read -r -p "続行するには 'yes' と入力してください: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "aborted." >&2
  exit 1
fi

echo "==> pushing main and ${TAG}"
git push origin main "$TAG"

echo "==> creating GitHub Release"
NOTES="## インストール方法

1. \`Replier-${TAG}.dmg\` をダウンロードして開き、\`Replier.app\` を \`Applications\` へドラッグ(zipでも可)
2. メニューバーのアイコンから起動し、オンボーディングでアクセシビリティ権限を許可
3. 動作には [Codex CLI](https://developers.openai.com/codex) のインストールとログイン(ChatGPT サブスクまたはAPIキー)が必要"

gh release create "$TAG" \
  --title "Replier ${TAG}" \
  --notes "$NOTES" \
  --generate-notes \
  "$ZIP_PATH" \
  "$DMG_PATH"

echo
echo "==> done: https://github.com/amaotone/replier/releases/tag/${TAG}"
