# Bitácora de cambios

> Registro acumulativo e indefinido de cambios, implementaciones y arreglos del proyecto.
> Nueva entrada arriba: `## FECHA` seguida de uno o más `### TIPO · Título`.

| Fecha | Tipo | Descripción |
|---|---|---|
| 2026-09-29 | 🎨 | Rediseño de la hoja de soporte: asistencia, ayuda rápida y canales de atención |
| 2026-09-29 | 🎨 | Tarjeta flotante de distancia/ETA del conductor debajo de la cabecera (solo pasajero) |
| 2026-09-29 | ✨ | Seguimiento en vivo del conductor: distancia y ETA al pasajero durante recogida y viaje |
| 2026-09-29 | ✨ | Favoritos como segunda pestaña de Historial en la app del pasajero |

## Convenciones

- **Fecha:** `YYYY-MM-DD` (no usar texto suelto).
- **Verificación:** cada entrada debe indicar cómo se validó el cambio.
- **Fuente de verdad:** este archivo se mantiene al día al finalizar cada tarea.

---

## 2026-09-29

### 🎨 Mejora · Rediseño de la hoja de soporte (asistencia, ayuda rápida y canales de atención)

- **Módulo / área:** `app-movil` (Flutter, pasajero y conductor)
- **Descripción:** La hoja de ayuda (`mostrarAyuda`) se rediseñó completamente con una estructura
  más completa: saludo de asistencia, sección de ayuda rápida con tips prácticos, pasos de uso
  por rol, y canales de atención con correo, dirección y horario. Se agregó `url_launcher` para
  abrir enlaces externos (email y mapas).
