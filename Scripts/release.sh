#!/usr/bin/env bash
# Build a Release Solitaire.app, Developer ID sign with Hardened Runtime,
# notarize via Apple, staple the ticket, and package it as a distributable .dmg.
#
# Usage: ./Scripts/release.sh <version>
#   e.g. ./Scripts/release.sh 1.0.0
#
# Prerequisites (one-time setup — already satisfied on this Mac):
#   - "Developer ID Application: Vincent LAURIAT (KFLACS69T9)" certificate in
#     the login keychain.
#   - notarytool credentials stored under the keychain profile
#     "AppliMacVincentGithub" (shared across Vincent's apps).
#
# Local dry run (build + sign + DMG, no notarization):
#   SKIP_NOTARIZE=1 ./Scripts/release.sh 1.0.0
#
# Outputs release/Solitaire-<version>.dmg, fully notarized.

set -euo pipefail

VERSION="${1:?Usage: ./Scripts/release.sh <version>  (e.g. ./Scripts/release.sh 1.0.0)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# 1. Sanity check: project.yml must declare the same MARKETING_VERSION
if ! grep -q "MARKETING_VERSION: \"$VERSION\"" project.yml; then
  echo "✗ MARKETING_VERSION in project.yml does not match $VERSION" >&2
  grep "MARKETING_VERSION" project.yml | sed 's/^/    /' >&2
  echo "  Bump project.yml first, then re-run." >&2
  exit 1
fi

# 2. Regenerate xcodeproj
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "✗ XcodeGen not installed. brew install xcodegen" >&2
  exit 1
fi
echo "→ xcodegen generate"
xcodegen generate >/dev/null

# 3. Build Release
echo "→ xcodebuild Release"
xcodebuild -project Solitaire.xcodeproj \
  -scheme Solitaire \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | tail -5

APP="$ROOT/build/Build/Products/Release/Solitaire.app"
if [ ! -d "$APP" ]; then
  echo "✗ Build did not produce $APP" >&2
  exit 1
fi

# 4. Stage to a clean directory, Developer ID sign with Hardened Runtime, package.
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Vincent LAURIAT (KFLACS69T9)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-AppliMacVincentGithub}"
ENTITLEMENTS="$ROOT/Solitaire/Solitaire.entitlements"

STAGING_DIR="$(mktemp -d)"
STAGING="$STAGING_DIR/Solitaire.app"
echo "→ Staging to $STAGING_DIR"
ditto --norsrc --noextattr --noacl "$APP" "$STAGING"

codesign_ts() {
  local target="$1"
  local attempt
  for attempt in 1 2 3 4 5; do
    if codesign --force --options runtime --timestamp \
        --entitlements "$ENTITLEMENTS" \
        --sign "$SIGNING_IDENTITY" "$target" 2>&1; then
      return 0
    fi
    if [ "$attempt" -lt 5 ]; then
      echo "  ↻ codesign failed (attempt $attempt/5), retrying in 5s…"
      sleep 5
    fi
  done
  echo "✗ codesign $target failed after 5 attempts" >&2
  return 1
}

echo "→ Codesigning the app with Developer ID + Hardened Runtime + sandbox entitlements"
codesign_ts "$STAGING"
codesign --verify --strict --deep "$STAGING"

RELEASE_DIR="$ROOT/release"
mkdir -p "$RELEASE_DIR"
DMG="$RELEASE_DIR/Solitaire-$VERSION.dmg"
rm -f "$DMG"

echo "→ Creating $DMG"
hdiutil create -volname "Solitaire $VERSION" -srcfolder "$STAGING" \
  -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG" >/dev/null

rm -rf "$STAGING_DIR"

# 5. Notarize the DMG with Apple, then staple the ticket — unless SKIP_NOTARIZE=1.
if [ "${SKIP_NOTARIZE:-0}" = "1" ]; then
  DMG_SIZE=$(ls -lh "$DMG" | awk '{print $5}')
  echo ""
  echo "⚠️  SKIP_NOTARIZE=1 : DMG signé mais NON notarisé, non stapled: $DMG ($DMG_SIZE)"
  exit 0
fi

echo "→ Submitting $DMG to Apple notary service (this takes 2–5 min)"
xcrun notarytool submit "$DMG" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

echo "→ Stapling notarization ticket to the DMG"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

DMG_SIZE=$(ls -lh "$DMG" | awk '{print $5}')
echo ""
echo "✅ Built, signed, notarized and stapled: $DMG ($DMG_SIZE)"
