#!/usr/bin/env bash
# Build the Veer app in Release configuration and copy Veer.app to a folder.
#
# Usage:
#   ./make-app.sh                 # copies Veer.app next to this script
#   ./make-app.sh ~/Some/Folder   # copies Veer.app to that folder
#
# Requires Xcode (or Command Line Tools). The build cache lives in .build/
# (gitignored), so repeat runs rebuild only what changed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$SCRIPT_DIR/Veer.xcodeproj"
SCHEME="Veer"
DERIVED_DATA="$SCRIPT_DIR/.build"
DEST_DIR="${1:-$SCRIPT_DIR}"

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "error: xcodebuild not found. Install Xcode or the Command Line Tools." >&2
    exit 1
fi

echo "▸ Building $SCHEME (Release)…"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    build

BUILT_APP="$DERIVED_DATA/Build/Products/Release/$SCHEME.app"
if [[ ! -d "$BUILT_APP" ]]; then
    echo "error: build product not found at: $BUILT_APP" >&2
    exit 1
fi

mkdir -p "$DEST_DIR"
if [[ -e "$DEST_DIR/$SCHEME.app" ]]; then
    rm -rf "$DEST_DIR/$SCHEME.app"
fi
ditto "$BUILT_APP" "$DEST_DIR/$SCHEME.app"
codesign --verify --deep "$DEST_DIR/$SCHEME.app"

echo "✔ Done: $DEST_DIR/$SCHEME.app"
echo "  Launch it with: open \"$DEST_DIR/$SCHEME.app\""
