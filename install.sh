#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

APP_NAME="PieMenu"
BUILD_APP_PATH="build/${APP_NAME}.app"
DEST_APP_PATH="/Applications/${APP_NAME}.app"

"${ROOT_DIR}/build.sh"

# If app is already running, macOS may keep using old process.
if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
  osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
  sleep 1
fi

if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
  pkill -x "${APP_NAME}" || true
  sleep 1
fi

rm -rf "${DEST_APP_PATH}"
cp -R "${BUILD_APP_PATH}" "/Applications/"
xattr -cr "${DEST_APP_PATH}" >/dev/null 2>&1 || true

echo ""
echo "Developer install complete: ${DEST_APP_PATH}"
echo "For end users, distribute build/PieMenu.dmg from GitHub Releases instead."
echo "Run with: open \"${DEST_APP_PATH}\""
