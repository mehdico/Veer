#!/usr/bin/env bash
# Build Veer, sign it with a Developer ID Application certificate, notarize,
# staple, and produce a cask-ready zip + checksum.
#
# Prerequisites (one-time setup):
#   1. A "Developer ID Application" certificate — create it in Xcode under
#      Settings → Accounts → Manage Certificates → "+" → Developer ID Application.
#   2. Notarytool credentials stored in the keychain:
#        xcrun notarytool store-credentials veer-notary \
#          --apple-id "you@example.com" --team-id "QQSK64JV3C" \
#          --password "app-specific-password"
#      (or pass --key / --key-id / --issuer for an App Store Connect API key.)
#
# Usage:
#   ./make-release.sh                 # writes dist/Veer-<version>.zip
#   NOTARY_PROFILE=my-profile ./make-release.sh
#   SIGNING_IDENTITY="Developer ID Application: Me (TEAMID)" ./make-release.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$SCRIPT_DIR/Veer.xcodeproj"
SCHEME="Veer"
DERIVED_DATA="$SCRIPT_DIR/.build"
BUILT_APP="$DERIVED_DATA/Build/Products/Release/$SCHEME.app"
DIST_DIR="$SCRIPT_DIR/dist"
NOTARY_PROFILE="${NOTARY_PROFILE:-veer-notary}"

echo "▸ Finding a Developer ID Application identity…"
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
    IDENTITY="$SIGNING_IDENTITY"
else
    IDENTITY="$(
        security find-identity -v -p codesigning 2>/dev/null \
        | awk -F'"' '/Developer ID Application/ { print $2; exit }'
    )"
fi
if [[ -z "$IDENTITY" ]]; then
    echo "error: no 'Developer ID Application' certificate found in your keychain." >&2
    echo "  Create one in Xcode → Settings → Accounts → Manage Certificates, then rerun." >&2
    echo "  (Apple Development certificates can't be used for distribution.)" >&2
    exit 1
fi
echo "▸ Signing with: $IDENTITY"

echo "▸ Building $SCHEME (Release)…"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_IDENTITY="$IDENTITY" \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    build

if [[ ! -d "$BUILT_APP" ]]; then
    echo "error: build product not found at: $BUILT_APP" >&2
    exit 1
fi

echo "▸ Verifying signature…"
codesign --verify --deep --strict "$BUILT_APP"
if ! codesign -dv "$BUILT_APP" 2>&1 | grep -q "runtime"; then
    echo "error: hardened runtime is not enabled (ENABLE_HARDENED_RUNTIME=YES is required for notarization)." >&2
    exit 1
fi

VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$BUILT_APP/Contents/Info.plist")"
ZIP_NAME="Veer-$VERSION.zip"
mkdir -p "$DIST_DIR"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

echo "▸ Zipping $ZIP_NAME…"
( cd "$DERIVED_DATA/Build/Products/Release" \
  && ditto -c -k --sequesterRsrc --keepParent "$SCHEME.app" "$ZIP_PATH" )

echo "▸ Submitting for notarization (profile: $NOTARY_PROFILE)…"
if ! xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait; then
    echo "error: notarization failed or no credentials found." >&2
    echo "  Store credentials with:" >&2
    echo "    xcrun notarytool store-credentials $NOTARY_PROFILE \\" >&2
    echo "      --apple-id \"you@example.com\" --team-id \"<TEAMID>\" --password \"app-specific-password\"" >&2
    exit 1
fi

echo "▸ Stapling the notarization ticket…"
xcrun stapler staple "$BUILT_APP"
xcrun stapler validate "$BUILT_APP"

echo "▸ Re-zipping the stapled app…"
( cd "$DERIVED_DATA/Build/Products/Release" \
  && ditto -c -k --sequesterRsrc --keepParent "$SCHEME.app" "$ZIP_PATH" )

echo "▸ Verifying Gatekeeper acceptance…"
spctl --assess --type execute --verbose=2 "$BUILT_APP"

SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{ print $1 }')"

echo ""
echo "✔ Release artifact: $ZIP_PATH"
echo ""
echo "  Upload it to the GitHub release (tag v$VERSION):"
echo "    gh release upload v$VERSION \"$ZIP_PATH\""
echo ""
echo "  Cask values for Casks/v/veer.rb:"
echo "    version \"$VERSION\""
echo "    sha256 \"$SHA256\""
echo "    url \"https://github.com/mehdico/Veer/releases/download/v$VERSION/$ZIP_NAME\""
