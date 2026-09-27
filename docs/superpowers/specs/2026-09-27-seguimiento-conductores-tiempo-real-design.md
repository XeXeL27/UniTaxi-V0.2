# Seguimiento de conductores en tiempo real

Fecha: 2026-09-27
Estado: aprobado, listo para implementar

## Que se quiere

Un mapa de flota en el panel web de administracion donde el administrador vea, en vivo y sin
recargar, donde esta cada conductor: su posicion moviendose, su disponibilidad y sus datos. Al hacer
clic sobre un conductor se abre su detalle y se puede centrar la camara o seguirlo mientras se mueve.

El objetivo es que la cadena quede montada de punta a punta con el mismo protocolo que usara la app
del conductor: hoy la conduce un simulador, manana la conduce `driver-app`.

## Decisiones tomadas

1. **Donde se consume**: mapa de flota en el panel admin. No es la app del pasajero, que aun no
   existe (`passenger-app/` y `driver-app/` solo tienen `.gitkeep`).
2. **De donde salen las posiciones**: ingesta por WebSocket STOMP. El backend recibe la posicion con
   `@MessageMapping`, la guarda en `ubicacion_conductor` y la difunde a los administradores.
3. **Como se ve**: opcion nueva del menu en el grupo Mapa, no se toca la pantalla `/mapa` que ya
   funciona.
4. **Que muestra**: marcadores con color por disponibilidad, modal de detalle y modo "Seguir" con la
   camara pegada al conductor.
5. **Simulador**: cliente STOMP externo al backend, no una clase interna. Ejercita la ingesta real.

## Fuera de alcance

- Trayectoria del recorrido y persistencia en `punto_recorrido`: eso lo escribe el servicio de viaje
  cuando exista la app del conductor.
- Respaldo por polling REST si el WebSocket se cae.
- Envio de posiciones desde el panel: el panel es solo lector.
- Alertas SOS y notificaciones push.

## Arquitectura

```
driver-app (futura)  --SEND /app/conductor/ubicacion--+
                                                        |
Simulador Dart --------SEND /app/conductor/ubicacion----+
                                                        v
                              STOMP /ws  (JWT en el frame CONNECT)
                                                        |
                @MessageMapping("/conductor/ubicacion")   <-- solo rol CONDUCTOR
                  * valida que el conductor exista y este APROBADO
                  * upsert en ubicacion_conductor
                  * si cambia la disponibilidad, inserta en disponibilidad_conductor
                                                        |
                ConductorUbicacionPublisher ---> /topic/admin/conductores
                                                        |
                                    panel admin (SUBSCRIBE, solo rol ADMIN)
                                                        |
                          Map<int, ConductorEnVivo> --> repintado maximo 4 veces/s
```

El panel nunca publica posiciones.

## Paquete cliente STOMP

Se usa `stomp_dart_client ^3.0.1` (no `stompjs_client`, que no existe en pub.dev; ese era el nombre
del paquete viejo). Soporta web por import condicional y usa `package:web_socket` por debajo, sin
`dart:html`.

Dos detalles no obvios que condicionan el codigo:

- El token viaja en **`stompConnectHeaders`**, que escribe el frame `CONNECT` como texto. Es lo que
  lee `getFirstNativeHeader("Authorization")` en `WebSocketConfig.java:102`. El otro parametro,
  `webSocketConnectHeaders`, no funciona en navegador: el navegador no deja poner cabeceras propias en
  el handshake, asi que el paquete las descarta.
- El parser del cliente trata un frame sin `content-type` como binario y deja `frame.body` en null.
  El broker simple de Spring si reenvia el `content-type` del frame recibido, pero la lectura usa
  `frame.body ?? utf8.decode(frame.binaryBody!)` para no depender de eso.

Los heart-beat del `StompConfig` se alinean en 10 s, que es lo que ya tiene
`setHeartbeatValue(new long[] { 10_000, 10_000 })` en el backend.

## Backend

### Archivos nuevos en `location/`

