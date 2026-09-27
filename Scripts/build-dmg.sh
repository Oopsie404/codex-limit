#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="$ROOT/dist/Codex Limit.app"
DMG="$ROOT/dist/CodexLimit-macos-0.1.4.dmg"
STAGE="$(mktemp -d -t codex-limit-dmg)"
trap 'rm -rf "$STAGE"' EXIT

./Scripts/build-app.sh >/dev/null
cp -R "$APP" "$STAGE/Codex Limit.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Codex Limit" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
echo "$DMG"
