#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release --arch arm64
ARM_BIN="$(swift build -c release --arch arm64 --show-bin-path)/CodexLimit"
APP="$ROOT/dist/Codex Limit.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ARM_BIN" "$APP/Contents/MacOS/CodexLimit"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
echo "$APP"
