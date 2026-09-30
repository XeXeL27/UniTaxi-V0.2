# Bitácora de cambios

> Registro acumulativo e indefinido de cambios, implementaciones y arreglos del proyecto.
> Nueva entrada arriba: `## FECHA` seguida de uno o más `### TIPO · Título`.

| Fecha | Tipo | Descripción |
|---|---|---|
| 2026-09-30 | 🎨 | Botones del mapa: capas y ubicación sobre el panel (sin taparlo) y brújula en la esquina superior |
| 2026-09-30 | 🐛 | Chat en memoria: se restaura @Transactional y desaparece el LazyInitializationException |
| 2026-09-30 | 🐛 | Chat en memoria y en modal flotante: se arregla la autenticación del WebSocket y los mensajes sí se ven |
| 2026-09-30 | 🐛 | El satelital ya no se llena de gris: tope de zoom 17 en Cobija |
| 2026-09-30 | ✨ | Radar de anillos en el mapa del pasajero mientras se busca conductor |
| 2026-09-30 | 🐛 | Panel inferior vuelve a su altura original, con los botones del mapa encima |
| 2026-09-30 | ✨ | Modal de confirmación con el detalle al pedir viaje (servicio, distancia, pago y precio) |
| 2026-09-30 | 🐛 | Botones de capas y ubicación fijos sobre el mapa en pasajero y conductor |
| 2026-09-30 | 🎨 | Tramos del conductor a la recogida en naranja en vez de gris |
| 2026-09-29 | 🎨 | Rediseño de la hoja de soporte: asistencia, ayuda rápida y canales de atención |
| 2026-09-29 | 🎨 | Tarjeta flotante de distancia/ETA del conductor debajo de la cabecera (solo pasajero) |
| 2026-09-29 | ✨ | Seguimiento en vivo del conductor: distancia y ETA al pasajero durante recogida y viaje |
| 2026-09-29 | ✨ | Favoritos como segunda pestaña de Historial en la app del pasajero |

## Convenciones

- **Fecha:** `YYYY-MM-DD` (no usar texto suelto).
- **Verificación:** cada entrada debe indicar cómo se validó el cambio.
- **Fuente de verdad:** este archivo se mantiene al día al finalizar cada tarea.

---

## 2026-09-30

### 🎨 Rediseño · Los botones del mapa dejan de montarse sobre el panel

- **Módulo / área:** `app-movil` (mapa compartido por pasajero y conductor)
- **Descripción:** Los botones de capas, brújula y ubicación iban en su propio `Positioned`
  posterior al panel en el Stack, a la misma altura (`bottom: abajo + 34`), así que siempre
  quedaban dibujados **encima de la tarjeta** de abajo (con un `reservaInferior` de 62 px dentro
  del panel como parche para que el contenido no quedara debajo). El usuario pidió cambiar eso:
  la opción elegida es que los botones vivan **sobre el panel, moviéndose con él**, y sacar la
  brújula del grupo hacia la esquina superior.
- **Cambios clave:**
  - `FilaBotonesMapa` (vista_mapa.dart): ahora lleva solo **capas + ubicación**, alineados a la
    derecha con el mismo ancho máximo (560) y margen (12) que el panel. Se elimina el
    `static const alto`.
  - Pantalla del pasajero y la del conductor: los botones y el panel pasan a **una sola
    `Column` dentro de un único `Positioned`** anclado abajo: los botones quedan justo encima de
    la tarjeta, nunca sobre ella, y suben/bajan con el panel. Con `panel == null` (eligiendo sin
    destino) la columna queda solo con los botones, como antes.
  - `PanelInferior` (paneles.dart): se elimina `reservaInferior` (ya nadie se monta sobre el
    panel, no hace falta dejarle aire).
  - Nueva `BrujulaArriba` (vista_mapa.dart): la brújula va ahora en el flujo de la columna
    superior (debajo de la cabecera y de las tarjetas, por eso nunca se monta sobre nada),
    alineada a la derecha y solo visible con el mapa girado. En el pasajero se oculta mientras
    el selector de vehículo esté visible, porque ahi no queda lugar libre en esa esquina.
  - Panel del pasajero que crece para el QR: tope de `0.5` a `0.44`, para que el botonero de
    arriba no alcance a la tarjeta ETA en pantallas chicas.
  - La columna vertical de 2 botones (110 px) que se barajó no sirve: durante el viaje, en
    pantallas de 667–720 px chocaría con la tarjeta ETA. Como solo quedan 2 botones (la brújula
    se fue arriba), van como fila horizontal de 60 px, que sí cabe en todos los casos.
