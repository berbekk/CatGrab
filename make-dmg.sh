#!/bin/bash
# Собирает build/CatGrab.dmg для раздачи: универсальный бинарник (Apple silicon + Intel),
# в окне DMG — приложение и ярлык «Программы».
#
# Подпись и нотаризация необязательны:
#   SIGN_IDENTITY   сертификат для подписи (Developer ID или свой самоподписанный); без него — ad-hoc
#   NOTARIZE=1      отправить на нотаризацию Apple (нужны Developer ID и APPLE_ID, APPLE_TEAM_ID,
#                   APPLE_APP_PASSWORD)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

export COPYFILE_DISABLE=1

APP_NAME="CatGrab"
BUILD_DIR="${CATGRAB_BUILD_DIR:-build}"
if [ -e "${BUILD_DIR}/${APP_NAME}.app" ] && [ ! -w "${BUILD_DIR}/${APP_NAME}.app" ]; then
  BUILD_DIR="${TMPDIR:-/tmp}"
  BUILD_DIR="${BUILD_DIR%/}/catgrab-build"
fi
export CATGRAB_BUILD_DIR="${BUILD_DIR}"
export CATGRAB_ARCHS="${CATGRAB_ARCHS:-arm64 x86_64}"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"
STAGING_DIR="${BUILD_DIR}/dmg-staging"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
NOTARIZE="${NOTARIZE:-0}"
APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-}"

if [ -n "${SIGN_IDENTITY}" ]; then
  export CODESIGN_IDENTITY="${SIGN_IDENTITY}"
fi

# Учётные данные проверяем до сборки, а не после — иначе ошибка всплывает через несколько минут.
if [ "${NOTARIZE}" = "1" ]; then
  if [ -z "${SIGN_IDENTITY}" ] || [ -z "${APPLE_ID}" ] || [ -z "${APPLE_TEAM_ID}" ] || [ -z "${APPLE_APP_PASSWORD}" ]; then
    echo "Notarization requires SIGN_IDENTITY, APPLE_ID, APPLE_TEAM_ID and APPLE_APP_PASSWORD."
    exit 1
  fi
fi

./build.sh
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

rm -rf "${STAGING_DIR}" "${DMG_PATH}"
mkdir -p "${STAGING_DIR}"
ditto --norsrc --noextattr "${APP_PATH}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"

echo "Creating DMG..."
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "${DMG_PATH}"
rm -rf "${STAGING_DIR}"

if [ -n "${SIGN_IDENTITY}" ]; then
  codesign --force --sign "${SIGN_IDENTITY}" "${DMG_PATH}"
fi

if [ "${NOTARIZE}" = "1" ]; then
  echo "Submitting for notarization..."
  xcrun notarytool submit "${DMG_PATH}" \
    --apple-id "${APPLE_ID}" \
    --team-id "${APPLE_TEAM_ID}" \
    --password "${APPLE_APP_PASSWORD}" \
    --wait
  xcrun stapler staple "${DMG_PATH}"
fi

echo "DMG complete: ${DMG_PATH}"