| Archivo | Contenido |
|---|---|
| `dto/UbicacionConductorRequest.java` | record con `latitud`, `longitud`, `rumbo`, `velocidad` y `disponibilidad`. Los rangos se comprueban en su propio constructor compacto, no con anotaciones de Jakarta: el canal de entrada de STOMP no ejecuta el validador sobre el cuerpo del frame |
| `dto/ConductorUbicacionResponse.java` | record del snapshot REST: id, nombres, apellidos, placa, calificacion, coordenadas, rumbo, velocidad, disponibilidad, `actualizadoEn` |
| `dto/PosicionConductorMensaje.java` | record del delta que viaja por WebSocket: id, coordenadas, rumbo, velocidad, disponibilidad, `actualizadoEn`. Sin nombre ni placa, porque el panel ya los tiene del snapshot |
| `service/UbicacionService.java` | `registrar(Long idUsuario, UbicacionConductorRequest)` y `listarFlota()` |
| `service/ConductorUbicacionController.java` | `@MessageMapping("/conductor/ubicacion")` |
| `service/ConductorUbicacionPublisher.java` | publica en `/topic/admin/conductores` |
| `config/InterceptorWebSocketSeguridad.java` | el `ChannelInterceptor` que hoy es una clase anonima dentro de `WebSocketConfig`, extraido para poder testear el gate de rol |
| `controller/admin/ConductorUbicacionAdminController.java` | `GET /api/admin/conductores/ubicaciones` |

`UbicacionService.registrar` recibe el **id de usuario del token**, nunca un id de conductor del
cuerpo, y resuelve el conductor con `ConductorRepository.findByUsuarioId`. Asi un conductor no puede
reportarse a si mismo como otro. Hace upsert sobre la fila que ya existe por `findByConductorId`, o la
crea, y actualiza `rumbo`, `velocidad` y `actualizado_en`. Si la peticion trae `disponibilidad` y es
distinta de la vigente (`findFirstByConductorIdOrderByDesdeDesc`), inserta una fila nueva en
`disponibilidad_conductor` con `desde` = ahora; no se borra la anterior, porque la tabla es historial.

El mensaje que se difunde es un delta y no el registro completo. La razon es el costo: cada conductor
reporta cada 2 o 3 segundos y el servicio no tiene por que volver a leer la persona y el vehiculo en
cada reporte, ni el panel recibir nombres y placas que ya tiene del snapshot. El panel combina el
delta con su snapshot por `idConductor`.

`listarFlota` devuelve **todos** los conductores APROBADOS y activos, tengan o no posicion: el panel
los cuenta aunque no se dibujen. La posicion viene de `ubicacion_conductor`; si no hay fila, los
campos de coordenada quedan en null. Resuelve personas, posiciones y placas con tres consultas
separadas y `join fetch`, no con una por conductor.

`ConductorUbicacionController` es un `@RestController` con `@MessageMapping`. Toma el principal del
frame con `SimpMessageHeaderAccessor.wrap(mensaje).getUser()`, que por `WebSocketConfig.java:108` es
un `JwtUser`. De ahi salen `idUsuario` y `rol`. Se exige `RolSistema.CONDUCTOR`; con otro rol se lanza
`NegocioException`, que el manejador global traduce a 422 cuando viene por REST.

`ConductorUbicacionPublisher` copia el patron de `ViajeEventPublisher.java:36`: `try/catch` con log
`warn` para que un broker caido nunca tumbe la transaccion que ya escribio en la base.

### Cambios en archivos existentes

- `WebSocketConfig.java:82` — el interceptor pasa a delegar en `InterceptorWebSocketSeguridad`, que
  suma el gate: un `SUBSCRIBE` a un destino que empieza por `/topic/admin/` exige `ROLE_ADMIN`. El
  resto de destinos y el `CONNECT` quedan igual.
- `ConductorRepository` — `findAprobadosParaFlota(EstadoRegistro, SituacionAprobacion)` con
  `join fetch` de usuario y persona, para el snapshot.
- `UbicacionConductorRepository` — `findByConductorIdIn(Collection<Long>)`, para traer todas las
  posiciones de un solo golpe.
