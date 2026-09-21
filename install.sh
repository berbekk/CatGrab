#!/bin/bash
# Для разработчиков: собрать и положить CatGrab.app в /Applications.
# Обычным пользователям — CatGrab.dmg со страницы Releases.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

APP_NAME="CatGrab"
BUILD_APP_PATH="build/${APP_NAME}.app"
DEST_APP_PATH="/Applications/${APP_NAME}.app"

if [ -e "${BUILD_APP_PATH}" ] && [ ! -w "${BUILD_APP_PATH}" ]; then
  CATGRAB_BUILD_DIR="${TMPDIR:-/tmp}"
  export CATGRAB_BUILD_DIR="${CATGRAB_BUILD_DIR%/}/catgrab-build"
  BUILD_APP_PATH="${CATGRAB_BUILD_DIR}/${APP_NAME}.app"
fi

"${ROOT_DIR}/build.sh"

# Пока старая копия запущена, macOS продолжит показывать её.
if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
  osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
  sleep 1
fi
if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
  pkill -x "${APP_NAME}" || true
  sleep 1
fi

if [ -e "${DEST_APP_PATH}" ] && [ ! -w "${DEST_APP_PATH}" ]; then
  echo "Cannot replace ${DEST_APP_PATH}: permission denied."
  echo "Launching the freshly built copy instead. To put it in Applications, run:"
  echo "  sudo rm -rf \"${DEST_APP_PATH}\" && cp -R \"${BUILD_APP_PATH}\" /Applications/"
  open "${BUILD_APP_PATH}"
  exit 0
fi
rm -rf "${DEST_APP_PATH}"
ditto --norsrc --noextattr "${BUILD_APP_PATH}" "${DEST_APP_PATH}"
xattr -cr "${DEST_APP_PATH}" >/dev/null 2>&1 || true

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "${LSREGISTER}" ]; then
  "${LSREGISTER}" -f "${DEST_APP_PATH}" >/dev/null 2>&1 || true
fi

echo ""
echo "Installed: ${DEST_APP_PATH}"
open "${DEST_APP_PATH}"
