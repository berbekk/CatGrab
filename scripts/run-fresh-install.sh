#!/usr/bin/env bash
# Запускает собранный CatGrab так, как его видит человек после установки: пустой конфиг
# (стандартное меню «Main» из шести приложений), знакомство с первой страницы.
# Свои меню не трогаются: конфиг берётся из временной папки, а не из Application Support.
# Права macOS (Универсальный доступ, Мониторинг ввода) сбросить отсюда нельзя — они на приложение.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${ROOT}/build/CatGrab.app"

if [[ ! -d "${APP}" ]]; then
  "${ROOT}/build.sh"
fi
FRESH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/catgrab-fresh.XXXXXX")"
echo "Fresh config in ${FRESH_DIR}"
pkill -x CatGrab 2>/dev/null || true
sleep 1
CATGRAB_CONFIG_DIR="${FRESH_DIR}" CATGRAB_FIRST_LAUNCH=1 exec "${APP}/Contents/MacOS/CatGrab"
