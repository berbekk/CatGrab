#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

# Без этого в pkg/zip попадают служебные файлы ._* (AppleDouble с расширенными атрибутами).
export COPYFILE_DISABLE=1

APP_NAME="PieMenu"
BUILD_DIR="build"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"
ZIP_PATH="${BUILD_DIR}/${APP_NAME}.zip"
PKG_PATH="${BUILD_DIR}/${APP_NAME}.pkg"
STAGING_DIR="${BUILD_DIR}/dmg"
RW_DMG_PATH="${BUILD_DIR}/${APP_NAME}-rw.dmg"
VOL_NAME="${APP_NAME}"
PKG_SCRIPTS_DIR="${ROOT_DIR}/scripts/pkg"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
NOTARIZE="${NOTARIZE:-0}"
APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-}"
MOUNT_DEVICE=""
MOUNT_POINT=""
INSTALLER_NAME="Install ${APP_NAME}.pkg"

APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${ROOT_DIR}/Sources/PieMenu/Info.plist")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${ROOT_DIR}/Sources/PieMenu/Info.plist")"

use_finder_layout() {
  if [[ "${SKIP_DMG_LAYOUT:-}" == "1" ]]; then
    return 1
  fi
  if [[ "${CI:-}" == "true" ]]; then
    return 1
  fi
  return 0
}

cleanup() {
  if [ -n "${MOUNT_DEVICE}" ]; then
    hdiutil detach "${MOUNT_DEVICE}" >/dev/null 2>&1 || true
  fi
  rm -f "${RW_DMG_PATH}"
}

trap cleanup EXIT

# Одна и та же подпись для приложения и для build.sh (Developer ID, если задан).
if [ -n "${SIGN_IDENTITY}" ]; then
  export CODESIGN_IDENTITY="${SIGN_IDENTITY}"
fi
./build.sh

echo "Creating installer package..."
rm -f "${PKG_PATH}"
chmod +x "${PKG_SCRIPTS_DIR}/preinstall" "${PKG_SCRIPTS_DIR}/postinstall"
xattr -cr "${PKG_SCRIPTS_DIR}" 2>/dev/null || true
pkgbuild \
  --component "${APP_PATH}" \
  --install-location /Applications \
  --scripts "${PKG_SCRIPTS_DIR}" \
  --identifier "${BUNDLE_ID}" \
  --version "${APP_VERSION}" \
  "${PKG_PATH}"

# Подписанный установщик не требует «Открыть все равно» у пользователей.
if [ -n "${PKG_SIGN_IDENTITY:-}" ]; then
  echo "Signing installer package..."
  productsign --sign "${PKG_SIGN_IDENTITY}" "${PKG_PATH}" "${PKG_PATH}.signed"
  mv "${PKG_PATH}.signed" "${PKG_PATH}"
fi

echo "Preparing DMG staging..."
rm -rf "${STAGING_DIR}" "${DMG_PATH}" "${RW_DMG_PATH}" "${ZIP_PATH}"
mkdir -p "${STAGING_DIR}"
cp "${PKG_PATH}" "${STAGING_DIR}/${INSTALLER_NAME}"

echo "Creating zip..."
ditto -c -k --norsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

if use_finder_layout; then
  echo "Creating DMG..."
  hdiutil create \
    -volname "${VOL_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDRW \
    "${RW_DMG_PATH}"

  ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "${RW_DMG_PATH}")"
  MOUNT_DEVICE="$(echo "${ATTACH_OUTPUT}" | awk '/^\/dev\// {print $1; exit}')"
  MOUNT_POINT="$(echo "${ATTACH_OUTPUT}" | grep '/Volumes/' | tail -1 | awk -F'\t' '{print $NF}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  DISK_NAME="$(basename "${MOUNT_POINT}")"

  if [ -z "${MOUNT_DEVICE}" ]; then
    echo "Error: failed to detect mounted DMG device"
    exit 1
  fi
  if [ -z "${MOUNT_POINT}" ] || [ ! -d "${MOUNT_POINT}" ]; then
    echo "Error: failed to detect DMG mount point"
    exit 1
  fi

  osascript <<EOF
tell application "Finder"
  set desktopBounds to bounds of window of desktop
  set screenLeft to item 1 of desktopBounds
  set screenTop to item 2 of desktopBounds
  set screenRight to item 3 of desktopBounds
  set screenBottom to item 4 of desktopBounds
  set screenWidth to screenRight - screenLeft
  set screenHeight to screenBottom - screenTop
  set winWidth to 640
  set winHeight to 480
  set winLeft to round (screenLeft + (screenWidth - winWidth) / 2)
  set winTop to round (screenTop + (screenHeight - winHeight) / 2)
  tell disk "${DISK_NAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    try
      set sidebar width of container window to 0
    end try
    set bounds of container window to {winLeft, winTop, winLeft + winWidth, winTop + winHeight}
    set theViewOptions to icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 128
    set position of item "${INSTALLER_NAME}" of container window to {300, 180}
    update without registering applications
    delay 1
  end tell
end tell
EOF

  if [ -d "${MOUNT_POINT}" ]; then
    bless --folder "${MOUNT_POINT}" --openfolder "${MOUNT_POINT}" >/dev/null 2>&1 || true
  fi

  hdiutil detach "${MOUNT_DEVICE}" >/dev/null 2>&1 || hdiutil detach "${MOUNT_DEVICE}" -force >/dev/null 2>&1
  MOUNT_DEVICE=""

  hdiutil convert "${RW_DMG_PATH}" -format UDZO -imagekey zlib-level=9 -o "${DMG_PATH}"
else
  echo "Creating DMG (CI layout)..."
  hdiutil create \
    -volname "${VOL_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "${DMG_PATH}"
fi

rm -rf "${STAGING_DIR}"

if [ "${NOTARIZE}" = "1" ]; then
  if [ -z "${SIGN_IDENTITY}" ] || [ -z "${APPLE_ID}" ] || [ -z "${APPLE_TEAM_ID}" ] || [ -z "${APPLE_APP_PASSWORD}" ]; then
    echo "Notarization skipped: set SIGN_IDENTITY, APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD and NOTARIZE=1"
    exit 1
  fi

  echo "Submitting for notarization..."
  xcrun notarytool submit "${DMG_PATH}" \
    --apple-id "${APPLE_ID}" \
    --team-id "${APPLE_TEAM_ID}" \
    --password "${APPLE_APP_PASSWORD}" \
    --wait
  xcrun stapler staple "${DMG_PATH}"
fi

echo ""
echo "DMG complete: ${DMG_PATH}"
echo "PKG complete: ${PKG_PATH}"
echo "ZIP complete: ${ZIP_PATH}"
