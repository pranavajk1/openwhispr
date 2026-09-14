#!/bin/sh
# Sign a `npm run pack` output with the personal "OpenWhispr Local Signing"
# identity (self-signed cert in the login keychain). electron-builder only
# accepts Apple-issued identities, so the pack step leaves the bundle unsigned
# and this signs it inside-out: loose helper binaries and native modules under
# Contents/Resources first, then the bundle. No hardened runtime, no notarization.
#
#   npm run pack && sh scripts/local-sign-mac.sh   (also writes app-update.yml)
#   cp -R dist/mac-arm64/OpenWhispr.app /Applications/
set -eu
APP="${1:-dist/mac-arm64/OpenWhispr.app}"
ID="${OPENWHISPR_SIGN_IDENTITY:-OpenWhispr Local Signing}"

# electron-builder writes app-update.yml only when the pack step itself targets
# dmg/zip; `--dir` + `--prepackaged` never does, and electron-updater's
# downloadUpdate() fails with ENOENT on it. Same content electron-builder emits
# from the publish config (updaterCacheDirName = package name + "-updater").
cat > "$APP/Contents/Resources/app-update.yml" <<'YML'
owner: pranavajk1
repo: openwhispr
provider: github
private: false
updaterCacheDirName: open-whispr-updater
YML
count=0
find "$APP/Contents/Resources" -type f \( -perm -u+x -o -name '*.dylib' -o -name '*.node' -o -name '*.so' \) ! -path '*/.*' |
while IFS= read -r f; do
  if file "$f" | grep -q 'Mach-O'; then codesign --force -s "$ID" "$f"; fi
done
codesign --deep --force -s "$ID" "$APP"
codesign --verify --deep --strict "$APP"
codesign -dv "$APP" 2>&1 | grep -E '^(Identifier|Authority)='
