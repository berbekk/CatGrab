#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
export PIE_FIRST_LAUNCH=1

if [[ -d "$ROOT/build/PieMenu.app" ]]; then
  defaults delete com.piemenu.app pie.hasSeenPermissionIntro 2>/dev/null || true
  exec "$ROOT/build/PieMenu.app/Contents/MacOS/PieMenu"
else
  cd "$ROOT"
  exec swift run PieMenu
fi
