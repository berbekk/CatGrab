#!/bin/bash
# Собирает build/CatGrab.app из Swift-пакета: бинарник, Info.plist, иконка, ресурсы, подпись.
#
# Переменные окружения:
#   CATGRAB_ARCHS         архитектуры через пробел; по умолчанию — только своя (быстро для разработки),
#                         для релиза — "arm64 x86_64" (универсальный бинарник, работает и на Intel)
#   CATGRAB_VERSION       версия в бандле (по умолчанию из Info.plist); ведущая "v" отбрасывается
#   CATGRAB_BUILD_NUMBER  CFBundleVersion (по умолчанию 1)
#   CATGRAB_BUILD_DIR     куда класть .app (по умолчанию build)
#   CODESIGN_IDENTITY     чем подписать; иначе — локальный dev-сертификат, иначе — ad-hoc
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "CatGrab builds on macOS 13+ only."
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift not found. Install the Xcode Command Line Tools:"
  echo "  xcode-select --install"
  exit 1
fi

# Стекло Liquid Glass — API macOS 26: без его SDK компилятор выдаст стену непонятных ошибок.
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version 2>/dev/null || echo 0)"
if [ "${SDK_VERSION%%.*}" -lt 26 ]; then
  echo "CatGrab needs the macOS 26 SDK to build (found ${SDK_VERSION})."
  echo "Install Xcode 26 or newer, or its Command Line Tools. The built app runs on macOS 13+."
  exit 1
fi

APP_NAME="CatGrab"
BUILD_DIR="${CATGRAB_BUILD_DIR:-build}"
if [ -e "${BUILD_DIR}/${APP_NAME}.app" ] && [ ! -w "${BUILD_DIR}/${APP_NAME}.app" ]; then
  BUILD_DIR="${TMPDIR:-/tmp}"
  BUILD_DIR="${BUILD_DIR%/}/catgrab-build"
  echo "build/${APP_NAME}.app is not writable (left by an installer). Building into ${BUILD_DIR} instead."
fi
mkdir -p "${BUILD_DIR}"
APP_ROOT="${BUILD_DIR}/${APP_NAME}.app"
APP_BUNDLE="${APP_ROOT}/Contents"
APP_VERSION="${CATGRAB_VERSION:-}"
if [ -z "${APP_VERSION}" ]; then
  APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "Sources/${APP_NAME}/Info.plist")"
fi
APP_VERSION="${APP_VERSION#v}"
BUILD_VERSION="${CATGRAB_BUILD_NUMBER:-1}"

ARCH_FLAGS=()
for arch in ${CATGRAB_ARCHS:-}; do
  ARCH_FLAGS+=(--arch "${arch}")
done

echo "Building ${APP_NAME} ${APP_VERSION} (${CATGRAB_ARCHS:-native arch})..."
swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"
BIN_PATH="${BIN_DIR}/${APP_NAME}"

if [ ! -f "${BIN_PATH}" ]; then
  echo "Error: compiled binary not found at ${BIN_PATH}"
  exit 1
fi

echo "Creating app bundle..."
"${ROOT_DIR}/scripts/generate-app-icon.sh"

# Предыдущая установка от root могла оставить копию, которую нельзя перезаписать.
chmod -R u+w "${APP_ROOT}" 2>/dev/null || true
rm -rf "${APP_ROOT}"
if [ -e "${APP_ROOT}" ]; then
  echo "Cannot overwrite ${APP_ROOT} — usually a copy left by an install running as root."
  echo "Run: sudo rm -rf \"${APP_ROOT}\""
  exit 1
fi
# Dev-сборка не должна попадать в Spotlight и LaunchServices — иначе рядом с /Applications/CatGrab.app
# появляется дубликат, и Spotlight/«Открыть с помощью» путаются.
touch "${BUILD_DIR}/.metadata_never_index"
mkdir -p "${APP_BUNDLE}/MacOS" "${APP_BUNDLE}/Resources"

cp "${BIN_PATH}" "${APP_BUNDLE}/MacOS/${APP_NAME}"
cp "Sources/${APP_NAME}/Info.plist" "${APP_BUNDLE}/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${APP_VERSION}" "${APP_BUNDLE}/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_VERSION}" "${APP_BUNDLE}/Info.plist"
printf 'APPL????' > "${APP_BUNDLE}/PkgInfo"
cp "Sources/${APP_NAME}/Resources/AppIcon.icns" "${APP_BUNDLE}/Resources/AppIcon.icns"
cp "Sources/${APP_NAME}/PrivacyInfo.xcprivacy" "${APP_BUNDLE}/Resources/PrivacyInfo.xcprivacy"
cp -R "Sources/${APP_NAME}Lib/Resources/." "${APP_BUNDLE}/Resources/"

# Расширенные атрибуты с исходников превращаются в мусорные ._* файлы внутри архивов.
xattr -cr "${APP_ROOT}" 2>/dev/null || true

ENTITLEMENTS="Sources/${APP_NAME}/${APP_NAME}.entitlements"
# Подпись: CODESIGN_IDENTITY из окружения → локальный dev-сертификат (scripts/create-dev-signing-identity.sh)
# → ad-hoc. Ad-hoc подпись меняется при каждой сборке, и macOS сбрасывает выданные доступы (TCC).
DEV_IDENTITY_NAME="${CATGRAB_DEV_IDENTITY_NAME:-CatGrab Dev Signing}"
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  SIGN_IDENTITY="${CODESIGN_IDENTITY}"
elif security find-identity -v -p codesigning 2>/dev/null | grep -q "\"${DEV_IDENTITY_NAME}\""; then
  SIGN_IDENTITY="${DEV_IDENTITY_NAME}"
else
  SIGN_IDENTITY="-"
fi
echo "Signing with: ${SIGN_IDENTITY}"
codesign --force --options runtime --entitlements "${ENTITLEMENTS}" --sign "${SIGN_IDENTITY}" "${APP_ROOT}"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "${LSREGISTER}" ]; then
  "${LSREGISTER}" -u "${APP_ROOT}" >/dev/null 2>&1 || true
fi

echo ""
echo "Build complete: ${APP_ROOT}"
echo "Run with: open ${APP_ROOT}"
