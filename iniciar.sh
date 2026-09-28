#!/usr/bin/env bash
# Levanta TaxiUAP completo con un solo comando: base de datos, frontends compilados y backend.
# El backend sirve el panel en /admin y la app (pasajeros y conductores) en /app.
#
# Uso:
#   ./iniciar.sh              recompila un frontend solo si cambio su codigo
#   ./iniciar.sh --compilar   recompila los dos frontends siempre
#   SERVER_PORT=8081 ./iniciar.sh   usa otro puerto
#
# Para programar con recarga en caliente se sigue pudiendo usar flutter run en cada proyecto.
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")" && pwd)"
FLUTTER="${FLUTTER:-$(command -v flutter || echo "$HOME/development/flutter/bin/flutter")}"
FORZAR=false
[[ "${1:-}" == "--compilar" ]] && FORZAR=true

echo "== Base de datos (PostGIS en Docker)"
(cd "$RAIZ" && docker compose up -d --wait)

# Compila un proyecto Flutter web con la ruta base con que lo sirve el backend.
compilar() {
  local proyecto="$1" base="$2"
  local indice="$RAIZ/$proyecto/build/web/index.html"
  local cambios=""
  if [[ -f "$indice" ]]; then
    cambios="$(cd "$RAIZ/$proyecto" && find lib web assets pubspec.yaml -newer "$indice" -print -quit 2>/dev/null || true)"
  fi
  if $FORZAR || [[ ! -f "$indice" || -n "$cambios" ]]; then
    echo "== Compilando $proyecto (/$base)"
    (cd "$RAIZ/$proyecto" && "$FLUTTER" build web --release --no-tree-shake-icons --no-web-resources-cdn \
      --base-href "/$base/")
  else
    echo "== $proyecto sin cambios: se usa la compilacion anterior"
  fi
}

compilar admin-panel admin
compilar app-movil app

PUERTO="${SERVER_PORT:-8080}"
IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
echo
echo "   Panel admin:  http://localhost:$PUERTO/admin"
echo "   App:          http://localhost:$PUERTO/app"
[[ -n "$IP" ]] && echo "   Desde otro equipo de la red: http://$IP:$PUERTO/app"
echo

echo "== Backend"
cd "$RAIZ/backend"
exec ./gradlew bootRun
