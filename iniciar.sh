#!/usr/bin/env bash
# Levanta TaxiUAP: frontends compilados y backend.
# El backend sirve el panel en /admin y la app (pasajeros y conductores) en /app.
#
# Base de datos externa (configuracion del servidor, nick460 4095150): este script no levanta ni toca
# ninguna base de datos ni el .env. La conexion, el puerto y las claves salen de la configuracion de
# la maquina (application-<perfil>.properties y .env), que git pull no modifica.
#
# Uso:
#   ./iniciar.sh              recompila un frontend solo si cambio su codigo
#   ./iniciar.sh --compilar   recompila los dos frontends siempre
#   ./iniciar.sh --con-bd     ademas levanta la BD de desarrollo (PostGIS en Docker, puerto 5436)
#   SERVER_PORT=8081 ./iniciar.sh   usa otro puerto
#
# Para programar con recarga en caliente se sigue pudiendo usar flutter run en cada proyecto.
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")" && pwd)"
FLUTTER="${FLUTTER:-$(command -v flutter || echo "$HOME/development/flutter/bin/flutter")}"
FORZAR=false
CON_BD=false
for ARG in "$@"; do
  case "$ARG" in
    --compilar) FORZAR=true ;;
    --con-bd) CON_BD=true ;;
  esac
done

falta() { echo "ERROR: $1" >&2; exit 1; }

if $CON_BD; then
  echo "== Base de datos de desarrollo (PostGIS en Docker)"
  (cd "$RAIZ" && docker compose up -d --wait)
fi

# Compila un proyecto Flutter web con la ruta base con que lo sirve el backend.
compilar() {
  local proyecto="$1" base="$2"
  local indice="$RAIZ/$proyecto/build/web/index.html"
  local cambios=""
  if [[ -f "$indice" ]]; then
    cambios="$(cd "$RAIZ/$proyecto" && find lib web assets pubspec.yaml -newer "$indice" -print -quit 2>/dev/null || true)"
  fi
  if $FORZAR || [[ ! -f "$indice" || -n "$cambios" ]]; then
    if [[ ! -x "$FLUTTER" ]] && ! command -v "$FLUTTER" >/dev/null; then
      # Sin Flutter: el backend sirve la copia compilada que va en el repositorio (resources/web).
      [[ -f "$indice" || -f "$RAIZ/backend/src/main/resources/web/$base/index.html" ]] \
        || falta "hay que compilar $proyecto y no se encontro Flutter. Instala Flutter 3.x o define FLUTTER=/ruta/a/flutter."
      echo "== $proyecto: sin Flutter, se usa la version compilada del repositorio"
      return
    fi
    echo "== Compilando $proyecto (/$base)"
    (cd "$RAIZ/$proyecto" && "$FLUTTER" build web --release --no-tree-shake-icons --no-web-resources-cdn \
      --base-href "/$base/")
  else
    echo "== $proyecto sin cambios: se usa la compilacion anterior"
  fi
}

compilar admin-panel admin
compilar app-movil app

# Solo para mostrarlo: el puerto real es el de la configuracion (SERVER_PORT si se paso, si no el
# server.port del perfil, si no el de application.properties).
PERFIL="${SPRING_PROFILES_ACTIVE:-xexel}"
PUERTO="${SERVER_PORT:-$(grep -hE '^server\.port=' "$RAIZ/backend/src/main/resources/application-$PERFIL.properties" 2>/dev/null \
  | tail -1 | sed -E 's/^server\.port=//; s/^\$\{[A-Z_]+:([0-9]+)\}$/\1/' || true)}"
PUERTO="${PUERTO:-5557}"
IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
echo
echo "   Panel admin:  http://localhost:$PUERTO/admin"
echo "   App:          http://localhost:$PUERTO/app"
[[ -n "$IP" ]] && echo "   Desde otro equipo de la red: http://$IP:$PUERTO/app"

# Hora de Bolivia aunque la maquina este en UTC (el backend tambien la fija al arrancar).
export TZ=America/La_Paz
# Logs en archivo (ademas de la consola): logs/taxiuap.log y logs/taxiuap-errores.log en la raiz.
export LOG_DIR="${LOG_DIR:-$RAIZ/logs}"
echo "   Logs:         $LOG_DIR/taxiuap.log  (solo errores: $LOG_DIR/taxiuap-errores.log)"
echo

echo "== Backend"
cd "$RAIZ/backend"
exec ./gradlew bootRun
