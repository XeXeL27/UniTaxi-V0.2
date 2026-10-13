#!/usr/bin/env bash
# UNITAXI como servicio de Docker: el backend (API, /admin y /app) corre en el contenedor unitaxi-backend,
# arranca solo al prender la maquina y se reinicia si se cae. No compila Flutter (el panel y la app ya van
# compilados en el repositorio): solo Java, dentro de Docker.
#
# Uso (desde cualquier carpeta; con o sin sudo):
#   ./despliegue/servicio.sh iniciar      construye la imagen (la primera vez) y levanta el servicio
#   ./despliegue/servicio.sh actualizar   git pull + reconstruir + reiniciar (guarda antes los cambios locales)
#   ./despliegue/servicio.sh reiniciar    reinicia el contenedor (por ejemplo, despues de cambiar el .env)
#   ./despliegue/servicio.sh detener      detiene el backend (la BD sigue)
#   ./despliegue/servicio.sh estado       muestra los contenedores y si responde el puerto
#   ./despliegue/servicio.sh logs         sigue el log del backend (Ctrl+C para salir)
# Opciones: --con-bd levanta tambien la BD de docker-compose (taxiuap-db, puerto 5436). Si el contenedor
# taxiuap-db ya existe se levanta siempre. UNITAXI_PUERTO=8081 usa otro puerto (por defecto el del .env o 5557).
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
ACCION="${1:-estado}"
CON_BD=false
for ARG in "$@"; do [[ "$ARG" == "--con-bd" ]] && CON_BD=true; done

falta() { echo "ERROR: $1" >&2; exit 1; }
command -v docker >/dev/null || falta "no se encontro Docker."
docker compose version >/dev/null 2>&1 || falta "falta el plugin 'docker compose'."

# El contenedor corre con el usuario duenio del repositorio (no con root, aunque se use sudo): asi los
# archivos subidos y los logs quedan suyos y ve su carpeta personal en la misma ruta.
DUENIO="$(stat -c %U "$RAIZ")"
export UNITAXI_RAIZ="$RAIZ"
export UNITAXI_UID="$(stat -c %u "$RAIZ")"
export UNITAXI_GID="$(stat -c %g "$RAIZ")"
export UNITAXI_HOME="$(getent passwd "$DUENIO" | cut -d: -f6)"
export UNITAXI_LOGS="${UNITAXI_LOGS:-$RAIZ/logs}"
export UNITAXI_PUERTO="${UNITAXI_PUERTO:-}"
[[ -n "$UNITAXI_HOME" ]] || falta "no se encontro la carpeta personal de $DUENIO."
mkdir -p "$UNITAXI_LOGS"
[[ "$(id -u)" == "0" ]] && chown "$UNITAXI_UID:$UNITAXI_GID" "$UNITAXI_LOGS"

# Puerto que se usara (solo para avisar y revisar): UNITAXI_PUERTO, si no SERVER_PORT del .env, si no 5557.
PUERTO="$UNITAXI_PUERTO"
if [[ -z "$PUERTO" && -f "$RAIZ/.env" ]]; then
  PUERTO="$(grep -E '^[[:space:]]*SERVER_PORT[[:space:]]*=' "$RAIZ/.env" | tail -1 | cut -d= -f2- | tr -d ' "'"'" || true)"
fi
PUERTO="${PUERTO:-5557}"

compose() { (cd "$RAIZ" && docker compose --profile servidor "$@"); }

# La BD que ya corre en la maquina (contenedor taxiuap-db de docker compose) no se toca: ni se recrea ni se
# reinicia. Si existe pero esta detenida solo se arranca; si no existe se crea unicamente con --con-bd.
levantar_bd() {
  if docker ps --format '{{.Names}}' | grep -qx taxiuap-db; then
    echo "== Base de datos: taxiuap-db ya esta corriendo (no se toca)"
  elif docker ps -a --format '{{.Names}}' | grep -qx taxiuap-db; then
    echo "== Base de datos: se arranca el contenedor taxiuap-db que estaba detenido"
    docker start taxiuap-db >/dev/null
  elif $CON_BD; then
    echo "== Base de datos: se crea taxiuap-db (docker compose)"
    compose up -d --wait taxiuap-db
  fi
}

# Otro proceso (por ejemplo ./iniciar.sh) ocupando el puerto impide arrancar el contenedor.
revisar_puerto() {
  if docker ps --format '{{.Names}}' | grep -qx unitaxi-backend; then return; fi
  if ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]$PUERTO\$"; then
    falta "el puerto $PUERTO ya esta en uso (¿sigue corriendo ./iniciar.sh?). Detenlo y vuelve a intentar:
       ss -ltnp | grep $PUERTO"
  fi
}

esperar() {
  echo "== Esperando que el backend responda en el puerto $PUERTO (la primera vez tarda un poco)"
  for _ in $(seq 1 90); do
    if curl -fsS -o /dev/null "http://127.0.0.1:$PUERTO/app/" 2>/dev/null; then
      echo "   Listo: http://localhost:$PUERTO/app  y  http://localhost:$PUERTO/admin"
      return
    fi
    if ! docker ps --format '{{.Names}}' | grep -qx unitaxi-backend; then break; fi
    sleep 2
  done
  echo "AVISO: todavia no responde. Revisa: ./despliegue/servicio.sh logs  o  $UNITAXI_LOGS/taxiuap-errores.log" >&2
}

case "$ACCION" in
  iniciar)
    levantar_bd
    revisar_puerto
    echo "== Construyendo la imagen del backend (solo Java)"
    compose build unitaxi
    compose up -d unitaxi
    esperar
    ;;
  actualizar)
    cd "$RAIZ"
    if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
      echo "== Hay cambios locales en archivos del repositorio: se guardan con git stash"
      git status --short --untracked-files=no
      git stash push -m "servicio.sh $(date '+%F %T')"
      echo "   (para verlos: git stash list / git stash show -p)"
    fi
    git pull --ff-only
    levantar_bd
    echo "== Construyendo la imagen del backend (solo Java)"
    compose build unitaxi
    compose up -d unitaxi
    esperar
    ;;
  reiniciar)
    compose restart unitaxi
    esperar
    ;;
  detener)
    compose stop unitaxi
    ;;
  estado)
    docker ps -a --filter name=unitaxi-backend --filter name=taxiuap-db \
      --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
    if curl -fsS -o /dev/null "http://127.0.0.1:$PUERTO/app/" 2>/dev/null; then
      echo "El puerto $PUERTO responde."
    else
      echo "El puerto $PUERTO NO responde."
    fi
    ;;
  logs)
    compose logs -f --tail 200 unitaxi
    ;;
  *)
    falta "accion desconocida: $ACCION (iniciar, actualizar, reiniciar, detener, estado, logs)"
    ;;
esac