- `VehiculoRepository` — `findDeConductores(Collection<Long>, EstadoRegistro)` con `join fetch` del
  conductor, para traer todas las placas de un solo golpe.

### Contrato de los mensajes

Entrada, `SEND /app/conductor/ubicacion`:

```json
{ "latitud": -11.0183, "longitud": -68.7551, "rumbo": 92.5, "velocidad": 24.0, "disponibilidad": "DISPONIBLE" }
```

Salida en `/topic/admin/conductores`, un delta por conductor actualizado:

```json
{ "idConductor": 3, "latitud": -11.0183, "longitud": -68.7551, "rumbo": 92.5,
  "velocidad": 24.0, "disponibilidad": "DISPONIBLE", "actualizadoEn": "2026-09-27T18:40:11" }
```

`GET /api/admin/conductores/ubicaciones` devuelve la lista de `ConductorUbicacionResponse` (este si
con nombre y placa), con `ApiResponse` y coordenadas en null para quien no tenga posicion.

## Frontend

| Archivo | Contenido |
|---|---|
| `admin-panel/pubspec.yaml` | + `stomp_dart_client: ^3.0.1` |
| `admin-panel/lib/core/config.dart` | + `wsUrl`, derivado de `apiUrl` cambiando `http` por `ws` y `https` por `wss` |
| `admin-panel/lib/core/stomp/cliente_stomp.dart` | Envoltura fina sobre `StompClient` |
| `admin-panel/lib/modulos/flota/modelos.dart` | `ConductorEnVivo` y `EstadoWs` |
| `admin-panel/lib/modulos/flota/flota_api.dart` | `listarFlota()` |
| `admin-panel/lib/modulos/flota/pantalla_conductores_vivo.dart` | La pantalla |
| `admin-panel/lib/core/menu.dart` | `ItemMenu('Conductores en vivo', FontAwesomeIcons.radar, '/conductores-vivo')` en el grupo Mapa |
| `admin-panel/lib/core/rutas.dart` | Ruta `/conductores-vivo` |
| `admin-panel/tool/simulador_conductores.dart` | El simulador |

`ClienteStomp` maneja una sola suscripcion y expone un `Stream<Map<String, dynamic>>`. Reconecta solo
(reconexion cada 5 s) y avisa su estado con un `ValueNotifier<EstadoWs>` para que la pantalla pueda
cambiar la pastilla de conexion. Se desconecta en `dispose` y se reconecta si el token de acceso
cambia, porque el `CONNECT` lleva el token congelado en el momento de la conexion.

La pantalla reutiliza `Zona` y `Zona.puntosDesdeWkt` de `lib/modulos/mapa/modelos.dart` en vez de
duplicar el parseo de WKT, y dibuja los poligonos de zona debajo de los marcadores para que se vea en
que zona va cada conductor.

- **Marcador**: circulo con borde, relleno por disponibilidad (verde `ColoresApp.exito` si
  DISPONIBLE, azul `ColoresApp.azulClaro` si OCUPADO, gris `ColoresApp.textoSuave` si no hay senal) y
  rotado segun `rumbo`.
- **Sin senal**: si la posicion tiene mas de 30 s, el marcador pasa a gris.
- **Barra superior**: pastilla del estado de conexion, contadores (X disponibles, Y ocupados, Z sin
  senal) y un interruptor "Solo disponibles".
- **Clic en un marcador**: modal con los datos del conductor y botones "Centrar" y "Seguir", usando
  `abrirModal` de `lib/widgets/modal_formulario.dart`. En modo seguir aparece una pastilla flotante
  "Dejar de seguir" sobre el mapa. Se sale de seguir con ese boton, saliendo de la pantalla, o si el
  conductor se queda sin senal.
- **Rendimiento**: los mensajes entrantes se acumulan en un `Map<int, ConductorEnVivo>` y el
  `setState` ocurre como maximo cada 250 ms, para no redibujar el mapa en cada mensaje.

