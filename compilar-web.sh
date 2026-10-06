#!/usr/bin/env bash
# Compila el panel (/admin) y la app (/app) en modo release y deja la copia que va en el repositorio
# dentro del backend (backend/src/main/resources/web). Asi el servidor de produccion los sirve sin
# tener Flutter: solo git pull y arrancar el backend. Correrlo antes de subir cambios del panel o la app.
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")" && pwd)"
FLUTTER="${FLUTTER:-$(command -v flutter || echo "$HOME/development/flutter/bin/flutter")}"
DESTINO="$RAIZ/backend/src/main/resources/web"

# La compilacion es dart2js con el renderer canvaskit (ver buildConfig en flutter_bootstrap.js): nunca
# carga skwasm ni wimp (solo compilaciones --wasm), webparagraph (solo con preferWebParagraph) ni los
# .symbols (depuracion). Se quitan de la copia del repositorio para que pese la mitad.
quitar_no_usados() {
  local carpeta="$1/canvaskit"
  rm -rf "$carpeta/webparagraph" "$carpeta"/skwasm* "$carpeta"/wimp*
  find "$1" -name '*.symbols' -delete
}

compilar() {
  local proyecto="$1" base="$2"
  echo "== Compilando $proyecto (/$base)"
  (cd "$RAIZ/$proyecto" && "$FLUTTER" build web --release --no-tree-shake-icons --no-web-resources-cdn \
    --base-href "/$base/")
  rm -rf "${DESTINO:?}/$base"
  mkdir -p "$DESTINO/$base"
  cp -r "$RAIZ/$proyecto/build/web/." "$DESTINO/$base/"
  quitar_no_usados "$DESTINO/$base"
  echo "   copiado a backend/src/main/resources/web/$base ($(du -sh "$DESTINO/$base" | cut -f1))"
}

compilar admin-panel admin
compilar app-movil app
