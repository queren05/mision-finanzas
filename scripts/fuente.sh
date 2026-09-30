#!/bin/sh
# Añade o actualiza una app en la fuente común de KSign (formato AltStore).
# Uso (en GitHub Actions, con GH_TOKEN): sh scripts/fuente.sh <id> <nombre> <bundleId> <versión> <build> <url .ipa> <tamaño> <url icono> <descripción>
# Cada app guarda su ficha como <id>.app.json en la release "fuente"; repo.json se regenera juntándolas todas.
# URL fija de la fuente: https://github.com/<usuario>/<repo>/releases/download/fuente/repo.json
set -e
ID=$1 NAME=$2 BUNDLE=$3 VER=$4 BUILD=$5 URL=$6 SIZE=$7 ICON=$8 DESC=$9
W=$(mktemp -d)
gh release view fuente >/dev/null 2>&1 || gh release create fuente --title "Fuente para KSign" --notes "Añade en KSign: https://github.com/$GITHUB_REPOSITORY/releases/download/fuente/repo.json"
gh release download fuente -p '*.app.json' -D "$W" 2>/dev/null || true
jq -n --arg n "$NAME" --arg b "$BUNDLE" --arg v "$VER" --arg bv "$BUILD" --arg u "$URL" --argjson s "$SIZE" --arg i "$ICON" --arg d "$DESC" \
  --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{name:$n, bundleIdentifier:$b, developerName:"David", subtitle:$d, localizedDescription:$d, iconURL:$i, tintColor:"e4b3cb", category:"utilities",
    versions:[{version:$v, buildVersion:$bv, date:$date, downloadURL:$u, size:$s, localizedDescription:("Versión " + $v), minOSVersion:"15.0"}]}' > "$W/$ID.app.json"
jq -s '{name:"Apps de David", identifier:"es.david.apps", subtitle:"Caudal, Bolita y más", iconURL:(.[0].iconURL), tintColor:"e4b3cb", apps:.}' "$W"/*.app.json > "$W/repo.json"
cat "$W/repo.json"
gh release upload fuente "$W/$ID.app.json" "$W/repo.json" --clobber
