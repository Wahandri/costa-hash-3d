#!/usr/bin/env bash
# Aplica la configuracion PWA al build web exportado:
#   - copia manifest + service worker
#   - genera iconos 192/512 (desde icon.svg o desde el apple-touch-icon)
#   - inyecta manifest/theme-color/apple-touch/SW + bloqueo horizontal en index.html
# Ejecutar DESPUES de cada export web.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
WEB="$(cd "$HERE/../build/web" && pwd)"
SRC="$HERE/pwa"

cp "$SRC/manifest.webmanifest" "$WEB/"
cp "$SRC/sw.js" "$WEB/"

mk_icon() {
  size="$1"; out="$2"
  if command -v convert >/dev/null 2>&1; then
    convert -background none "$SRC/icon.svg" -resize "${size}x${size}" "$out" 2>/dev/null && return 0
    convert "$WEB/index.apple-touch-icon.png" -resize "${size}x${size}" "$out" 2>/dev/null && return 0
  fi
  cp "$WEB/index.apple-touch-icon.png" "$out" 2>/dev/null || true
}
mk_icon 192 "$WEB/icon-192.png"
mk_icon 512 "$WEB/icon-512.png"

python3 - "$WEB/index.html" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
head = (
    '\t\t<link rel="manifest" href="manifest.webmanifest">\n'
    '\t\t<meta name="theme-color" content="#0e1020">\n'
    '\t\t<meta name="mobile-web-app-capable" content="yes">\n'
    '\t\t<meta name="apple-mobile-web-app-capable" content="yes">\n'
    '\t\t<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">\n'
    '\t\t<link rel="apple-touch-icon" href="icon-192.png">\n\t</head>'
)
if "manifest.webmanifest" not in s:
    s = s.replace("</head>", head, 1)
body = (
    '\t\t<script>\n'
    "\t\tif ('serviceWorker' in navigator) { navigator.serviceWorker.register('sw.js').catch(function(){}); }\n"
    "\t\twindow.addEventListener('load', function(){\n"
    "\t\t\ttry { if (screen.orientation && screen.orientation.lock) screen.orientation.lock('landscape').catch(function(){}); } catch(e){}\n"
    '\t\t});\n\t\t</script>\n\t</body>'
)
if "serviceWorker" not in s:
    s = s.replace("</body>", body, 1)
open(p, "w", encoding="utf-8").write(s)
print("PWA inyectada en index.html")
PY
echo "PWA aplicada en $WEB"
