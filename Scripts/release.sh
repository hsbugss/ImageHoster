#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-1.0.0}"
APP_NAME="ImageHoster"
DIST_DIR="$ROOT/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
RELEASE_DIR="$ROOT/release"
ZIP_NAME="$APP_NAME-v$VERSION-macos-arm64.zip"
ZIP_PATH="$RELEASE_DIR/$ZIP_NAME"

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

"$ROOT/Scripts/package-app.sh" >/dev/null

if [[ ! -d "$APP_DIR" ]]; then
  echo "打包失败：找不到 $APP_DIR" >&2
  exit 1
fi

find "$APP_DIR" "$DIST_DIR" -name ".DS_Store" -delete

(
  cd "$DIST_DIR"
  ditto -c -k --keepParent "$APP_NAME.app" "$ZIP_PATH"
)

ARCHIVE_LIST="$(unzip -Z1 "$ZIP_PATH")"

if echo "$ARCHIVE_LIST" | grep -E '(^|/)\.DS_Store$|(^|/)\.build/|(^|/)tmp/|(^|/)imagehoster-build/|UserDefaults|Keychain|upload-history|screenshot' >/dev/null; then
  echo "发布包校验失败：发现不应包含的文件。" >&2
  echo "$ARCHIVE_LIST" >&2
  exit 1
fi

if echo "$ARCHIVE_LIST" | grep -v "^$APP_NAME.app/" >/dev/null; then
  echo "发布包校验失败：zip 只能包含 $APP_NAME.app。" >&2
  echo "$ARCHIVE_LIST" >&2
  exit 1
fi

echo "$ZIP_PATH"