- **Cambios clave:**
  - **Héroe:** ícono de auriculares, pregunta según rol ("¿Necesitas asistencia?" / "¿Necesitas
    ayuda con la app?") y afirmación "Estamos disponibles para ayudarte en lo que necesites."
  - **AYUDA RÁPIDA:** dos tips con íconos (activar ubicación, mantener notificaciones activas)
    seguidos de los 3 pasos de uso del rol (conductor/pasajero).
  - **CANALES DE ATENCIÓN:** tres filas tipo tarjeta con íconos y colores:
    - ✉️ Correo: `unitaxi@uap.edu.bo` → abre email (`mailto:`)
    - 📍 Dirección: "X6JW+Q5P, C. Bruno Racua, Cobija" → abre Google Maps
    - 🕐 Horario: "Lunes a viernes: 8:00 - 12:00 y 14:00 - 16:00" (informativo)
  - Si el enlace falla, copia al portapapeles y muestra aviso.
  - Cierre con línea de emergencia 110 y frase "¿Tienes preguntas? Estamos encantados de ayudarte."
  - Hoja con `SingleChildScrollView` y altura máxima 85% de la pantalla (contenido más largo).
  - Nueva dependencia: `url_launcher: ^6.3.1` + queries en `AndroidManifest.xml` para `mailto:` y `https:`.
- **Archivos afectados:**
  - `app-movil/pubspec.yaml` (url_launcher)
  - `app-movil/android/app/src/main/AndroidManifest.xml` (queries para intents)
  - `app-movil/lib/widgets/inicio_mapa.dart` (mostrarAyuda reescrito + widgets auxiliares)
- **Verificación:** `flutter pub get`, `flutter analyze` sin incidencias.

### 🎨 Mejora · Tarjeta flotante de distancia/ETA del conductor (solo pasajero)

- **Módulo / área:** `app-movil` (Flutter, pasajero)
- **Descripción:** La distancia y el tiempo de llegada del conductor ahora se muestran en una
  tarjeta flotante tipo notificación debajo de la cabecera superior, sobre el mapa. Solo visible
  para el pasajero durante el viaje (CONFIRMADO → EN_CURSO).
- **Cambios clave:**
  - `CabeceraInicio`: se revirtió el parámetro `banner` (no se usa más).
  - Nueva widget `TarjetaSeguimientoConductor`: Material blanco con elevación, radio 14, icono
    circular con color del estado del viaje, título en negrita ("Llega en ~2 min" / "Llegas en
    ~7 min") y subtítulo suave ("A 350 m · 1234-ABC" / "2,4 km hasta destino").
  - La tarjeta aparece solo cuando hay viaje activo, ruta al conductor calculada, y etapa
    enViaje. Se oculta al completar/cancelar.
  - Al tocar la tarjeta, reabre el panel inferior si estaba plegado.
  - Los números se actualizan en silencio (sin re-animar) vía `ListenableBuilder` sobre el flujo.
- **Archivos afectados:**
  - `app-movil/lib/widgets/inicio_mapa.dart` (CabeceraInicio revertido)
  - `app-movil/lib/modulos/pasajero/inicio/pantalla_inicio.dart` (TarjetaSeguimientoConductor)
  - `app-movil/lib/modulos/pasajero/viaje/paneles_pasajero.dart` (PanelViaje sin banner)
- **Verificación:** `flutter analyze` sin incidencias.

### ✨ Nuevo · Seguimiento en vivo del conductor asignado (pasajero)

- **Módulo / área:** `backend` (Spring Boot) + `app-movil` (Flutter, pasajero)
- **Descripción:** Cuando un conductor acepta un viaje, el pasajero ahora ve en tiempo real de
  dónde viene el conductor, a qué distancia está y cuánto tarda en llegar. El seguimiento se
  mantiene durante todo el viaje (recogida y trayecto al destino). La posición se recibe por
  WebSocket STOMP con respaldo REST cada 3 s si el WebSocket falla.
- **Cambios clave (backend):**
  - `SeguimientoViajePublisher` (nuevo en `trip/service`): cuando un conductor reporta su
    posición, si tiene un viaje activo, envía `PosicionConductorMensaje` a la cola por usuario
    del pasajero (`/user/queue/conductor-ubicacion`). Solo ese pasajero recibe el mensaje.
  - `UbicacionService.registrar()`: integrado con `SeguimientoViajePublisher` tras publicar al
    admin.
  - `UbicacionConductorRepository.distanciaMetrosHasta()`: consulta nativa PostGIS
    (`ST_Distance` sobre geography) para calcular distancia en metros en línea recta.
  - `UbicacionConductorViajeResponse` (nuevo DTO): latitud, longitud, rumbo, velocidad,
    actualizadoEn, distanciaMetros, puntoReferencia (ORIGEN o DESTINO).
  - `ViajeService.ubicacionConductorSeguimiento()`: valida que el llamante es el pasajero del
    viaje y que el viaje está activo; devuelve la posición del conductor y la distancia al
    punto de referencia (origen mientras va a recoger, destino durante el viaje).
  - `GET /api/pasajero/viajes/{id}/ubicacion-conductor`: endpoint REST de respaldo.
- **Cambios clave (app):**
  - `ReceptorUbicacionConductor` (nuevo en `core/`): suscriptor STOMP que recibe la posición
    del conductor en `/user/queue/conductor-ubicacion`.
  - `UbicacionConductorViaje` (nuevo modelo): respuesta del endpoint REST de respaldo.
  - `ViajeApi.ubicacionConductor()`: método para el respaldo REST.
  - `ControladorMapa`: estado `conductorUbicacion` + `conductorRumbo` + `rutaConductor`;
    métodos `iniciarSeguimientoConductor`, `cambiarPuntoReferenciaConductor`,
    `ponerSeguimientoConductor`, `detenerSeguimientoConductor`.
  - `MapaBase` (vista_mapa): dibuja la ruta punteada gris del conductor al punto de referencia
    y el marcador del vehículo con rotación según el rumbo.
  - `FlujoPasajero`: integra `ReceptorUbicacionConductor` al entrar en viaje; si no llega
    posición por WebSocket en 10 s, pide por REST; actualiza el punto de referencia cuando
    cambia la situación del viaje (origen → destino al pasar a EN_CURSO).
  - `PanelViaje`: muestra "Tu conductor está a X m · llega en ~Y min" durante la recogida, y
    "A tu destino: X, Y min" durante el viaje.
- **Archivos afectados (backend):**
  - `backend/src/main/java/com/taxiuap/backend/trip/service/SeguimientoViajePublisher.java` (nuevo)
  - `backend/src/main/java/com/taxiuap/backend/location/service/UbicacionService.java` (inyección + llamada)
  - `backend/src/main/java/com/taxiuap/backend/location/repository/UbicacionConductorRepository.java` (native query)
  - `backend/src/main/java/com/taxiuap/backend/location/dto/UbicacionConductorViajeResponse.java` (nuevo)
  - `backend/src/main/java/com/taxiuap/backend/trip/service/ViajeService.java` (método + inyección)
  - `backend/src/main/java/com/taxiuap/backend/controller/pasajero/ViajePasajeroController.java` (endpoint)
  - `backend/src/test/java/com/taxiuap/backend/location/service/UbicacionServiceTest.java` (mock)
- **Archivos afectados (app):**
  - `app-movil/lib/core/receptor_ubicacion.dart` (nuevo)
  - `app-movil/lib/modulos/pasajero/viaje/viaje_api.dart` (modelo + método)
  - `app-movil/lib/mapa/controlador_mapa.dart` (estado + métodos)
  - `app-movil/lib/mapa/vista_mapa.dart` (ruta + marcador del conductor)
  - `app-movil/lib/modulos/pasajero/viaje/flujo_pasajero.dart` (integración STOMP + REST)
  - `app-movil/lib/modulos/pasajero/viaje/paneles_pasajero.dart` (UI distancia/ETA)
  - `app-movil/lib/modulos/pasajero/inicio/pantalla_inicio.dart` (pasa Sesion a FlujoPasajero)
- **Verificación:** `./gradlew build` OK (40 tests pass); `flutter analyze` sin incidencias.

### ✨ Nuevo · Favoritos dentro de Historial (app del pasajero)

- **Módulo / área:** `app-movil` (Flutter, pasajero)
- **Descripción:** Favoritos deja de ser una sección propia de la barra inferior y pasa a ser la
  segunda pestaña de la sección Historial, junto a los viajes. Solo afecta al pasajero; el
  conductor y el panel admin quedan intactos. Sin cambios en el backend.
- **Cambios clave:**
  - `PantallaHistorial` acepta un builder opcional `pestanaFavoritos` que recibe los viajes ya
    cargados y el relleno. Con él muestra las pestañas `Historial | Favoritos`; sin él se comporta
    exactamente como antes (una sola lista), que es como lo ve el conductor.
  - La pestaña se reinicia en Historial cada vez que se entra a la sección (`recargar`), con un
    setter para que el cambio de estado no se pierda al recargar.
  - Nuevo `SelectorPestanas` reutilizable en `lib/widgets/`: pestañas tipo carpeta.
  - Nuevos "Lugares frecuentes" derivados en cliente de los viajes ya cargados (`COMPLETADOS`):
    agrupación de destinos a 60 m o menos, mínimo de 2 visitas, orden por frecuencia y a igualdad
    por última visita, y nombre/dirección del viaje más reciente del grupo.
  - `sinRepetirConFavoritos` quita de "Lugares frecuentes" los lugares que ya están guardados
    (dentro de 60 m), para que un mismo lugar no aparezca en los dos grupos.
  - "Agregar a favoritos" llama a `FavoritosApi.crear` (`POST /api/pasajero/direcciones`) y el
    lugar deja de listarse como frecuente porque ya figura entre los guardados.
  - Tocar cualquier lugar, guardado o deducido, lo pone como destino y regresa al mapa; si el
    pasajero ya tiene un viaje en curso avisa y no cambia nada.
  - Un favorito sin posición se muestra sin acción de destino (no se sabe a dónde ir).
  - Barra inferior del pasajero de 4 a 3 secciones: `Inicio | Historial | Más`.
- **Archivos afectados:**
  - `app-movil/lib/widgets/selector_pestanas.dart` (nuevo)
  - `app-movil/lib/modulos/pasajero/favoritos/lugares_frecuentes.dart` (nuevo)
  - `app-movil/lib/modulos/pasajero/favoritos/seccion_favoritos.dart` (reescrito: los dos grupos)
  - `app-movil/lib/comun/historial_viajes.dart` (pestañas y builder opcional)
  - `app-movil/lib/modulos/pasajero/inicio/pantalla_inicio.dart` (barra, cableado, promoción)
  - `app-movil/test/lugares_frecuentes_test.dart` (nuevo, 14 pruebas)
- **Verificación:** `flutter analyze` sin incidencias; `flutter test` 14/14;
  `dart format --line-length 120` sobre los archivos del cambio.
