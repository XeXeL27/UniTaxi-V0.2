#!/usr/bin/env bash
# Arranque del backend dentro del contenedor. Lee el .env de la raiz del repositorio igual que bootRun:
# ignora comentarios y variables vacias (DB_URL= deja el valor por defecto) y quita las comillas de los
# valores ("ruta con espacios"). Lo que ya define docker-compose.yml (UNITAXI_PUERTO, carpetas) no se pisa.
set -euo pipefail

RAIZ="${RAIZ:?Falta RAIZ (carpeta del repositorio)}"

if [[ -f "$RAIZ/.env" ]]; then
  while IFS= read -r linea || [[ -n "$linea" ]]; do
    linea="${linea#"${linea%%[![:space:]]*}"}"
    [[ -z "$linea" || "$linea" == \#* || "$linea" != *=* ]] && continue
    nombre="${linea%%=*}"
    nombre="${nombre%"${nombre##*[![:space:]]}"}"
    valor="${linea#*=}"
    valor="${valor#"${valor%%[![:space:]]*}"}"
    valor="${valor%"${valor##*[![:space:]]}"}"
    if [[ ${#valor} -ge 2 && ( ( "$valor" == \"*\" ) || ( "$valor" == \'*\' ) ) ]]; then
      valor="${valor:1:${#valor}-2}"
    fi
    [[ -z "$valor" || ! "$nombre" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && continue
    [[ -n "${!nombre:-}" ]] && continue
    export "$nombre=$valor"
  done < "$RAIZ/.env"
fi

# Puerto elegido al levantar el servicio (si no, el del .env o el del perfil; por defecto 5557).
[[ -n "${UNITAXI_PUERTO:-}" ]] && export SERVER_PORT="$UNITAXI_PUERTO"

# Desde backend/, como bootRun: asi valen las mismas rutas relativas (../taxiuap-secretos, etc.).
cd "$RAIZ/backend"
exec java -Duser.timezone=America/La_Paz ${JAVA_OPCIONES:-} -jar /opt/unitaxi/unitaxi.jar
