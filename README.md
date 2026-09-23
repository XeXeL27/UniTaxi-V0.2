# UniTaxi-V0.2

App de transporte tipo Uber/inDrive para estudiantes de Bolivia (Cobija, Pando), con descuentos para
estudiantes verificados con su comprobante de matrícula. Primera versión solo para Android.

| Carpeta | Contenido | Tecnología |
|---|---|---|
| `backend/` | API REST, JWT, WebSocket STOMP, reglas de negocio | Spring Boot 4.1, Java 21, Gradle |
| `admin-panel/` | Panel web de administración | Flutter Web |
| `passenger-app/` | App del pasajero (pendiente) | Flutter |
| `driver-app/` | App del conductor (pendiente) | Flutter |
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
cp backend/src/main/resources/application-xexel.properties.example \
   backend/src/main/resources/application-xexel.properties
```

Completar en ambos los valores `<cambiar>`. La contraseña de `.env` (`TAXIUAP_DB_PASSWORD`) debe ser la
misma que `spring.datasource.password` del perfil xexel.

## Iniciar todo

En tres terminales, en este orden:

```bash
# 1. Base de datos (puerto 5436)
docker compose up -d
docker compose ps            # debe decir "healthy"

# 2. Backend (puerto 8080). Al arrancar crea las tablas y carga datos de prueba (perfil xexel)
cd backend && ./gradlew bootRun

# 3. Panel admin (puerto 5173, abre Chrome)
cd admin-panel && flutter run -d chrome --web-port 5173
```

El panel se abre con el administrador inicial: usuario `admin` y la contraseña de
`admin.inicial.password` del perfil xexel.

Usuarios de prueba del seed (contraseña `Taxi123*`): `pasajero1` a `pasajero8`, `conductor1` a
`conductor6`, `admin.pruebas`.

## Detener todo

```bash
# Panel: tecla q en la terminal de flutter run
# Backend: Ctrl+C en su terminal
docker compose down          # detiene la base de datos; los datos quedan guardados
```

`docker compose down -v` borra también la base de datos (el seed la vuelve a llenar al arrancar).

## Compilar

```bash
cd backend && ./gradlew build

# Panel admin para producción:
cd admin-panel && flutter build web --release --no-tree-shake-icons --no-web-resources-cdn \
    --dart-define=API_URL=https://servidor-del-backend
```

- `--no-tree-shake-icons`: sin esta opción algunos iconos de Font Awesome salen como cuadros vacíos.
- `--no-web-resources-cdn`: el panel no depende de internet para cargar su motor de dibujo.
