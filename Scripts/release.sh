#!/usr/bin/env bash
# Bumps the app version (project.yml is the single source of truth), commits,
# and creates an annotated release tag. Does NOT push.
#
# Usage: Scripts/release.sh 0.2.0
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ "$#" -ne 1 ]; then
  echo "usage: $(basename "$0") X.Y.Z" >&2
  exit 1
fi

VERSION="$1"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: version must be in X.Y.Z format (got: '$VERSION')" >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "error: working tree is not clean. Commit or stash changes first." >&2
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

echo
echo "==> done. Push when ready:"
echo
echo "  git push origin main ${TAG}"
echo
