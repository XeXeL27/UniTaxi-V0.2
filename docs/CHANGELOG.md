# Bitácora de cambios

> Registro acumulativo e indefinido de cambios, implementaciones y arreglos del proyecto.
> Nueva entrada arriba: `## FECHA` seguida de uno o más `### TIPO · Título`.

| Fecha | Tipo | Descripción |
|---|---|---|
| 2026-09-30 | ✨ | Radar de anillos en el mapa del pasajero mientras se busca conductor |
| 2026-09-30 | 🐛 | Panel inferior vuelve a su altura original, con los botones del mapa encima |
| 2026-09-30 | ✨ | Modal de confirmación con el detalle al pedir viaje (servicio, distancia, pago y precio) |
| 2026-09-30 | 🐛 | Botones de capas y ubicación fijos sobre el mapa en pasajero y conductor |
| 2026-09-30 | 🎨 | Tramos del conductor a la recogida en naranja en vez de gris |
| 2026-09-29 | 🎨 | Tarjeta flotante de distancia/ETA del conductor debajo de la cabecera (solo pasajero) |
| 2026-09-29 | ✨ | Seguimiento en vivo del conductor: distancia y ETA al pasajero durante recogida y viaje |
| 2026-09-29 | ✨ | Favoritos como segunda pestaña de Historial en la app del pasajero |

## Convenciones

- **Fecha:** `YYYY-MM-DD` (no usar texto suelto).
- **Verificación:** cada entrada debe indicar cómo se validó el cambio.
- **Fuente de verdad:** este archivo se mantiene al día al finalizar cada tarea.

---

## 2026-09-30

### ✨ Nuevo · Radar de búsqueda en el mapa mientras se busca conductor (pasajero)

- **Módulo / área:** `app-movil` (Flutter, pasajero)
- **Descripción:** Mientras se espera un conductor, toda la señal estaba en un panelito abajo y el
  mapa se veía quieto. Ahora el mapa muestra la búsqueda: tres anillos azules salen del punto de
  partida, crecen y se desvanecen, uno detrás de otro, mientras la solicitud está abierta.
- **Cambios clave:**
  - `lib/mapa/vista_mapa.dart`: función pura `anillosRadar(avance)`, que devuelve los tres anillos
    (radio en metros y opacidad) de una fase del ciclo, y el widget `RadarBusqueda` que la pinta en
    un `CircleLayer` con un `AnimationController` de 2,4 s en bucle. Los anillos van escalonados un
    tercio de ciclo y la opacidad sube al salir, baja mientras crece y llega a cero justo cuando el
    anillo desaparece, para que el ciclo no se note. Radio de 20 m a 400 m.
  - `MapaBase.capaAnimada` pasa a ser `capasAnimadas` (lista), para que el radar conviva con la
    capa de mototaxistas que se deslizan. Se sigue insertando en el mismo punto del `Stack`, así que
    el orden de dibujo no cambia y el radar queda debajo de los pines A y B.
  - `lib/modulos/pasajero/inicio/pantalla_inicio.dart`: el radar solo entra al árbol en la etapa
    `buscando`, así que el `AnimationController` no corre en ninguna otra. La app del conductor no
    se toca.
  - `lib/modulos/pasajero/viaje/paneles_pasajero.dart`: se desactiva (comentado, no borrado) el
    `LinearProgressIndicator` del panel. La solicitud no tiene porcentaje, así que la barra no
    representaba ningún avance real y quedaba una segunda señal de "estamos buscando" junto con el
    radar.
  - **El radio es ilustrativo:** el backend no filtra por distancia, avisa a los conductores
    conectados, así que el radar dice "buscamos por acá" y no un alcance real. La información
    verdadera de cuántos mototaxistas hay cerca sigue viniendo de los marcadores del mapa, que se
    refrescan cada 5 s.
- **Archivos afectados:**
  - `app-movil/lib/mapa/vista_mapa.dart` (`anillosRadar`, `AnilloRadar`, `RadarBusqueda`, `capasAnimadas`)
  - `app-movil/lib/modulos/pasajero/inicio/pantalla_inicio.dart`
  - `app-movil/lib/modulos/pasajero/viaje/paneles_pasajero.dart`
  - `app-movil/test/radar_busqueda_test.dart` (nuevo)
- **Verificación:** `flutter analyze` sin incidencias; `flutter test` 22/22, cinco de ellos nuevos
  sobre `anillosRadar` (tres anillos siempre, ciclo continuo con tolerancia de punto flotante, radio
  entre 20 y 400 m y creciente, opacidad con tope de 0,45 que termina en cero, y anillos escalonados).

### ✨ Nuevo · Modal de confirmación al pedir viaje (pasajero)



