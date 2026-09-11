#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "PieMenu собирается только на macOS 13+."
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "Не найден Swift. Установите Xcode Command Line Tools:"
  echo "  xcode-select --install"
  exit 1
fi

APP_NAME="PieMenu"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app/Contents"
APP_ROOT="${BUILD_DIR}/${APP_NAME}.app"

echo "Building ${APP_NAME}..."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="${BIN_DIR}/${APP_NAME}"

if [ ! -f "${BIN_PATH}" ]; then
  echo "Error: compiled binary not found at ${BIN_PATH}"
  exit 1
fi

echo "Creating app bundle..."
"${ROOT_DIR}/scripts/generate-app-icon.sh"

rm -rf "${APP_ROOT}"
mkdir -p "${BUILD_DIR}"
# Dev-сборка не должна попадать в Spotlight и LaunchServices — иначе рядом с /Applications/PieMenu.app
# появляется дубликат, и Spotlight/«Открыть с помощью» путаются.
touch "${BUILD_DIR}/.metadata_never_index"
mkdir -p "${APP_BUNDLE}/MacOS"
mkdir -p "${APP_BUNDLE}/Resources"

cp "${BIN_PATH}" "${APP_BUNDLE}/MacOS/${APP_NAME}"
cp "Sources/PieMenu/Info.plist" "${APP_BUNDLE}/Info.plist"
printf 'APPL????' > "${APP_BUNDLE}/PkgInfo"
cp "Sources/PieMenu/Resources/AppIcon.icns" "${APP_BUNDLE}/Resources/AppIcon.icns"
if [ -f "Sources/PieMenu/PrivacyInfo.xcprivacy" ]; then
  cp "Sources/PieMenu/PrivacyInfo.xcprivacy" "${APP_BUNDLE}/Resources/PrivacyInfo.xcprivacy"
fi

LIB_RESOURCES_DIR="Sources/PieMenuLib/Resources"
if [ -d "${LIB_RESOURCES_DIR}" ]; then
  cp -R "${LIB_RESOURCES_DIR}/." "${APP_BUNDLE}/Resources/"
fi

# Расширенные атрибуты с исходников превращаются в мусорные ._* файлы внутри pkg/zip.
xattr -cr "${APP_ROOT}" 2>/dev/null || true

ENTITLEMENTS="Sources/PieMenu/PieMenu.entitlements"
# Подпись: CODESIGN_IDENTITY из окружения → локальный dev-сертификат (scripts/create-dev-signing-identity.sh)
# → ad-hoc. Ad-hoc подпись меняется при каждой сборке, и macOS сбрасывает выданные доступы (TCC).
DEV_IDENTITY_NAME="${PIEMENU_DEV_IDENTITY_NAME:-PieMenu Dev Signing}"
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  SIGN_IDENTITY="${CODESIGN_IDENTITY}"
elif security find-identity -v -p codesigning 2>/dev/null | grep -q "\"${DEV_IDENTITY_NAME}\""; then
  SIGN_IDENTITY="${DEV_IDENTITY_NAME}"
else
  SIGN_IDENTITY="-"
fi
echo "Signing with: ${SIGN_IDENTITY}"

if [ -f "${ENTITLEMENTS}" ]; then
  codesign --force --options runtime --entitlements "${ENTITLEMENTS}" \
           --sign "${SIGN_IDENTITY}" "${APP_ROOT}"
else
  codesign --force --options runtime --sign "${SIGN_IDENTITY}" "${APP_ROOT}"
fi

echo ""
echo "Build complete: ${APP_ROOT}"
echo "Run with: open ${APP_ROOT}"
