#!/bin/sh
# Junta los fuentes en dist/index.html y copia la web al proyecto de iPhone
set -e
cd "$(dirname "$0")"
JS=$(mktemp).js
cat src/core.js src/prices.js src/charts.js src/views.js src/import.js src/forms.js src/extra.js src/sync.js src/main.js > "$JS"
node --check "$JS"
{ cat src/head.html src/body.html; echo '<script>'; cat "$JS"; echo '</script>'; echo '</body></html>'; } > dist/index.html
rm "$JS"
mkdir -p ios-app/www
cp dist/index.html dist/manifest.webmanifest dist/icon-192.png dist/icon-512.png dist/apple-touch-icon.png ios-app/www/ 2>/dev/null || true
echo "OK: dist/index.html ($(wc -c < dist/index.html) bytes)"
