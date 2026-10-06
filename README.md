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

### Producción (máquina virtual)

El sistema queda publicado en `http://virtual.uap.edu.bo:5557` (panel en `/admin`, app en `/app`).

1. Copiar `.env.example` a `.env` y completar los valores (`TAXIUAP_DB_PASSWORD`, `JWT_SECRET`,
   `ADMIN_CORREO`, `ADMIN_PASSWORD`, Google, Gemini, SIGSE, correo). Con el `.env` alcanza: la BD,
   el puerto y la dirección pública tienen sus valores en `application.properties`.
2. Abrir el puerto 5557 en el firewall de la máquina virtual.
3. `./iniciar.sh` (o `SPRING_PROFILES_ACTIVE=prod ./iniciar.sh` para no cargar ningún perfil local).
4. APK que apunta a producción: `cd app-movil && flutter build apk --release` (sin `API_URL` usa
   `http://virtual.uap.edu.bo:5557`; para otro servidor, `--dart-define=API_URL=http://servidor:5557`).

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
