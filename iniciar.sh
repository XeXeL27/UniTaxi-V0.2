#!/usr/bin/env bash
# Levanta TaxiUAP completo con un solo comando: base de datos, frontends compilados y backend.
# El backend sirve el panel en /admin y la app (pasajeros y conductores) en /app.
#
# Uso:
#   ./iniciar.sh              recompila un frontend solo si cambio su codigo
#   ./iniciar.sh --compilar   recompila los dos frontends siempre
#   SERVER_PORT=8081 ./iniciar.sh   usa otro puerto (por defecto 5557)
#
# Para programar con recarga en caliente se sigue pudiendo usar flutter run en cada proyecto.
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")" && pwd)"
FLUTTER="${FLUTTER:-$(command -v flutter || echo "$HOME/development/flutter/bin/flutter")}"
FORZAR=false
[[ "${1:-}" == "--compilar" ]] && FORZAR=true

# --- Requisitos -------------------------------------------------------------------------------
falta() { echo "ERROR: $1" >&2; exit 1; }
command -v docker >/dev/null || falta "no se encontro docker. Instala Docker con el plugin compose."
docker compose version >/dev/null 2>&1 || falta "falta 'docker compose' (plugin compose de Docker)."
command -v java >/dev/null || falta "no se encontro java. Instala Java 21 (por ejemplo openjdk-21-jdk)."
VERSION_JAVA="$(java -version 2>&1 | awk -F'"' '/version/ {split($2, v, "."); print v[1]; exit}')"
[[ "${VERSION_JAVA:-0}" -ge 21 ]] || falta "el backend necesita Java 21 o superior (hay Java ${VERSION_JAVA:-?})."

# --- .env: si no existe se crea con contrasenas aleatorias (maquina nueva) -------------------
# Texto aleatorio de letras y numeros: [1] bytes de /dev/urandom, recortado a [2] caracteres.
aleatorio() { local s; s="$(head -c "$1" /dev/urandom | base64 -w0 | tr -d '/+=')"; printf '%s' "${s:0:$2}"; }
ENV="$RAIZ/.env"
if [[ ! -f "$ENV" ]]; then
  echo "== Creando .env (no existia)"
  CLAVE_ADMIN="$(aleatorio 24 14)"
  # Los valores de ejemplo (<cambiar>) quedan vacios: esas integraciones se apagan solas.
  sed -e 's/<cambiar>//' "$RAIZ/.env.example" \
    | sed -e "s|^TAXIUAP_DB_PASSWORD=.*|TAXIUAP_DB_PASSWORD=$(aleatorio 24 24)|" \
          -e "s|^JWT_SECRET=.*|JWT_SECRET=$(aleatorio 96 86)|" \
          -e "s|^ADMIN_CORREO=.*|ADMIN_CORREO=admin@unitaxi.bo|" \
          -e "s|^ADMIN_PASSWORD=.*|ADMIN_PASSWORD=$CLAVE_ADMIN|" > "$ENV"
  chmod 600 "$ENV"
  echo "   Administrador inicial del panel: usuario admin, contrasena $CLAVE_ADMIN"
  echo "   (queda en .env como ADMIN_PASSWORD; completa ahi Google, Gemini, SIGSE y el correo)"
fi
# Sin JWT_SECRET el backend no arranca: se agrega uno si falta.
if ! grep -qE '^JWT_SECRET=.+' "$ENV"; then
  sed -i '/^JWT_SECRET=/d' "$ENV"
  echo "JWT_SECRET=$(aleatorio 96 86)" >> "$ENV"
  echo "== Se agrego un JWT_SECRET nuevo al .env"
fi

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
    if [[ ! -x "$FLUTTER" ]] && ! command -v "$FLUTTER" >/dev/null; then
      [[ -f "$indice" ]] || falta "hay que compilar $proyecto y no se encontro Flutter. Instala Flutter 3.x o define FLUTTER=/ruta/a/flutter."
      echo "== $proyecto: sin Flutter para recompilar, se usa la compilacion anterior"
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

# El puerto va por variable de entorno: le gana a server.port de cualquier perfil.
export SERVER_PORT="${SERVER_PORT:-5557}"
PUERTO="$SERVER_PORT"
IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
echo
echo "   Panel admin:  http://localhost:$PUERTO/admin"
echo "   App:          http://localhost:$PUERTO/app"
[[ -n "$IP" ]] && echo "   Desde otro equipo de la red: http://$IP:$PUERTO/app"
echo "   Produccion:   http://virtual.uap.edu.bo:$PUERTO/app  y  /admin"
echo

echo "== Backend"
cd "$RAIZ/backend"
exec ./gradlew bootRun
