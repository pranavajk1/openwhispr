#!/bin/sh
# Sign a `npm run pack` output with the personal "OpenWhispr Local Signing"
# identity (self-signed cert in the login keychain). electron-builder only
# accepts Apple-issued identities, so the pack step leaves the bundle unsigned
# and this signs it inside-out: loose helper binaries and native modules under
# Contents/Resources first, then the bundle. No hardened runtime, no notarization.
#
#   npm run pack && sh scripts/local-sign-mac.sh
#   cp -R dist/mac-arm64/OpenWhispr.app /Applications/
set -eu
APP="${1:-dist/mac-arm64/OpenWhispr.app}"
ID="${OPENWHISPR_SIGN_IDENTITY:-OpenWhispr Local Signing}"
count=0
find "$APP/Contents/Resources" -type f \( -perm -u+x -o -name '*.dylib' -o -name '*.node' -o -name '*.so' \) ! -path '*/.*' |
while IFS= read -r f; do
  if file "$f" | grep -q 'Mach-O'; then codesign --force -s "$ID" "$f"; fi
done
codesign --deep --force -s "$ID" "$APP"
codesign --verify --deep --strict "$APP"
codesign -dv "$APP" 2>&1 | grep -E '^(Identifier|Authority)='