- **Módulo / área:** `app-movil` (Flutter, pasajero)
- **Descripción:** Pedir el taxi mandaba la solicitud al backend en el acto, sin preguntar nada:
  el pasajero tenía que confiar en que el precio del panel era el que le iban a cobrar. Ahora,
  antes de enviar, sale un modal naranja con el detalle de lo que se está pidiendo y dos botones;
  si cancela no se llama al backend.
- **Cambios clave:**
  - `lib/widgets/dialogos.dart`: `_TarjetaAlerta` acepta ahora un `contenido` (Widget) además del
    `mensaje` de texto, con `assert` de que llega uno de los dos. Sigue siendo privado, así que los
    cuatro modales de texto no cambian. Nueva función pública `confirmarViaje(context, {titulo,
    contenido, textoConfirmar, textoCancelar})` que devuelve `bool`; `confirmarAccion` se apoya en
    el mismo `_confirmar` interno para no duplicar la apertura del diálogo.
  - La tarjeta pasa de `width: 320` fijo a `maxWidth: 320` (se estrecha en teléfonos de 320 px en
    lugar de desbordar) y el cuerpo va en un `SingleChildScrollView` limitado al 60 % del alto de
    la pantalla, para que un contenido con varios datos no se salga en pantallas bajas.
  - `lib/modulos/pasajero/viaje/paneles_pasajero.dart`: nueva `DetalleSolicitudViaje`, el cuerpo del
    modal, con el servicio (Moto, con su icono), la distancia de la ruta, la forma de pago
    (efectivo o QR) y el precio ya calculado en el `RecuadroPrecio` que usa el panel. Sin tiempo
    estimado ni los puntos de origen y destino. Reutiliza `DatoRuta` y `RecuadroPrecio`.
  - `lib/modulos/pasajero/inicio/pantalla_inicio.dart`: `_solicitar()` abre el modal y solo si el
    pasajero confirma sigue con el envío. Como los dos botones que piden el taxi (el "Solicitar
    taxi" del panel y el central rojo de la barra) llaman a `_solicitar`, los dos pasan por la
    confirmación. El `setState` de `_enviando` va después del modal, para que el botón no se quede
    en "cargando" mientras se lee. El aviso de "no hay taxistas libres" y el manejo de
    `ApiExcepcion` quedan como estaban.
  - Sin llamadas extra al backend: todo sale de `FlujoPasajero` y del controlador del mapa.
- **Archivos afectados:**
  - `app-movil/lib/widgets/dialogos.dart`
  - `app-movil/lib/modulos/pasajero/viaje/paneles_pasajero.dart`
  - `app-movil/lib/modulos/pasajero/inicio/pantalla_inicio.dart`
  - `app-movil/test/dialogos_test.dart` (nuevo)
- **Verificación:** `flutter analyze` sin incidencias; `flutter test` 17/17, tres de ellos nuevos
  (`confirmarViaje` con contenido devuelve `true` al confirmar y `false` al cancelar y cierra el
  modal, y `confirmarAccion` con texto sigue funcionando).

### 🐛 Arreglo · El panel inferior vuelve a su altura original y los botones quedan encima

- **Módulo / área:** `app-movil` (Flutter, pasajero y conductor)
- **Descripción:** Al dejar los botones del mapa fijos, el panel se subió 62 px para arrancar
  justo debajo de ellos. Eso dejaba un hueco de 62 px con el mapa al pie del panel y, además, tapaba
  62 px más de mapa por arriba, porque el panel se movió entero. El panel vuelve a su sitio
  (`bottom: abajo + 34`, la misma línea de antes del cambio) y los botones se dibujan encima de él.
- **Cambios clave:**
  - En las dos pantallas el `Positioned` del panel va antes que el de los botones en el `Stack`, así
    que los botones quedan por encima: siguen anclados al borde inferior y no se mueven cuando el
    panel cambia de alto, sin huecos y sin tapar más mapa.
  - `PanelInferior` gana `reservaInferior` (px que se dejan vacíos abajo). Las dos pantallas le
    pasan `FilaBotonesMapa.alto` (62), con lo que el contenido nunca queda debajo de los botones.
    Por dentro de la tarjeta se ve 62 px menos, que es el precio de que los botones no se muevan.
  - Conductor: se mantiene la eliminación del condicional que subía o bajaba el panel 24 px según
    la etapa, pero ya no hace falta `subePanel` en `margenesVista`, que vuelve a encuadrar la
    ruta como antes. En `detalle` y `enViaje` el panel queda 24 px más abajo que antes, ya que no
    hay botón central de conectarse que lo tape; como el contenido se desplaza dentro, no afecta.
  - Actualizado el comentario de `FilaBotonesMapa`, que describía la posición anterior.
- **Archivos afectados:**
  - `app-movil/lib/widgets/paneles.dart` (`PanelInferior.reservaInferior`)
  - `app-movil/lib/modulos/pasajero/inicio/pantalla_inicio.dart`
  - `app-movil/lib/modulos/conductor/inicio/pantalla_inicio.dart` (orden en el `Stack`, `margenesVista`)
  - `app-movil/lib/mapa/vista_mapa.dart` (comentario)
- **Verificación:** `flutter analyze` sin incidencias; `flutter test` 17/17.

### 🐛 Arreglo · Botones de capas y ubicación fijos sobre el mapa (pasajero y conductor)

- **Módulo / área:** `app-movil` (Flutter, pasajero y conductor)
- **Descripción:** El botón de tipo de mapa (capas), el de brujula y el de centrar en mi ubicación
  estaban dentro de la misma columna que el panel inferior, anclada al borde inferior de la
  pantalla. Como la fila iba arriba del panel, subía y bajaba con él: al abrir o cerrar el detalle
  del viaje, al cambiar de etapa, al pagar con QR y en general con cualquier cambio de alto del
  panel. Ahora la fila está anclada al borde inferior y no se mueve en ninguna etapa.
- **Cambios clave:**
  - Nueva widget `FilaBotonesMapa` en `lib/mapa/vista_mapa.dart`: la fila de los tres botones
    redondos que estaba duplicada en las dos pantallas, con `static const double alto = 62`
    (botón de 50 + separación de 12) para que el panel pueda anclarse justo encima sin números
    mágicos.
  - En las dos pantallas los botones y el panel pasan a `Positioned` separados: los botones en
    `bottom: abajo + 34` (fijo) y el panel en `bottom: abajo + 34 + FilaBotonesMapa.alto`.
  - El borde superior del panel no cambia, así que el encuadre de la ruta se mantiene igual; el
    panel conserva su alto, su `altoMaximo`, su animación y su contenido.
  - Conductor: se eliminó el condicional que subía o bajaba el panel 24 px según la etapa
    (`detalle`/`enViaje`); sin él, el panel tapaba los botones. Como ahora el panel queda 24 px más
    arriba en esas dos etapas, `margenesVista` reserva esos 24 px para que la ruta se encuadre
    igual. Los 34 px de los botones también los dejan por encima del botón central de conectarse,
    que sobresale unos 30 px de la barra.
- **Archivos afectados:**
  - `app-movil/lib/mapa/vista_mapa.dart` (nueva `FilaBotonesMapa`)
  - `app-movil/lib/modulos/pasajero/inicio/pantalla_inicio.dart`
  - `app-movil/lib/modulos/conductor/inicio/pantalla_inicio.dart` (offsets y `margenesVista`)
- **Verificación:** `flutter analyze` sin incidencias; `flutter test` 14/14.

### 🎨 Mejora · Tramos del conductor a la recogida en naranja (pasajero y conductor)

- **Módulo / área:** `app-movil` (Flutter, mapa)
- **Descripción:** La línea discontinua que muestra de dónde viene el conductor a recoger al
  pasajero iba en el gris de los textos suaves (`#7F8C8D`), que se confundía con las calles y los
  edificios del mapa, sobre todo en la capa satelital. Ahora es naranja con borde oscuro, como los
  tramos alternativos de las apps de mapa, y se distingue de la ruta azul en las dos apps.
- **Cambios clave:**
  - Nuevos colores `ColoresApp.rutaSecundaria` (`#F57C00`) y `ColoresApp.rutaSecundariaBorde`
    (`#B26500`), junto a `ruta`/`rutaBorde`.
  - `MapaBase` los aplica a las dos líneas de 5 px: `acercamiento` (en el conductor, desde su GPS
    hasta el punto A) y `rutaConductor` (en el pasajero, desde la posición del conductor hasta el
    punto de referencia). Se les añade borde de 1,5 px para que se lean también sobre el satelital
    y en zonas densas, igual que la ruta azul.
  - El conector punteado de 3 px entre los pines A/B y la calle donde arranca la ruta
    (`_tramoAPie`) sigue en gris: es un detalle corto y no se pidió cambiarlo.
  - Comentarios actualizados en `MapaBase`, `ControladorMapa` y `cambiarAcercamiento`, que decían
    "tramo gris".
- **Archivos afectados:**
  - `app-movil/lib/core/tema.dart` (dos colores nuevos)
  - `app-movil/lib/mapa/vista_mapa.dart` (las dos polilíneas y su comentario)
  - `app-movil/lib/mapa/controlador_mapa.dart` (solo comentarios)
- **Verificación:** `flutter analyze` sin incidencias; `flutter test` 14/14.

## 2026-09-29

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