- **Archivos afectados:** `app-movil/lib/mapa/vista_mapa.dart`,
  `app-movil/lib/widgets/paneles.dart`,
  `app-movil/lib/modulos/pasajero/inicio/pantalla_inicio.dart`,
  `app-movil/lib/modulos/conductor/inicio/pantalla_inicio.dart`, `docs/CHANGELOG.md`
- **Verificación:** `flutter analyze` sin incidencias; `flutter test` 26/26. Pendiente la prueba
  manual en dispositivo: botones sobre el panel en las etapas con panel, brújula al girar el
  mapa, y que nada quede tapado en el viaje (tarjeta ETA, QR, selector de vehículo).

### 🐛 Arreglo · Chat en memoria: sin sesión de Hibernate al leer la persona del emisor

- **Módulo / área:** `backend` (chat)
- **Descripción:** Tras pasar `ChatService` a memoria seguía sin haber comunicación: cada envío
  provocaba `LazyInitializationException: Could not initialize proxy [Persona#...] - no session`
  en el hilo STOMP. La causa fue el propio cambio: al reescribir el servicio se quitó la
  anotación `@Transactional` de clase que tenía, y `usuarioRepository.findById` devuelve una
  `Usuario` cuya `persona` es perezosa; sin transacción no hay sesión de Hibernate y leer
  `getNombres()` revienta, con lo que el mensaje nunca se guardaba ni se reenviaba.
- **Cambios clave:**
  - `ChatService` recupera `@Transactional(readOnly = true)` a nivel de clase (cubre
    `historial`, `marcarLeidos` y `contarNoLeidos`, que también leen entities) y
    `@Transactional` de lectura-escritura en `enviar`. No es para persistir (no hay BD en el
    chat): es para mantener la sesión abierta mientras se leen los entities perezosos.
  - La transacción corre en el hilo de STOMP sin problema: es una transacción normal de Spring,
    no necesita `SecurityContext`.
- **Archivos afectados:** `backend/src/main/java/com/taxiuap/backend/communication/service/ChatService.java`,
  `docs/CHANGELOG.md`
- **Verificación:** `./gradlew test` → BUILD SUCCESSFUL (49 pruebas, 0 fallos). Pendiente la
  prueba manual en el dispositivo (pasajero y conductor enviándose mensajes en un viaje activo).

### 🐛 Arreglo · Chat: modal flotante, mensajes en memoria y autenticación del WebSocket corregida

- **Módulo / área:** `backend` (chat) y `app-movil` (chat del viaje)
- **Descripción:** Al probar el chat aparecieron tres problemas: (1) abría una pantalla completa
  que tapaba el mapa; (2) no se veían los mensajes; y (3) el backend reventaba con
  `AuthenticationCredentialsNotFoundException: No hay usuario autenticado` cada vez que alguien
  enviaba un mensaje. La causa raíz de (3) es que el handler `@MessageMapping` de STOMP corre en
  un hilo del pool `taxiuap-async`, sin `SecurityContext`, y `ChatService.enviar` terminaba
  llamando a `ViajeService.obtenerViajeDelUsuario`, que saca el usuario de `UsuarioActual`
  (SecurityContext). Además (2): el backend solo reenviaba el mensaje al receptor, así que quien
  escribía nunca veía su propia burbuja. Por decisión del usuario el chat pasó a ser **en
  memoria** (sin persistir en la tabla `mensaje`), lo que además elimina la dependencia del
  SecurityContext en el hilo de WebSocket.
- **Cambios clave:**
  - `ViajeService` gana `obtenerViajeParaUsuario(idViaje, idUsuario)`: mismo control de
    participación pero con el id pasado por parámetro; `obtenerViajeDelUsuario` ahora lo delega
    pasando `UsuarioActual.idUsuario()`.
  - `ChatService` reescrito en memoria: mensajes en un `ConcurrentHashMap` por viaje (tope de
    200 por conversación), ids correlativos con `AtomicLong`, `leido` como flag mutable, y
    limpieza de la conversación cuando el viaje está COMPLETADO/CANCELADO. Ya no usa
    `MensajeRepository` ni `@Transactional`. La entidad `mensaje`, su repositorio y el seed
    quedan intactos (solo no se usan en el chat).
  - `ChatController` reenvía el mensaje **a los dos** participantes (receptor y emisor) por su
    `/queue/chat`, para que la burbuja propia aparezca al instante.
  - Flutter: `BotonChat` ahora abre `VistaChat` con `showDialog` en un `Dialog` de ancho máximo
    420 y alto máximo 520, en vez de una ruta a pantalla completa; `VistaChat` pierde el
    `Scaffold`/`AppBar` y gana cabecera con nombre, estado de conexión y botón de cerrar.
  - `ChatEstado._alRecibir` no cuenta como no leído ni notifica los mensajes propios (son el eco
    del backend).
