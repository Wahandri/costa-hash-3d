#!/usr/bin/env bash
# Exporta el build web y REAPLICA la PWA (manifest + service worker + iconos).
# Usar SIEMPRE esto en lugar del export directo, para no perder la PWA.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
GODOT="${GODOT:-/opt/server/tools/godot/godot}"

"$GODOT" --headless --path "$PROJECT" --export-release "Web" "$PROJECT/build/web/index.html"
bash "$HERE/pwa_apply.sh"
echo "Export + PWA listos."
