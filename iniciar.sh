#!/usr/bin/env bash
# Levanta TaxiUAP completo con un solo comando: base de datos, frontends compilados y backend.
# El backend sirve el panel en /admin y la app (pasajeros y conductores) en /app.
#
# En el servidor basta con: git pull && ./iniciar.sh
#   - El .env se crea solo la primera vez (contrasenas aleatorias) y git pull nunca lo toca.
#   - Base de datos: PostGIS en Docker (puerto 5436), salvo BD externa: DB_URL hacia otro servidor o
#     BD_EXTERNA=1 en el .env, o un PostgreSQL de la maquina que ya escucha en el 5436.
#   - Backend: con Java 21 en la maquina corre ahi; sin Java corre en un contenedor Docker con Java 21
#     (mismas rutas, mismo puerto, mismo .env). BACKEND_EN_DOCKER=1 lo fuerza.
#   - Sin Flutter se sirven el panel y la app ya compilados que vienen en el repositorio.
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
HAY_DOCKER=false
command -v docker >/dev/null && docker compose version >/dev/null 2>&1 && HAY_DOCKER=true
VERSION_JAVA=0
command -v java >/dev/null && VERSION_JAVA="$(java -version 2>&1 | awk -F'"' '/version/ {split($2, v, "."); print v[1]; exit}')"
BACKEND_EN_DOCKER="${BACKEND_EN_DOCKER:-}"
if [[ -z "$BACKEND_EN_DOCKER" ]]; then
  [[ "${VERSION_JAVA:-0}" -ge 21 ]] && BACKEND_EN_DOCKER=0 || BACKEND_EN_DOCKER=1
fi
if [[ "$BACKEND_EN_DOCKER" == 1 ]] && ! $HAY_DOCKER; then
  falta "no hay Java 21 ni Docker. Instala Docker con el plugin compose (o Java 21, por ejemplo openjdk-21-jdk)."
fi

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
# Integraciones sin configurar: quedan apagadas hasta completar el .env y volver a iniciar.
for VAR in SIGSE_URL SIGSE_API_KEY GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET GEMINI_API_KEY; do
  grep -qE "^$VAR=.+" "$ENV" || echo "   AVISO: falta $VAR en .env (esa funcion no andara en este servidor)"
done
# Hora de Bolivia aunque la maquina este en UTC (el backend tambien la fija al arrancar).
export TZ=America/La_Paz

# DB_URL en el .env (o en el entorno) hacia otro servidor = BD externa: no se levanta la de Docker.
DB_URL_ENV="${DB_URL:-$(grep -E '^DB_URL=' "$ENV" | tail -1 | cut -d= -f2- | tr -d '"' || true)}"
BD_EXTERNA="${BD_EXTERNA:-$(grep -E '^BD_EXTERNA=' "$ENV" | tail -1 | cut -d= -f2- | tr -d '"' || true)}"
CONTENEDOR_BD=false
$HAY_DOCKER && docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx taxiuap-db && CONTENEDOR_BD=true
if [[ "$BD_EXTERNA" == 1 ]] \
    || [[ -n "$DB_URL_ENV" && "$DB_URL_ENV" != *"localhost:5436"* && "$DB_URL_ENV" != *"127.0.0.1:5436"* ]]; then
  echo "== Base de datos externa (DB_URL / BD_EXTERNA del .env): no se levanta la de Docker"
elif ! $CONTENEDOR_BD && (exec 3<>/dev/tcp/127.0.0.1/5436) 2>/dev/null; then
  # Ya hay un PostgreSQL propio en el 5436 (instalado en la maquina): se usa ese, sin contenedor.
  echo "== Base de datos ya activa en el puerto 5436 (fuera de Docker): se usa esa"
else
  $HAY_DOCKER || falta "no se encontro Docker para la base de datos. Instala Docker o pon DB_URL de una BD externa en .env."
  echo "== Base de datos (PostGIS en Docker)"
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
      # Sin Flutter (servidor de produccion): el backend sirve la copia compilada que va en el repositorio.
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

# El puerto va por variable de entorno: le gana a server.port de cualquier perfil.
export SERVER_PORT="${SERVER_PORT:-5557}"
PUERTO="$SERVER_PORT"
IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
echo
echo "   Panel admin:  http://localhost:$PUERTO/admin"
echo "   App:          http://localhost:$PUERTO/app"
[[ -n "$IP" ]] && echo "   Desde otro equipo de la red: http://$IP:$PUERTO/app"
echo "   Produccion:   https://uni-taxi.uap.edu.bo/app  y  /admin (proxy con certificado hacia el $PUERTO)"
echo

# Logs en archivo (ademas de la consola): logs/taxiuap.log y logs/taxiuap-errores.log en la raiz.
export LOG_DIR="${LOG_DIR:-$RAIZ/logs}"
echo "   Logs:         $LOG_DIR/taxiuap.log  (solo errores: $LOG_DIR/taxiuap-errores.log)"
echo

cd "$RAIZ/backend"
if [[ "$BACKEND_EN_DOCKER" != 1 ]]; then
  echo "== Backend (Java ${VERSION_JAVA} de esta maquina)"
  exec ./gradlew bootRun
fi

# Sin Java 21: el mismo ./gradlew bootRun dentro de un contenedor con Java 21. Red del anfitrion (la BD en
# localhost:5436 y el puerto quedan igual) y las mismas rutas y usuario: los archivos subidos
# (~/Documentos Unitaxi), los logs, el cache de Gradle (~/.gradle) y el .env son los de esta maquina.
echo "== Backend (Docker con Java 21: esta maquina no tiene Java 21)"
MONTAJES=(-v "$HOME:$HOME")
[[ "$RAIZ" == "$HOME"/* ]] || MONTAJES+=(-v "$RAIZ:$RAIZ")
[[ "$LOG_DIR" == "$HOME"/* || "$LOG_DIR" == "$RAIZ"/* ]] || { mkdir -p "$LOG_DIR"; MONTAJES+=(-v "$LOG_DIR:$LOG_DIR"); }
docker rm -f taxiuap-backend >/dev/null 2>&1 || true
exec docker run --rm --name taxiuap-backend --network host \
  -u "$(id -u):$(id -g)" "${MONTAJES[@]}" -w "$RAIZ/backend" \
  -e HOME="$HOME" -e GRADLE_USER_HOME="$HOME/.gradle" -e JAVA_TOOL_OPTIONS="-Duser.home=$HOME" \
  -e TZ -e SERVER_PORT -e LOG_DIR -e SPRING_PROFILES_ACTIVE -e LOG_SQL -e LOG_NIVEL \
  eclipse-temurin:21-jdk ./gradlew bootRun