Sin respaldo por polling: si el WebSocket cae, la pastilla pasa a "Sin conexion" y los marcadores se
congelan con la hora de su ultima posicion.

## Simulador

`admin-panel/tool/simulador_conductores.dart`, se ejecuta con
`dart run tool/simulador_conductores.dart`.

1. Hace login por HTTP contra `/api/auth/login` con `rol: CONDUCTOR` para `conductor1`, `conductor2`,
   `conductor3` y `conductor4` (contrasena `Taxi123*`, la del seed) y guarda cada token.
2. Abre un WebSocket STOMP por conductor a `/ws`, con el token en `stompConnectHeaders`.
3. Cada 2 a 3 segundos envia `SEND /app/conductor/ubicacion` con una posicion que hace un paseo
   aleatorio dentro del poligono de una zona de Cobija, con un rumbo coherente con el movimiento.
4. Cada 30 segundos alterna la disponibilidad entre DISPONIBLE y OCUPADO, para que se vean los tres
   colores en el mapa.

El simulador importa `package:taxiuap_admin/core/stomp/cliente_stomp.dart`, o sea que ejercita el
mismo cliente que usara la app del conductor. Termina con Ctrl+C.

## Seguridad

- El `CONNECT` ya exige JWT (`WebSocketConfig.java:90`); sin cambios.
- `@MessageMapping` acepta solo rol `CONDUCTOR` y resuelve el conductor por el token.
- Un conductor `PENDIENTE`, `RECHAZADO` o `SUSPENDIDO`, o con `estado_conductor = X`, es rechazado
  con `NegocioException`.
- `/topic/admin/**` exige `ROLE_ADMIN` en el `SUBSCRIBE`.
- El endpoint `GET /api/admin/conductores/ubicaciones` queda bajo `/api/admin/**`, asi que lo cubre
  `SecurityConfig.java:75`.

## Verificacion

El proyecto no tiene suite de pruebas, asi que esta funcionalidad si las lleva donde el testeo es
barato y no hace falta base de datos. Mockito, JUnit Jupiter y AssertJ ya estan en el classpath de
pruebas del backend.

- `backend/src/test/.../location/dto/UbicacionConductorRequestTest.java`: los cuatro rangos
  rechazan y las cuatro combinaciones validas pasan. Sin Spring, sin Mockito.
- `backend/src/test/.../location/service/UbicacionServiceTest.java` (Mockito): upsert de conductor sin
  fila previa y con fila previa; rechazo de conductor PENDIENTE, de conductor `estado = X` y de
  usuario sin ficha de conductor; insercion de disponibilidad solo cuando cambia; `listarFlota` con y
  sin posiciones.
- `backend/src/test/.../location/service/ConductorUbicacionControllerTest.java`: un ADMIN no puede
  reportar posicion y el `idConductor` sale del token.
- `backend/src/test/.../config/InterceptorWebSocketSeguridadTest.java`: `SUBSCRIBE` a
  `/topic/admin/...` sin rol ADMIN se rechaza; con rol ADMIN pasa; `/topic/solicitudes` sigue
  pasando para cualquiera autenticado; `SEND` sin usuario se rechaza.
- `admin-panel/test/cliente_stomp_test.dart`: `Config.wsUrl` (http, https, sin esquema) y
  `decodificarMensaje` (json, bytes utf-8, vacio).
- `admin-panel/test/conductor_en_vivo_test.dart`: `ConductorEnVivo.desdeJson` y el corte de "sin
  senal" a los 30 segundos.

Comprobaciones de compilacion y analisis:

- `cd backend && ./gradlew build`
- `cd admin-panel && flutter analyze`
- `cd admin-panel && flutter test`

End to end manual: `docker compose up -d`, `bootRun`, `dart run tool/simulador_conductores.dart`, y
el panel en `/conductores-vivo` con los cuatro conductores moviendose, el modal abriendose y el modo
seguir moviendo la camara. Casos de seguridad a comprobar a mano: `CONNECT` sin token rechazado;
pasajero que se suscribe a `/topic/admin/conductores` rechazado; conductor que envia latitud 999
rechazado.
