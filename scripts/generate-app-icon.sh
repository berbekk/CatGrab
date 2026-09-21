#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC="${ROOT_DIR}/Sources/CatGrab/Resources/AppIcon.png"
ICONSET="${ROOT_DIR}/Sources/CatGrab/Resources/AppIcon.iconset"
OUT_ICNS="${ROOT_DIR}/Sources/CatGrab/Resources/AppIcon.icns"

if [ ! -f "${SRC}" ]; then
  echo "Error: missing ${SRC}"
  exit 1
fi

# Иконсет — промежуточный артефакт: пересоздаём с нуля и убираем за собой.
rm -rf "${ICONSET}"
mkdir -p "${ICONSET}"
trap 'rm -rf "${ICONSET}"' EXIT

cat > "${ICONSET}/Contents.json" <<'EOF'
{
  "images" : [
    { "idiom" : "mac", "scale" : "1x", "size" : "16x16", "filename" : "icon_16x16.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "16x16", "filename" : "icon_16x16@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "32x32", "filename" : "icon_32x32.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "32x32", "filename" : "icon_32x32@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "128x128", "filename" : "icon_128x128.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "128x128", "filename" : "icon_128x128@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "256x256", "filename" : "icon_256x256.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "256x256", "filename" : "icon_256x256@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "512x512", "filename" : "icon_512x512.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "512x512", "filename" : "icon_512x512@2x.png" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF

sips -z 16 16 "${SRC}" --out "${ICONSET}/icon_16x16.png" >/dev/null
sips -z 32 32 "${SRC}" --out "${ICONSET}/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "${SRC}" --out "${ICONSET}/icon_32x32.png" >/dev/null
sips -z 64 64 "${SRC}" --out "${ICONSET}/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "${SRC}" --out "${ICONSET}/icon_128x128.png" >/dev/null
sips -z 256 256 "${SRC}" --out "${ICONSET}/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "${SRC}" --out "${ICONSET}/icon_256x256.png" >/dev/null
sips -z 512 512 "${SRC}" --out "${ICONSET}/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "${SRC}" --out "${ICONSET}/icon_512x512.png" >/dev/null
sips -z 1024 1024 "${SRC}" --out "${ICONSET}/icon_512x512@2x.png" >/dev/null

rm -f "${OUT_ICNS}"
iconutil -c icns "${ICONSET}" -o "${OUT_ICNS}"

echo "App icon generated: ${OUT_ICNS}"
