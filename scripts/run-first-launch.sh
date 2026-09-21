#!/usr/bin/env bash
# Запускает собранный CatGrab так, будто это первый запуск: снова показывает окно выдачи доступов.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${ROOT}/build/CatGrab.app"

if [[ ! -d "${APP}" ]]; then
  "${ROOT}/build.sh"
fi
defaults delete io.github.berbekk.CatGrab pie.hasSeenPermissionIntro 2>/dev/null || true
CATGRAB_FIRST_LAUNCH=1 exec "${APP}/Contents/MacOS/CatGrab"