- **Archivos afectados:** `backend/src/main/java/com/taxiuap/backend/trip/service/ViajeService.java`,
  `backend/src/main/java/com/taxiuap/backend/communication/service/ChatService.java`,
  `backend/src/main/java/com/taxiuap/backend/controller/chat/ChatController.java`,
  `backend/src/test/java/com/taxiuap/backend/communication/service/ChatServiceTest.java`,
  `app-movil/lib/comun/vista_chat.dart`, `app-movil/lib/core/chat.dart`, `docs/CHANGELOG.md`
- **Verificación:** `./gradlew test` → BUILD SUCCESSFUL (49 pruebas, 0 fallos;
  `ChatServiceTest` reescrito con 9 casos: envío a los dos sentidos, viaje terminado, no
  participante, historial ordenado, historial de viaje terminado vacío, marcar leídos y no
  leídos). `flutter analyze` sin incidencias; `flutter test` 26/26. Queda pendiente la prueba
  manual en dispositivo: enviar mensajes entre pasajero y conductor durante un viaje activo y
  ver el modal flotante sobre el mapa.

### 🐛 Arreglo · El mapa satelital deja de mostrar "Map data not yet available" al acercar (pasajero y conductor)

- **Módulo / área:** `app-movil` (Flutter, mapa compartido por las dos apps)
- **Descripción:** Al pasar a la vista satelital y acercar más de cierto nivel, el mapa se llenaba
  del recuadro gris con el mensaje "Map data not yet available". No era un fallo de red ni de
  `flutter_map`: la capa satelital usa Esri World Imagery, que en Cobija (y en todo Pando) no
  tiene ortofoto por encima del nivel 17, aunque el servicio anuncie niveles hasta el 23. La app
  permitía llegar a 19 y el `maxNativeZoom` del satelital estaba en 18, así que desde 18 en
  adelante Esri respondía su tesela de relleno.
- **Evidencia:** Sondeo directo a los servidores (tamaño de la tesela, mismo punto de Cobija):
  z=16 y z=17 dan ~20 KB (imagen real); z=18, 19 y 20 dan siempre 2521 bytes exactos (el aviso).
  En La Paz, Santa Cruz y Cochabamba la imagen real sí llega a z=19, por eso el bug solo aparece
  donde opera la app.
- **Cambios clave:**
  - `lib/mapa/controlador_mapa.dart`: `CapaMapa` gana el campo `zoomNativo` (calles 19, satelital
    17), que documenta el último nivel con teselas reales de cada proveedor. El tope solo se aplica
    al satelital: calles conserva 19, que es donde nunca hubo problema.
  - `cambiarCapa` ahora llama a `_recortarZoomAlTope`: si la cámara venía de calles por encima de
    17, al pasar a satelital baja sola hasta el tope en vez de esperar al siguiente gesto.
  - `lib/mapa/vista_mapa.dart`: `MapOptions.maxZoom` y `TileLayer.maxNativeZoom` pasan a leer
    `c.capa.zoomNativo`, en lugar del `maxZoom: 19` fijo y del ternario `satelite ? 18 : 19` que
    causaba el bug. Con `maxNativeZoom: 17` `flutter_map` escala la última tesela real y no pide
    una que el servidor no tiene.
- **Archivos afectados:** `app-movil/lib/mapa/controlador_mapa.dart`,
  `app-movil/lib/mapa/vista_mapa.dart`, `app-movil/test/capa_mapa_test.dart`, `docs/CHANGELOG.md`
- **Verificación:** `flutter analyze` sin incidencias; `flutter test` 26/26 (4 pruebas nuevas en
  `capa_mapa_test.dart`: topes por capa, que ningún tope supere 19 y que `zoomCalle` (17) no quede
  por encima del tope de la capa más restrictiva, para que seguir al conductor no vuelva a pedir
  teselas inexistentes). Queda pendiente la comprobación manual en el dispositivo: satelital sobre
  Cobija acercando hasta el máximo, y confirmar que calles sigue llegando a 19.

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
