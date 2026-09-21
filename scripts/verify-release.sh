#!/bin/bash
# Проверяет готовый build/CatGrab.dmg так, как его увидит пользователь: структуру образа, версию,
# подпись и то, что бинарник запустится и на Apple silicon, и на Intel.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${CATGRAB_BUILD_DIR:-${ROOT_DIR}/build}"
DMG_PATH="${1:-${BUILD_DIR}/CatGrab.dmg}"
APP_NAME="CatGrab"
# NOTARIZE=1 включает проверку тикета нотаризации и Gatekeeper.
NOTARIZE="${NOTARIZE:-0}"
MOUNT_DEVICE=""

cleanup() {
  if [ -n "${MOUNT_DEVICE}" ]; then
    hdiutil detach "${MOUNT_DEVICE}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

test -f "${DMG_PATH}"
hdiutil verify "${DMG_PATH}" >/dev/null

ATTACH_OUTPUT="$(hdiutil attach -readonly -nobrowse "${DMG_PATH}")"
MOUNT_DEVICE="$(printf '%s\n' "${ATTACH_OUTPUT}" | awk '/^\/dev\// { print $1; exit }')"
MOUNT_POINT="$(printf '%s\n' "${ATTACH_OUTPUT}" | awk -F '\t' '/\/Volumes\// { print $NF; exit }')"

test -n "${MOUNT_DEVICE}"
test -n "${MOUNT_POINT}"
test -d "${MOUNT_POINT}/${APP_NAME}.app"
test -L "${MOUNT_POINT}/Applications"
test "$(readlink "${MOUNT_POINT}/Applications")" = "/Applications"

APP="${MOUNT_POINT}/${APP_NAME}.app"
plutil -lint "${APP}/Contents/Info.plist" >/dev/null
test -f "${APP}/Contents/Resources/AppIcon.icns"
codesign --verify --deep --strict --verbose=2 "${APP}"

ARCHS="$(lipo -archs "${APP}/Contents/MacOS/${APP_NAME}")"
echo "Architectures: ${ARCHS}"
for arch in arm64 x86_64; do
  if [[ " ${ARCHS} " != *" ${arch} "* ]]; then
    echo "Missing ${arch}: the app would not launch on every Mac."
    exit 1
  fi
done

# Версия в бандле должна совпадать с тегом, иначе «О программе» врёт.
BUNDLE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP}/Contents/Info.plist")"
echo "Bundle version: ${BUNDLE_VERSION}"
if [ -n "${CATGRAB_VERSION:-}" ] && [ "${BUNDLE_VERSION}" != "${CATGRAB_VERSION#v}" ]; then
  echo "Version mismatch: bundle ${BUNDLE_VERSION}, expected ${CATGRAB_VERSION#v}"
  exit 1
fi

if [ "${NOTARIZE}" = "1" ]; then
  xcrun stapler validate "${DMG_PATH}"
  # Тот же путь, которым Gatekeeper проверяет приложение при первом запуске.
  spctl --assess --type execute --verbose=4 "${APP}"
fi

echo "Release DMG verified: ${DMG_PATH}"
