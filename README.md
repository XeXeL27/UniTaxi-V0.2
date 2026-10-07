# UniTaxi-V0.2

App de transporte tipo Uber/inDrive para estudiantes de Bolivia (Cobija, Pando), con descuentos para
estudiantes verificados con su comprobante de matrícula. Primera versión solo para Android.

| Carpeta | Contenido | Tecnología |
|---|---|---|
| `backend/` | API REST, JWT, WebSocket STOMP, reglas de negocio | Spring Boot 4.1, Java 21, Gradle |
| `admin-panel/` | Panel web de administración | Flutter Web |
| `app-movil/` | Una sola app para pasajeros y conductores (Android; también se sirve como web) | Flutter |
| `docker-compose.yml` | Base de datos de desarrollo | PostgreSQL 16 + PostGIS 3.5 |

Las convenciones del proyecto, el modelo de datos y las reglas de negocio están en [CLAUDE.md](CLAUDE.md).

## Requisitos

- Docker con Docker Compose
- Java 21
- Flutter 3.x (para el panel admin: Chrome)

## Configuración inicial (una sola vez)

Los archivos con credenciales no se suben al repositorio. Se crean a partir de sus plantillas:

```bash
cp .env.example .env
cp backend/src/main/resources/application-profile.properties.example \
   backend/src/main/resources/application-profile.properties
```

Completar en ambos los valores `<cambiar>`. La contraseña de `.env` (`TAXIUAP_DB_PASSWORD`) debe ser la
misma que `spring.datasource.password` del perfil xexel.

## Iniciar todo (un solo comando)

```bash
./iniciar.sh
```

Levanta la base de datos, compila el panel y la app si su código cambió y arranca el backend, que sirve
todo desde el mismo servidor. Luego se entra solo cambiando el link:

| Link | Qué abre |
|---|---|
| `http://localhost:5557/admin` | Panel de administración (cuentas ADMIN) |
| `http://localhost:5557/app` | App: según la cuenta muestra lo del pasajero o lo del conductor; si la persona tiene las dos, pregunta cómo quiere ingresar |
| `http://IP-de-la-PC:5557/app` | La app desde un celular de la misma red (en el navegador el GPS solo funciona en `localhost` o con HTTPS) |

- `./iniciar.sh --compilar` recompila los dos frontends aunque no hayan cambiado.
- `SERVER_PORT=8081 ./iniciar.sh` usa otro puerto (por defecto 5557).

### Producción

El sistema se publica en `https://uni-taxi.uap.edu.bo` (panel en `/admin`, app en `/app`): el backend
escucha en el puerto 5557 y delante va un proxy (nginx, Apache...) con el certificado que reenvía a
`http://127.0.0.1:5557` las cabeceras `Host`, `X-Forwarded-Proto` y `X-Forwarded-Host`, y la
conexión WebSocket de `/ws` (`Upgrade` / `Connection`). El DNS de `uni-taxi.uap.edu.bo` debe apuntar
a ese servidor.

Requisitos del servidor: Java 21 y la base de datos (externa: `iniciar.sh` no levanta ninguna). No hace
falta Flutter: el panel y la app ya van compilados dentro del backend (`backend/src/main/resources/web`).

```bash
git clone https://github.com/Equipo-de-Sistemas/UniTaxiV2.git && cd UniTaxiV2
./iniciar.sh
```

Para actualizar: `git pull` y volver a correr `./iniciar.sh`. El script no toca la base de datos, el
`.env` ni el perfil de la máquina (`application-<perfil>.properties`): la conexión, el puerto y las
claves son los de esa configuración.

- Base de datos de desarrollo en Docker (PostGIS, puerto 5436): `./iniciar.sh --con-bd` o
  `docker compose up -d`.
- Logs: consola y `logs/taxiuap.log` (30 días, comprimidos) más `logs/taxiuap-errores.log` (solo
  advertencias y errores, lo primero que se revisa). Otra carpeta con `LOG_DIR`; el SQL con
  `LOG_SQL=DEBUG ./iniciar.sh`.
- Hora: el backend usa la de Bolivia (America/La_Paz) aunque la máquina esté en UTC.

En una máquina nueva se copia `.env.example` como `.env` y se completa; con la BD vacía, el backend
crea el administrador inicial y los catálogos
mínimos (UAP, tipos de vehículo, categorías ESTANDAR, MOTO y DELIVERY con su tarifa, zonas y
etiquetas). Después se completan en el `.env` las integraciones opcionales: Google, Gemini, SIGSE,
correo y Firebase (sin ellas el sistema arranca y esas funciones quedan apagadas).

Al cambiar el panel o la app, antes de subir: `./compilar-web.sh` (compila los dos y actualiza la copia
del backend). APK de producción: `cd app-movil && flutter build apk --release` (sin `API_URL` usa
`https://uni-taxi.uap.edu.bo`; para otro servidor, `--dart-define=API_URL=http://servidor:5557`).

El panel se abre con el administrador inicial: usuario `admin` y la contraseña de
`admin.inicial.password` del perfil xexel.

### Para programar con recarga en caliente

```bash
docker compose up -d
cd backend && ./gradlew bootRun
cd admin-panel && flutter run -d chrome --web-port 5173
cd app-movil && flutter run -d chrome --web-port 5174      # o en el celular/emulador: flutter run
```

Usuarios de prueba del seed (contraseña `Taxi123*`): `pasajero1` a `pasajero8`, `conductor1` a
`conductor6`, `admin.pruebas`.

## Detener todo

```bash
# Backend (con ./iniciar.sh): Ctrl+C en su terminal
# flutter run: tecla q en su terminal
docker compose down          # detiene la base de datos; los datos quedan guardados
```

`docker compose down -v` borra también la base de datos (el seed la vuelve a llenar al arrancar).

## Compilar

```bash
cd backend && ./gradlew build

# App Android (hace falta el Android SDK):
cd app-movil && flutter build appbundle --release

# Panel admin para producción:
cd admin-panel && flutter build web --release --no-tree-shake-icons --no-web-resources-cdn \
    --dart-define=API_URL=https://servidor-del-backend
```

- `--no-tree-shake-icons`: sin esta opción algunos iconos de Font Awesome salen como cuadros vacíos.
- `--no-web-resources-cdn`: el panel no depende de internet para cargar su motor de dibujo.
