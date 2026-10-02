# Proyecto: TaxiUAP

App de transporte tipo Uber/inDrive orientada a estudiantes de Bolivia. Nombre visible: UNITAXI (en
textos, Android, web y correos; los nombres internos del codigo siguen como taxiuap).
Incluye descuentos para estudiantes verificados con comprobante de matricula.
Primera version solo para Android (Play Store).

---

## Stack tecnologico

- Backend:  Spring Boot 4.1.1, Gradle 9.7.1 (Groovy), Java 21, packaging JAR
- Mobile:   Flutter 3.x (Dart), solo Android por ahora
- Admin:    Flutter Web (panel web de administracion, carpeta admin-panel/). Se eligio Flutter en vez de
            Vue para usar un solo lenguaje en todo el frontend
- BD:       PostgreSQL 16 + PostGIS 3.5 en Docker (docker-compose.yml en la raiz, contenedor taxiuap-db,
            puerto 5436 del host), base de datos "taxiuap"
- Tiempo real: WebSocket con STOMP
- Push notifications: Firebase Cloud Messaging (FCM)

**PostGIS: via Docker.** El PostgreSQL 16 local (puerto 5432) no tiene PostGIS, asi que desde
2026-09-23 la BD de desarrollo corre en el contenedor taxiuap-db (imagen postgis/postgis:16-3.5), que
crea la extension sola al inicializar el volumen. Los puertos 5432-5435 los usan clusters locales;
la base taxiuap vieja del 5432 ya no se usa.

## Estructura de carpetas

```
taxiuap/
  backend/          <- Spring Boot (Gradle)
  app-movil/        <- Flutter: una sola app para pasajeros y conductores (Android + web)
  admin-panel/      <- Flutter Web (panel admin)
  docs/             <- diagramas, modelo de datos
  CLAUDE.md
```

## Proyecto de referencia: uniFex

Existe un proyecto anterior (uniFex, Spring Boot 3.5.5, Maven) cuya estructura de
configuracion y seguridad se reutiliza como base.

- Ruta: /home/usic02/Escritorio/SISTEMAS 2026/uniFex
- Carpetas de referencia: src/main/java/com/usic/uniFex/Config/ y src/main/java/com/usic/uniFex/security/
- uniFex es solo referencia: NO modificar ningun archivo de uniFex

Clases de uniFex adaptadas: SecurityConfig (solo la cadena JWT), JwtService, JwtAuthFilter, JwtUser,
RolesSistema (-> RolSistema), WebSocketConfig, AuditoriaConfig (-> AuditoriaConfig + AuditorAwareImpl +
EntidadAuditable), ManejadorErroresApi (-> shared/exception/ManejadorGlobalExcepciones).
Descartadas: cadena web/Thymeleaf, AutenticacionInterceptor, MantenimientoApiFilter, Roles, PantallasSistema,
el sistema de log de errores a archivo, subidas de archivos (CarpetasDeSubidaConfig, TomcatUploadConfig,
WebConfig), HandshakeWebSocketLog, Encriptar, ForwardedHeaderFilter.

---

## Forma de trabajo (orquestador + ejecutor)

- La sesion principal (Opus) analiza, planifica y decide arquitectura.
- La creacion masiva de archivos se delega al agente "executor" (Sonnet), definido en
  .claude/agents/executor.md, con instrucciones precisas: rutas, nombres de clases y contenido esperado.
- Antes de cada modulo nuevo, presentar el plan y esperar aprobacion.
- Trabajar un dominio a la vez. Al terminar cada uno, compilar con ./gradlew build y
  actualizar la seccion "Estado del proyecto" de este archivo.

---

## Convenciones del backend

- Paquete base: com.taxiuap.backend
- Arquitectura en capas: controller -> service -> repository -> entity
- Entidades, repositorios, servicios y DTOs se organizan por dominio: com.taxiuap.backend.<dominio>
- Los controllers se organizan por actor (ver seccion Controllers), no por dominio
- DTOs separados para request y response. Nunca exponer entidades en la API
- Respuestas HTTP estandarizadas con la clase ApiResponse<T> (shared/response)
- Excepciones centralizadas con @RestControllerAdvice (shared/exception/ManejadorGlobalExcepciones)
- Validacion de entrada con Jakarta Validation (@Valid, @NotNull, @Email, etc.)
- Lombok para getters, setters y constructores
- Todo el codigo (clases, metodos, variables, rutas, mensajes) en espanol, igual que uniFex
- Sin emojis en codigo, logs, comentarios, commits, mensajes ni respuestas de API

### Paquetes

```
com.taxiuap.backend.
  config/           <- configuracion general (Async, WebSocket, auditoria, inicializadores)
  config/security/  <- JWT, filtros, SecurityFilterChain, RolSistema, AuditorAware
  controller/       <- controllers REST agrupados por actor
  identity/         <- persona, rol, usuario, pasajero, conductor, administrador, dispositivo
  institution/      <- tipo_institucion, institucion, carrera, estudiante, matricula_estudiante,
                       verificacion_estudiante, tutor_estudiante
  vehicle/          <- tipo_vehiculo, categoria_servicio, vehiculo, documento_conductor
  location/         <- zona, ubicacion_conductor, disponibilidad_conductor, direccion_guardada
  trip/             <- solicitud_viaje, oferta_viaje, viaje, historial_estado_viaje, punto_recorrido
  pricing/          <- tarifa, regla_descuento_estudiantil, descuento, pago, comision, billetera_conductor
  rating/           <- calificacion, etiqueta_calificacion, calificacion_etiqueta,
                       respuesta_calificacion, reporte_comentario
  communication/    <- mensaje, notificacion, contacto_emergencia, alerta_sos, reporte
  shared/           <- ApiResponse, excepciones, EstadoRegistro, utilidades
  seed/             <- carga de datos de prueba (solo perfil xexel)
```

Dentro de cada dominio: entity/, repository/, service/, dto/

### Esquema de base de datos

- El esquema lo genera Hibernate desde las entidades: spring.jpa.hibernate.ddl-auto=update
- NO crear archivos .sql. NO usar Flyway ni Liquibase
- Cada tabla y columna se define en la entidad con @Table y @Column usando exactamente
  los nombres del modelo de datos (snake_case)
- Claves primarias con @GeneratedValue(strategy = GenerationType.IDENTITY)
- Relaciones con @ManyToOne / @OneToOne y @JoinColumn usando el nombre exacto de la FK
- fetch = FetchType.LAZY por defecto en relaciones
- Campos decimal de dinero y calificaciones: BigDecimal con precision y scale definidos
- Campos geography: tipo org.locationtech.jts.geom.Point o Polygon (dependencia hibernate-spatial),
  con @Column(columnDefinition = "geography(Point,4326)") o "geography(Polygon,4326)"
- La extension PostGIS la crea la imagen Docker (ver Stack). Hibernate no debe intentar crearla
- Nunca borrar ni renombrar columnas asumiendo que Hibernate lo hara: ddl-auto=update solo agrega

### Auditoria

- uniFex tenia las anotaciones de auditoria pero nunca activo @EnableJpaAuditing; aqui si esta activa
  (config/AuditoriaConfig).
- Las entidades extienden config/EntidadAuditable (@MappedSuperclass) que agrega las columnas
  creado_en, creado_por, modificado_en, modificado_por. Se llenan solas via AuditingEntityListener.
- AuditorAwareImpl (config/security) toma el idUsuario del JwtUser autenticado; vacio si no hay usuario
  (registro publico, inicializadores).
- Cada entidad conserva su propio estado_<entidad> tal como esta en el modelo (enum EstadoRegistro: A / X).

### Configuracion

- application.properties: configuracion comun, sin credenciales
- Perfil de desarrollo: **xexel** (application-xexel.properties, en .gitignore). Credenciales de la BD
  local tomadas del entorno local existente (usuario postgres). Hay una plantilla versionada
  application-xexel.properties.example
- spring.profiles.active=${SPRING_PROFILES_ACTIVE:xexel}
- Secretos (JWT, admin inicial, FCM) por variables de entorno; valores reales solo en el perfil xexel
- Puerto de desarrollo: 8080

```
# application.properties
spring.application.name=taxiuap
spring.profiles.active=${SPRING_PROFILES_ACTIVE:xexel}
spring.jpa.hibernate.ddl-auto=update
spring.jpa.open-in-view=false
spring.jpa.properties.hibernate.jdbc.time_zone=America/La_Paz
jwt.secret=${JWT_SECRET}
jwt.expiration=${JWT_EXPIRATION_MS:86400000}
jwt.refresh-expiration=${JWT_REFRESH_EXPIRATION_MS:604800000}
admin.inicial.usuario=${ADMIN_USUARIO:admin}
admin.inicial.correo=${ADMIN_CORREO}
admin.inicial.password=${ADMIN_PASSWORD}
cors.origenes=${CORS_ORIGENES:}
taxiuap.seed.habilitado=${SEED_HABILITADO:false}
taxiuap.archivos.directorio=${ARCHIVOS_DIRECTORIO:${user.home}/taxiuap-archivos}
```

El perfil xexel pone taxiuap.seed.habilitado=true.

### Dependencias del backend (build.gradle)

- spring-boot-starter-webmvc (nombre de Boot 4 para starter-web)
- spring-boot-starter-data-jpa
- spring-boot-starter-security
- spring-boot-starter-validation
- spring-boot-starter-websocket
- org.postgresql:postgresql
- org.hibernate.orm:hibernate-spatial
- io.jsonwebtoken (jjwt-api, jjwt-impl, jjwt-jackson) 0.13.0
- lombok
- spring-boot-devtools
- firebase-admin (se agrega cuando se implementen notificaciones)

---

## Seguridad

Basada en Config/ y security/ de uniFex, adaptada:

- Solo una cadena JWT stateless. Sin sesion ni Thymeleaf (uniFex tiene dos cadenas, aqui solo una)
- Sin UserDetailsService: el login (dominio identity) verifica con PasswordEncoder y emite el JWT
- Contrasenas con BCrypt en usuario.password_hash
- Login por nombre de usuario, correo o telefono, con rol opcional en el request. Si la persona tiene cuenta
  de pasajero y de conductor (mismas credenciales) hace falta el rol: cada app envia el suyo y el panel
  admin envia ADMIN. El subject del JWT es el nombre de usuario
- Roles segun rol.codigo (enum config/security/RolSistema): PASAJERO, CONDUCTOR, ADMIN.
  Autoridad Spring: ROLE_<codigo>
- JWT con claim tipo ACCESO / REFRESCO; el filtro solo acepta tokens de ACCESO
- Reglas de acceso:
  - /api/auth/**       publico (registro, login, refresh)
  - /api/publico/**    publico (catalogos: instituciones, carreras, tipos de vehiculo)
  - /api/pasajero/**   rol PASAJERO
  - /api/conductor/**  rol CONDUCTOR
  - /api/admin/**      rol ADMIN
  - /ws/**             WebSocket STOMP; el CONNECT se autentica con el JWT (sin token se rechaza)
- 401/403 responden JSON (ApiResponse) con setStatus, nunca sendError
- CORS configurado para el panel admin en desarrollo (propiedad cors.origenes)
- AdminInitializer (se implementa junto con el dominio identity): crea los roles base desde RolSistema
  y un administrador inicial desde variables de entorno si no existen
- uniFex usa Spring Boot 3.5 / Security 6 y este proyecto Spring Boot 4 / Security 7:
  adaptar las APIs que hayan cambiado, no copiar literalmente

---

## Panel admin (Flutter Web)

- Solo rol ADMIN puede entrar (se valida en el login del panel y en el backend con /api/admin/**)
- Todo responsive: desde 1000 px el menu lateral izquierdo y la barra superior quedan fijos y solo se
  desplaza el contenido; por debajo el menu pasa a un drawer. Los modales ocupan toda la pantalla bajo 600 px
- Menu lateral con grupos desplegables por tipo, definido en un solo lugar: lib/core/menu.dart
- Iconos: estilo iOS desde 2026-10-02 (CupertinoIcons, paquete cupertino_icons), todos en lib/core/iconos.dart
  (clase Iconos, con los nombres que tenian en Font Awesome); motos con Icons.two_wheeler_rounded (iOS no trae).
  Se usan con Icon(Iconos.x). Ya no hay font_awesome_flutter en el panel. Nunca emojis
- Colores del diseno de referencia: azul #0B2341, rojo #B71234 (lib/core/tema.dart)
- Menu retractil: el boton de tres lineas de la barra superior esconde/muestra el menu al instante en
  escritorio (se recuerda la preferencia) y abre el drawer en pantallas angostas
- Toda lista usa el mismo widget: ListadoRemoto -> TablaDatos (lib/widgets/). Las columnas se definen con
  ColumnaTabla y su TipoColumna (texto, numero, fecha, fechaHora, estado), que decide el filtro, el orden y
  la exportacion. La busqueda, los filtros y la exportacion trabajan sobre la lista ya cargada
- Estilo de tabla unico (tipo DataTables Responsive): encabezado azul marino con texto blanco, bordes entre
  celdas, filas blancas / gris claro con texto oscuro, exportar Excel | CSV | PDF en botones agrupados.
  Nunca se corta: las columnas se reparten el ancho (ColumnaTabla.ancho = minimo, proporcion = flex; el
  minimo nunca es menor que el titulo). Primera columna "N°" (1..N sobre la lista filtrada y ordenada).
  Si no entran todas las columnas, se ocultan las de la derecha; el ojo (primer boton de Acciones) abre un
  modal con todos los datos del registro. La columna de acciones siempre se ve.
- Celdas de una sola linea (maxLines 1, "...", el texto completo en un Tooltip y en el ojo): ninguna fila
  crece hacia abajo. Bajo 560 px de ancho la tabla es compacta (columna N° de 42 px, menos relleno y botones
  de acciones de 34 px en una sola fila, achicados si no entran)
- Rendimiento de la tabla: las filas no usan IntrinsicHeight (las lineas verticales se dibujan una vez
  sobre el cuerpo) y el menu lateral se muestra/esconde sin animar el ancho (animarlo re-media la tabla
  en cada cuadro). En modo debug (flutter run) todo es mas lento que en el build release
  Orden: menu "Ordenar" con textos segun el tipo (De la A a la Z / Z a A, Mas reciente / Mas antiguo
  primero, Menor / Mayor) o clic en el encabezado. Toda lista con fechas debe incluir su columna de fecha
  (por ejemplo Registrado) para poder ordenar por antiguedad
- En textos de la interfaz no usar flechas ni simbolos especiales (→): el panel no carga fuentes de
  internet y esos glifos salen como cuadros vacios
- La columna de estado (A/X) no se muestra: los listados solo traen registros en A
- Altas y ediciones en modal: ModalFormulario + abrirModal (lib/widgets/modal_formulario.dart)
- Flujos estandar (lib/widgets/flujos_crud.dart) con los modales de lib/widgets/dialogos.dart:
  modales animados (circulo dibujado en 0,4 s y luego check / signo de pregunta / X), estilo de la
  referencia del usuario. crear -> formulario -> modal verde; editar -> confirmacion naranja -> formulario -> modal verde;
  eliminar -> confirmacion naranja -> borrado logico -> modal rojo. Toda pantalla nueva usa estos flujos
- Cada modulo en lib/modulos/<grupo>/: modelos.dart, <grupo>_api.dart y una pantalla por opcion del menu
- Cuentas (Usuarios, Pasajeros, Conductores): suspender / habilitar y eliminar con
  lib/modulos/personas/acciones_cuenta.dart (flujoAccion y flujoEliminar). Suspender = estado_usuario S
  (EstadoRegistro A / X / S; S solo se usa en usuario): no puede ingresar (login, Google, refresh) y
  JwtAuthFilter corta la sesion abierta en su siguiente peticion con el motivo (401); la app vuelve al
  login mostrandolo. No se suspende ni elimina a quien tiene un viaje o solicitud en curso ni la propia
  cuenta. La suspension del conductor como operador sigue siendo su situacion_aprobacion

---

## App movil (app-movil): pasajeros y conductores en una sola app

- Un solo login para todos (mismo diseno que el login del panel: marca a la izquierda desde 900 px, arriba
  en el celular; el formulario nunca pasa de 420-460 px). POST /api/auth/cuentas dice que cuentas tiene la
  persona. Solo pasajero -> vista del pasajero; solo conductor -> vista del conductor; varias -> hoja
  "¿Como quieres ingresar?" (incluye Administrador). ADMIN desde /app en el navegador: la app deja la
  sesion en las claves del panel (taxiuap_token_*) y abre /admin en la misma pestana; en el APK, aviso.
  La app guarda su sesion en claves propias (taxiuap_app_*) para no pisar la del panel (mismo origen).
  En el APK el ADMIN tambien entra: la app abre el panel del servidor dentro de si misma
  (lib/modulos/login/panel_admin_movil.dart, webview_flutter) escribiendo antes los tokens en las
  claves del panel; boton Salir vuelve al login (Sesion.panelAdmin, no se guarda)
  En Mas, "Cambiar a modo conductor/pasajero" (POST /api/cuenta/cambiar-rol, sin pedir contrasena),
  bloqueado con una solicitud o viaje en curso
- Diseno de las dos vistas (referencia del usuario, app "Karona", en azul/rojo TaxiUAP). Desde 2026-09-30 la
  pantalla principal tiene estilo Uber: fuente Inter incluida (assets/fuentes, fontFamily del tema), cabecera
  blanca con foto redonda, "Hola, Nombre" en negrita negra, direccion en gris y boton de ayuda gris;
  pildora "¿A donde vas?" debajo de la cabecera; iconos y textos negros
  (ColoresApp.tinta / gris / grisTexto); barra inferior sin fondos de color; boton de pedir en negro; barra inferior flotante
  (lib/widgets/barra_inferior.dart) con boton central; secciones con PaginaSeccion
  (lib/widgets/pagina_seccion.dart). Sin menu lateral. Pasajero: Inicio | Actividad | (pedir taxi) | Perfil.
  Conductor: Inicio | Actividad | (conectarse/desconectarse) | Opiniones | Perfil. Desde 2026-10-02 la barra
  es estilo iOS 26 (capsula blanca translucida con desenfoque, CupertinoIcons de linea y relleno el activo,
  activo en azul marino ColoresApp.azul sobre una pastilla clara); "Mas" paso a llamarse "Perfil" (icono de
  cuenta) e "Historial" a "Actividad" (pestanas Viajes | Favoritos). Las tarjetas de Perfil (TarjetaOpcion)
  van como Ajustes de iOS: icono blanco en cuadro de color, titulo negro, CupertinoSwitch
- Pantalla Mas comun (lib/comun/pantalla_mas.dart): datos personales, mis documentos (conductor), cambiar
  de modo, politicas y terminos (textos de ejemplo en lib/comun/textos_legales.dart), cambiar contrasena
  (actual + nueva + confirmar; pantalla completa bajo 600 px, modal en web; POST /api/cuenta/contrasena
  cambia juntas las de pasajero y conductor), ingreso con huella (local_auth, solo APK Android; guarda las
  credenciales cifradas; MainActivity es FlutterFragmentActivity), cerrar sesion y version
- Codigo: lib/modulos/pasajero/, lib/modulos/conductor/, lib/modulos/login/, lib/comun/ (modelos del
  viaje, perfil), y lo compartido en lib/core, lib/mapa, lib/widgets. Paquete Android com.taxiuap.movil
- Flutter con plataformas android + web
- Paleta del diseno de referencia del pasajero (lib/core/tema.dart): azul marino #0A2342, rojo #D32F2F
  (hover #B71C1C), fondo #F4F6F8, texto #2C3E50 / #7F8C8D, borde #E0E0E0; ruta en azul #1A73E8
- Login con rol fijo por app (Config.rol: PASAJERO o CONDUCTOR); sesion y cliente copiados del panel
- Mapa: flutter_map + OpenStreetMap. Rutas por calles con OSRM publico (router.project-osrm.org); si no
  responde, linea recta punteada. Direcciones con Nominatim (reverse). GPS en vivo con geolocator
- Tiempo real por consulta periodica (pasajero 3 s, conductor 4-5 s); STOMP queda para despues
- Pasajero: A = ubicacion GPS al iniciar sesion (el mapa se centra en ella, zoom 17); B se marca tocando el
  mapa o con el buscador "¿A donde quieres ir?" (Nominatim search alrededor de Cobija + favoritos); ve
  ruta, tiempo y precio fijo; "Solicitar taxi" o el boton central ->
  "Buscando conductor" -> conductor asignado (nombre, estrellas, vehiculo, placa, estado) con su punto
  GPS moviendose -> al COMPLETADO, pantalla de calificacion tipo Uber (estrellas, etiquetas segun la
  nota, comentario). Al abrir la app retoma solicitud, viaje o calificacion pendiente (ultimas 2 h)
- Buscador de destino: solo lugares de Cobija (Nominatim con bounded=1 y caja fija de la ciudad, mas filtro
  en la app), ordenados por cercania
- Pasajero: partida y destino como circulos sin letra (azul A, rojo B; MapaBase.puntosSinLetra). Con la
  partida marcada y eligiendo destino, sus favoritos aparecen en el mapa (estrella y nombre); tocar uno
  lo pone como destino. A la derecha solo el boton Moto (Auto oculto por ahora)
- Pasajero: los mototaxis libres en linea (assets/mototaxi.png, tamano fijo) se ven siempre mientras elige
  o espera y se deslizan entre consultas (lib/mapa/posiciones_animadas.dart). Selector Moto (activo) /
  Auto ("Pronto") a la derecha con el numero de mototaxis libres; se esconde cuando hay panel abierto.
  Boton de capas del mapa (calles OSM, satelite Esri, claro Carto)
- Cerrar sesion desde Mas (las dos vistas)
- Conductor: envia su GPS por STOMP (/app/conductor/ubicacion, lib/core/emisor_ubicacion.dart) con
  disponibilidad DISPONIBLE / OCUPADO (en viaje) / DESCONECTADO (al cerrar sesion); latido cada 30 s
- Conductor: sin selector Moto/Auto (solo el pasajero lo ve). El panel "Solicitudes de viaje" es desplegable:
  cerrado solo la barra con el contador y una flecha; abierto, la lista (FlujoConductor.listaAbierta).
  El numero rojo (panel y Inicio de la barra) = solicitudes disponibles que el conductor no vio: baja si
  otro las toma y se limpia al desplegar la lista (con Inicio a la vista)
- Conductor que cancela un viaje: la solicitud queda CANCELADA y se publica una copia PENDIENTE para otro
  conductor (id_sol_viaje es unico en viaje); el que cancelo recibe una oferta RECHAZADA en la copia, asi
  no la ve ni la puede tomar (409). La app del pasajero vuelve sola a "Buscando conductor". El conductor
  tampoco ve el pedido de su propia persona como pasajero
- Conductor: lista de solicitudes (las mas recientes primero); al tocar una ve la ruta A-B en azul y el tramo gris desde su GPS
  hasta A, el precio y su ganancia (precio menos comision); "Aceptar viaje" -> Voy en camino -> Llegue
  -> Iniciar -> Finalizar (cobro en efectivo). Se finaliza solo si su GPS queda a 50 m o menos de B.
  Secciones Historial (con la ruta en el mapa; lib/comun/historial_viajes.dart, la misma del pasajero)
  y Opiniones (promedio y lista). Boton central conectarse/desconectarse: desconectado no consulta
  solicitudes ni envia su GPS (avisa DESCONECTADO). En la ruta de una solicitud la cabecera muestra una
  flecha para volver (y el boton atras de Android)
- API_URL por --dart-define; sin ella: en web release el mismo servidor que la sirve (/app), con
  flutter run en web localhost:8080, en el emulador Android 10.0.2.2:8080

### Pago en efectivo o QR
- qr_pago_conductor (pricing): de 0 a 3 imagenes del QR de banca movil del conductor, sin texto. El
  conductor las agrega/cambia/quita cuando quiere (Mas > Mis QR de cobro, /api/conductor/qr), tambien
  opcionales en el registro (partes QR1..QR3 del multipart). Se guardan como PNG (ProcesadorImagen.imagenQr,
  sin recortar, max 1200 px) en personas/<id>_<ci>/conductor/qr/. El admin las ve, descarga y elimina en el
  expediente (pestana "QR de cobro", /api/admin/conductores/{id}/qr)
- El pasajero elige Efectivo | QR antes de solicitar (solicitud_viaje.metodo_pago, se copia a
  viaje.metodo_pago). Pagando por QR ve los QR del conductor debajo del viaje y los descarga (web: archivo;
  APK: galeria con el paquete gal). Luego el pasajero no cambia el metodo: lo pide
  (POST /api/pasajero/viajes/{id}/metodo-pago -> viaje.metodo_pago_pedido) y el conductor acepta o rechaza
  (dialogo al consultar, POST .../metodo-pago/respuesta). El conductor lo cambia directo con PUT
  /api/conductor/viajes/{id}/metodo-pago. A QR solo si el conductor tiene QR
- Finalizar usa el metodo vigente del viaje. QR y efectivo van directo al conductor: pago COMPLETADO
- Comision en 0 por ahora (taxiuap.comision.porcentaje=${COMISION_PORCENTAJE:0}): todo el pago es del conductor

### Backend del flujo movil
- Precio fijo: taxiuap.viaje.precio-fijo=8.00 (vacio = tarifa por distancia). Descuento estudiantil
  apagado con taxiuap.descuento-estudiantil.habilitado=false mientras el precio sea fijo
- GET /api/pasajero/solicitudes/precio y GET /api/conductor/precio (precio, moneda, comision)
- POST /api/conductor/solicitudes/{id}/aceptar: aceptacion directa estilo Uber con el UPDATE
  condicional de la regla 5 (409 si otro conductor la tomo); registra la oferta ya ACEPTADA
- La solicitud sin idCategoriaServicio usa ESTANDAR; no se puede pedir otra con un viaje activo
- POST /api/pasajero/viajes/{id}/calificacion (regla 10) y GET /api/conductor/calificaciones. El
  promedio del conductor se recalcula con todas sus calificaciones activas
- ViajeResponse incluye marca, modelo, color, calificacionConductor y calificadoPorPasajero
- Al finalizar el viaje la solicitud pasa a situacion FINALIZADA; al cancelar el viaje, a CANCELADA
- GET /api/pasajero/conductores-en-linea: conductores DISPONIBLE que reportaron GPS hace menos de
  taxiuap.conductores.segundos-en-linea (120 s). Solo posicion, sin datos personales
- Mapa "Conductores en vivo" del panel: filtros con iconos arriba (Todos / Disponibles / Ocupados /
  Desconectados, con contador), marcadores de moto que se deslizan entre reportes del topic, "sin senal"
  a los 75 s (la app reporta cada 30 s quieta). Si llega un conductor que no estaba en la lista, se recarga
- El simulador del panel (admin-panel/tool/simulador_conductores.dart) lee la URL con
  dart run -DAPI_URL=http://host:puerto (no con variable de entorno)
- config/SecuenciasInitializer: al arrancar deja cada secuencia de PK en el ultimo id existente (tabla vacia:
  vuelve a 1), asi tras un borrado fisico el siguiente registro es el correlativo. Los huecos del medio no
  se tocan (el 2026-10-01 se compactaron a mano personas y cuentas)
- config/RestriccionesEnumInitializer: al arrancar actualiza los CHECK de las columnas enum si al enum
  de Java se le agrego un valor (ddl-auto=update no lo hace). No crea restricciones nuevas

---

## Usuarios, eliminacion permanente y terminos (2026-10-02)

- Usuarios del panel: columna Situacion = HABILITADO / PENDIENTE (conductor en revision) / OBSERVADO (carnet) /
  RECHAZADO / SUSPENDIDO (UsuarioAdminResponse.situacion, GestionUsuarioService.situacion), con su filtro.
  Editar (formulario_editar_usuario.dart): datos de la persona hasta el correo, nombre de usuario (en sus dos
  cuentas de la app), fotos del carnet y, si es conductor, licencia con fotos; todo junto en
  PUT /api/admin/usuarios/{id}/datos (multipart datos + carnetAnverso/carnetReverso/licenciaAnverso/
  licenciaReverso; EdicionUsuarioAdminService). GET .../{id}/detalle. Si cambia el correo se avisa al anterior
- "Enviar credenciales" (POST /api/admin/usuarios/{id}/credenciales): las contrasenas son BCrypt, asi que se
  genera una nueva (vale para pasajero y conductor) y se envia con el usuario al correo actual
  (CredencialesCorreoService.reenviar). No con cuenta suspendida, carnet observado ni conductor sin aprobar
- Personas > Eliminacion permanente (EliminacionPermanenteService, /api/admin/eliminacion-permanente):
  excepcion a la regla 11 pedida por el usuario. Borra fisicamente la persona, sus cuentas y todo lo solo
  suyo (solicitudes sin viaje, ofertas, mensajes, notificaciones, dispositivos, favoritos, contactos,
  reportes, SOS, documentos, QR, permisos, billetera, ubicacion, moto, estudiante) y su carpeta (despues del
  commit). Los viajes con otra persona y sus calificaciones se CONSERVAN pasando al registro fijo "USUARIO
  ELIMINADO" (id 0 en persona, usuario, pasajero y conductor, estado X); la moto que usan esos viajes queda
  con placa E<id>-<placa> (la placa es unica). Bloqueado si tiene cuenta ADMIN, viaje/solicitud en curso o
  es uno mismo. Panel: resumen -> confirmacion naranja -> escribir el correo -> modal rojo. Al final
  SecuenciasInitializer.ajustar() (ignora ids <= 0)
- Terminos y condiciones (app lib/comun/aceptar_terminos.dart, texto de prueba UAP/mototaxi en
  textos_legales.dart): modal vertical con casilla y Aceptar despues de "Confirma tus datos" (tambien con
  Observado) en verificar carnet / registro de pasajero con Google, y al final del registro de conductor.
  Los requests llevan aceptaTerminos: true; CarnetService.revisar lo exige (422) y guarda
  persona.fecha_acepta_terminos
- Barra de las apps: "Mas" es "Perfil" (Perfil > ... en los textos) e "Historial" es "Actividad"
- Sonido (2026-10-02): assets/sonidos/viaje_aceptado.mp3 suena UNA vez solo cuando un conductor acepta el
  viaje (AvisoViaje conSonido; minimizada o con push VIAJE_ACEPTADO el canal aviso_viaje_* con res/raw);
  "Tu conductor llego" solo vibra y usa el sonido del telefono (canal aviso_viaje_tel_*)

## Registro publico y Google

- Login de la app: "Continuar con Google" primero pregunta "¿Como quieres ingresar?" (Pasajero / Conductor)
  y usa ese modo: pasajero entra directo (si no tenia cuenta se registra); conductor entra si ya lo es o
  llena el formulario de conductor antes de entrar. El modo INGRESO del backend queda sin uso en la app.
  "Registrate" en lib/modulos/registro/
- Pasajero: se registra SOLO con Google. Desde 2026-10-01 elegir la cuenta de Google NO guarda nada si la
  persona no tiene carnet: el backend responde codigoRegistroPasajero (web: ?google_pasajero=) y la app
  abre PantallaVerificarCarnet(codigoGoogle). Al confirmar, POST /api/auth/registro/pasajero/google
  (multipart datos/anverso/reverso) crea persona, carnet y cuenta en UNA transaccion y recien ahi sale el
  correo; "Cancelar registro" o un fallo no dejan nada (los archivos nuevos se borran si la transaccion
  se deshace: AlmacenamientoArchivos.escribir). nombre_usuario = parte del correo
  antes de la @ (con numero si esta ocupado). La foto de Google se guarda como foto de perfil
- Conductor: con Google (nombre y correo de Google; sin usuario ni contrasena) o con el formulario
  (datos, usuario, contrasena). En los dos: CI, telefono, licencia, moto y PDF CI y LICENCIA (SOAT
  opcional). Queda PENDIENTE; en la app ve "Cuenta en revision" (sin solicitudes ni GPS) y el boton
  "Ver si ya me aprobaron". El admin lo aprueba con PUT /api/admin/conductores/{id}/situacion
- Si la persona (mismo correo) ya tiene la otra cuenta de la app, la nueva reutiliza su nombre de usuario
  y contrasena (regla 12)
- Conductor habilitado = situacion_aprobacion APROBADO. Mientras no lo este y la persona tambien sea
  pasajero: /api/auth/cuentas no lo ofrece (entra directo como pasajero), rolesDisponibles no lo incluye,
  cambiar-rol a CONDUCTOR responde 422 y Google con modo CONDUCTOR entra como pasajero con un aviso. Con
  los dos habilitados el login pregunta con cual ingresar
- Pasajero que quiere ser conductor: Mas > "Registrarme como conductor" abre el formulario en modal
  (desdePasajero, precargado) -> GET/POST /api/pasajero/registro-conductor (RegistroConductorPasajeroService:
  crea la cuenta de conductor con el mismo usuario y contrasena, moto, PDF y QR; queda PENDIENTE). En Mas
  se ve "en revision" / "rechazado"; al aprobarlo aparece "Cambiar a modo conductor"
- Flujo: GET /api/auth/google?modo=INGRESO|PASAJERO|CONDUCTOR&volver=<url de la app> -> Google ->
  /api/auth/google/callback -> redirige a volver con ?google=<codigo> (POST /api/auth/google/canje, un
  solo uso, 2 min), ?google_registro=<codigo> (formulario de conductor; GET /api/auth/google/registro/{c}
  y POST /api/auth/registro/conductor/google, multipart) o ?google_error=<mensaje>. Los JWT nunca van en la
  URL; el state se valida (IngresoGoogleTemporal, en memoria). volver solo puede ser el origen de
  google.redirect-uri o uno de cors.origenes
- POST /api/auth/registro/conductor (formulario) es multipart: parte "datos" + un PDF por tipo
- En el APK (Google no acepta volver a http://IP-de-la-red): google_sign_in nativo (lib/core/google_movil.dart,
  lib/modulos/registro/ingreso_google.dart). La app pide GET /api/auth/google/config (client id web, usado
  como serverClientId), obtiene el id_token y lo manda a POST /api/auth/google/movil {idToken, modo}; el
  backend lo verifica con tokeninfo (aud = client id, correo verificado) y responde la sesion o el
  codigoRegistro. En Google Cloud existe el cliente OAuth Android "Unitaxi" (com.taxiuap.movil + SHA-1 de
  ~/.android/debug.keystore); otra llave de firma necesita su SHA-1 ahi
- Conductor nuevo con Google en el APK: el formulario se abre en un modal (pantalla completa bajo 600 px),
  precargado con CI, complemento, telefono y fecha si la persona ya existia; fecha de nacimiento obligatoria
  (Google no la entrega). El pasajero con Google no da CI ni telefono
- Para probar sin Google real: google.auth-url, google.token-url, google.userinfo-url y
  google.tokeninfo-url se pueden apuntar a un servidor falso
- APK: flutter build apk --release --dart-define=API_URL=http://IP-del-PC:8080. La red no tiene IPv6: si
  Gradle falla al descargar, anteponer JAVA_TOOL_OPTIONS="-Djava.net.preferIPv4Stack=true"

## Carnet, licencia y confirmacion de cambios (2026-09-30)

- Registro de conductor desde la app (formulario, Google y desde pasajero): el carnet y la licencia van
  como FOTOS (partes CARNET_ANVERSO/REVERSO y LICENCIA_ANVERSO/REVERSO), ya no PDF de CI ni de LICENCIA;
  en PDF solo el SOAT, opcional. Si la persona ya registro su carnet (CarnetService.tieneCarnet) no se
  vuelve a pedir y se conservan su CI, complemento y fecha (tieneCarnet en PerfilGoogleResponse y
  RegistroConductorEstadoResponse)
- Licencia (identity/service/LicenciaService): fotos en personas/<id>_<ci>/conductor/licencia/, columnas
  conductor.licencia_anverso_url / licencia_reverso_url / licencia_vencimiento. En el registro: categoria
  M (solo motos por ahora), vigente y numero igual al CI. Categorias P, M, A, B, C (una letra)
- App: lib/core/carnet/lectura_licencia.dart (con tests, datos inventados) lee numero, categoria,
  vencimiento y la linea "NOMBRES, APELLIDOS" en cualquier rotacion; SelectorCarnet sirve para los dos
  documentos (DocumentoFoto). El nombre de la licencia debe coincidir con el de la persona y con el
  texto del carnet (tolera tildes, Ñ/N y una letra mal leida). Lo leido (CI, fecha, numero, categoria,
  vencimiento) queda bloqueado; el complemento solo se escribe si lo tiene (2 caracteres con un
  numero: PDO, LP no son complemento). Se confirma "Tu numero de carnet / licencia es: ..."
- Nombre desde el carnet (2026-10-01): el nombre de la persona es el del carnet, no el de Google (puede ser
  un apodo; el correo solo sirve para las credenciales). DatosCarnet.nombres/apellidos se leen de la MRZ del
  reverso (PEREZ<MAMANI<<JUAN), si no de las etiquetas NOMBRES/APELLIDOS del anverso, y en el carnet antiguo
  de la linea "A: ..."; las tildes se toman del texto impreso. En el APK los campos son de solo lectura,
  salvo cuando el corte no es seguro (DatosCarnet.nombreSeguro false): carnet antiguo (se proponen los dos
  ultimos como apellidos y la persona acomoda nombres y apellidos) o MRZ cortada sin etiquetas legibles
  (apellidos fijos, nombres se completan). revisarNombreEscrito exige las mismas palabras del carnet en el
  mismo orden (con MRZ cortada, que los nombres empiecen como los leidos). En la web se escriben. Viajan como nombres/apellidos en CarnetRequest,
  RegistroConductorGoogleRequest y RegistroConductorPasajeroRequest (ReglasRegistro.nombreOActual)
- Confirmacion del carnet y la licencia (2026-10-01): al enviar el carnet (verificar_carnet del pasajero con
  Google, registro de conductor y cambio de fotos) sale el modal "Confirma tus datos: Tu nombre completo es / Tu numero de carnet es
  6565204-1B" (confirmarDatosCarnet). El conductor confirma despues "Confirma que tu numero de licencia es".
  Con "No" se vacian las fotos y lo leido (el SelectorCarnet se recrea con otra key) y se vuelven a tomar.
  En el APK el complemento no se escribe: se lee del carnet (N° 6565204-1B o el numero suelto con guion) o,
  si el carnet no lo mostro, de la licencia. Licencia = CI con su complemento (DatosLicencia.complemento,
  numeroCompleto); el backend compara numero y complemento (LicenciaService.validarDatos). En la web se
  escriben a mano, con las fotos adjuntas obligatorias. Fotos nuevas de carnet o licencia borran las
  anteriores despues del commit (AlmacenamientoArchivos.reemplazarConSello); los PDF siguen conservandose
- Nombres en MAYUSCULAS (2026-10-01): Persona.setNombres/setApellidos los guardan en mayusculas (del carnet,
  del formulario, del admin o de Google) y config/NombresMayusculasInitializer pasa los guardados antes. En la
  app Formatos.letras (nombres, apellidos, color) escribe en mayusculas y lo precargado de Google se pasa a
  mayusculas; el lector del carnet devuelve "AXEL RAUL" (con tildes si se leyeron). Panel: MayusculasFormatter
  en lib/core/formato.dart. Los saludos usan enTitulo (Hola, Axel)
- Microletra del carnet antiguo (2026-10-01): el fondo ("ESTADOPLURINACIONALDEBOLIVIA" repetido) y el borde
  salen leidos como palabras ("ONALDEOLIVIAE URINAIONALC"). lectura_carnet los reconoce con distancia de
  edicion contra ese texto (_esDelFondo), los quita de las puntas de la fila y, entre las lineas junto a "A:"
  y "Nacido el", elige la primera con menos texto de fondo. El nombre va despues de "...e impresion pertenece
  A:" (tambien sirve de ancla)
- Licencia (2026-10-01): bajo "Nombres, Apellidos" va el titular con una coma entre nombres y apellidos
  ("JUAN CARLOS, PEREZ" y a veces el segundo apellido en la linea de abajo); la etiqueta, que tambien lleva
  coma, se descarta. DatosLicencia.nombres/apellidos guardan el corte y, en el registro de conductor,
  cortarConLicencia separa con eso el nombre del carnet antiguo (queda seguro, sin acomodar a mano). El numero
  de licencia (debajo de la foto) es el del CI: extraerDatosLicencia(ci:) lo elige si se leyo en la licencia
- Editor de foto (2026-10-01, lib/comun/editor_foto.dart, enderezarFoto): cada foto del carnet o la licencia,
  antes de leerla, se abre a pantalla completa para girarla de a 90 grados (y acercarla con dos dedos). Con el
  telefono sobre la mesa la camara la guarda de costado. Devuelve la foto girada con el EXIF ya aplicado
  (el servidor la reprocesa con ImageIO, que ignora el EXIF). Tocar una foto ya elegida ofrece "Girar esta foto"
- Formatos (identity/dto/ReglasRegistro, app lib/widgets/formatos.dart): celular del conductor 8 digitos
  que empiezan con 6 o 7; marca solo letras en mayusculas; modelo alfanumerico; color solo letras
- Todo cambio de datos se confirma con la contrasena de la cuenta; en la app primero la huella si esta
  activa (lib/comun/confirmar_identidad.dart). PUT /api/cuenta/datos lleva password (ya no hay codigo
  por correo), tambien el reemplazo de PDF con permiso y las fotos. Permisos nuevos CARNET y LICENCIA
  (volver a tomar las fotos: PUT /api/conductor/carnet y /api/conductor/licencia). El admin ve y cambia
  las fotos en el expediente (Ver carnet / Ver licencia, Editar licencia; PUT
  /api/admin/usuarios/{id}/carnet y /api/admin/conductores/{id}/licencia)
- usuario.aviso_credenciales: se pone en true al enviar un correo con credenciales; la pantalla
  principal (pasajero y conductor) muestra "Revisa tu correo" una vez (POST /api/cuenta/aviso-credenciales)
- El conductor en revision consulta su perfil cada 15 s y pasa solo a recibir solicitudes al aprobarlo;
  el pasajero con registro de conductor pendiente consulta cada 20 s y al aprobarlo se le ofrece
  cambiar a modo conductor
- GPS: RequiereGps pide el permiso despues del primer cuadro de la pantalla principal (no sobre el login);
  ServiciosMapa ya no pide permiso y ControladorMapa.iniciarGps espera a RequiereGps.listo
- Red: lib/core/conexion.dart (connectivity_plus) y franja roja "Sin conexion" en toda la app; en el login
  avisos de internet lento a los 20 s y muy lento a los 40 s (el login espera hasta 60 s)
- Pasajero: TarjetaMoto con marca, modelo, color y placa en el panel del viaje
- Sonido y vibracion del pasajero (lib/core/aviso_viaje.dart). Desde 2026-10-01 el sonido propio (la moto)
  esta apagado (Sonido.activo = false): con la app abierta solo vibra y minimizada la notificacion usa el
  sonido del telefono (canales aviso_viaje_tel_*). La vibracion son dos pulsos de 350 ms marcados como
  USAGE_NOTIFICATION (sin eso Android la tomaba como toque de teclado y la descartaba con la vibracion
  al tocar apagada). Con el sonido activo: al aceptar el viaje y al llegar el
  conductor suena assets/sonidos/viaje_aceptado.mp3 UNA vez (copia en android res/raw, keep.xml para R8;
  MainActivity canal unitaxi/vibracion: "sonar" con MediaPlayer como sonido de notificacion, respeta el
  modo silencio, y "vibrar") junto con la vibracion corta; al finalizar solo vibra. Minimizada sale la
  notificacion "Tu viaje fue aceptado" / "Tu conductor llego" con el mismo sonido (canales aviso_viaje_*
  segun la configuracion: el sonido de un canal Android no cambia despues de creado)
- Android 14 congela la app minimizada a los pocos segundos: mientras el pasajero busca o esta en viaje,
  y mientras el conductor esta conectado o en viaje, corre un servicio en primer plano (ForegroundService
  de flutter_local_notifications, tipos dataSync|location, notificacion fija, Notificador.seguirViaje /
  dejarDeSeguir en fila para no pisarse al cambiar de modo)
- Mas > Sonido y vibracion (lib/comun/configuracion_avisos.dart, PreferenciasAviso en el telefono): dos
  interruptores separados y "Probar aviso". Tambien aplican a la notificacion de solicitudes del conductor
- Al abrir la app se recupera primero la solicitud o el viaje en curso (el precio en paralelo); sin
  conexion se reintenta cada 3 s mostrando PanelRecuperando en vez de caer a "elegir destino"
- Push con la app cerrada (FCM, proyecto Firebase unitaxi-6febf): app-movil/android/app/google-services.json
  y la llave de cuenta de servicio en taxiuap-secretos/ (los dos ignorados por git; el repo es publico).
  .env: FIREBASE_CREDENCIALES="ruta" (con comillas por el espacio de "SISTEMAS 2026"; bootRun las quita);
  sin la variable el backend busca el JSON en ../taxiuap-secretos. communication/service/
  NotificacionPushService (firebase-admin 9.4.3 con NetHttpTransport: con el httpclient5 de Boot 4 fallaba
  "Not in GZIP format") envia mensajes de DATOS despues del commit: VIAJE_ACEPTADO (ViajeService.
  crearDesdeOferta) y CONDUCTOR_LLEGO (llegue). Tokens en dispositivo (POST /api/cuenta/dispositivo y
  /baja al cerrar sesion; UNREGISTERED -> X). App: lib/core/push.dart (Push.preparar en main,
  Push.registrar al abrir el inicio; mensajeEnSegundoPlano arma la notificacion). La notificacion usa
  idNotificacionViaje(idViaje, evento), la misma que la app abierta: si llegan las dos, suena una vez.
  Probado en el emulador con la app cerrada (proceso muerto)
- Concurrencia (probado con 5 pasajeros y 5 conductores a la vez): la solicitud se toma con el UPDATE
  condicional (un solo ganador, 409 el resto); ademas se bloquea la fila del conductor al aceptar
  (ConductorRepository.bloquear, SELECT FOR UPDATE: no puede quedar con dos viajes) y la del pasajero al
  pedir (PasajeroRepository.bloquear: el doble toque no crea dos solicitudes)

## Lectura de carnet y licencia con Gemini (2026-10-01)

- Cada foto del carnet y de la licencia (registro de pasajero con Google, de conductor, verificar carnet y
  cambio de fotos) se lee en el SERVIDOR con Gemini: POST /api/auth/documentos/leer (multipart foto +
  documento CARNET|LICENCIA + lado ANVERSO|REVERSO; publico, limite por IP taxiuap.gemini.lecturas-por-hora).
  shared/ia/ClienteGemini (REST generateContent, JSON con esquema fijo, temperatura 0) e
  identity/service/LecturaDocumentoService; instrucciones en resources/gemini/lectura_documento.txt (formatos:
  carnet nuevo con MRZ, carnet antiguo "pertenece A:", licencia con coma en "Nombres, Apellidos"; sin datos
  reales). Modelo gemini-flash-latest (alias del Flash mas nuevo). El Flash nuevo suele responder 503 "high
  demand": ClienteGemini prueba entonces los Flash estables anteriores (lista de la API) y siempre como
  ultimo intento gemini-flash-lite-latest (maximo 4 modelos por lectura, 25 s cada uno); el modelo saturado
  se salta 2 min y el que da 404 (gemini-2.5-flash ya no existe para cuentas nuevas) 12 h. Probado con las
  fotos reales del usuario: carnet antiguo, carnet nuevo, licencia y una captura que no es documento
- La llave va SOLO en el servidor: GEMINI_API_KEY en .env (taxiuap.gemini.api-key). Nunca en la app
- LecturaDocumentoResponse: disponible=false (sin llave, cuota, red, 403) -> el APK lee con ML Kit
  (respaldo) y la web pasa a datos escritos a mano (LectorDocumentos.puedeLeer en la app). aceptada=false
  -> motivo (otro lado, otro documento, borrosa)
- Cada lectura aceptada queda en memoria 3 h con la huella SHA-256 de la foto. Al registrar, FotosCarnet y
  FotosLicencia llevan la huella de lo subido: si el servidor leyo esas fotos, CI, complemento, fecha y
  nombre deben ser los leidos (verificarCarnet / verificarLicencia, 422 si no). El conductor queda APROBADO
  solo si la licencia leida por el servidor es M, vigente, numero = CI y el mismo nombre del carnet
  (licenciaCoincide); el flag licenciaVerificada de la app ya no se usa. Con ML Kit queda PENDIENTE
- App: lib/core/carnet/lector_documentos.dart (LecturaFoto, datosCarnetDeLecturas, datosLicenciaDeLecturas).
  SelectorCarnet lee en el servidor, si no puede usa ML Kit para las dos fotos (_soloTelefono). Los datos
  leidos quedan bloqueados. Carnet antiguo (un solo renglon): Gemini propone el corte nombres/apellidos
  (dos ultimos = apellidos, DE/DEL/DE LA con el apellido; el backend lo descarta si no son las mismas
  palabras de nombreCompleto) y la app lo muestra completo y bloqueado, sin el aviso de acomodar
  (DatosCarnet.corteSugerido); en el registro de conductor la coma de la licencia lo corrige si difiere.
  Solo sin propuesta se acomoda a mano. Lupa en cada foto y "Ver la foto" para verla en grande (verFoto); los modales "Confirma tus
  datos" y "Confirma tu licencia" muestran las fotos leidas. Icono del reverso: tarjeta sin foto (creditCard)
- Editor de foto: titulo 22 px, guia 17 px y lo que debe cumplir la foto (derecha, nitida, sin reflejos,
  documento completo). Politicas de privacidad: las fotos se envian a Gemini solo al leerlas
- Login de la app (PanelMarca): el logo del icono del APK (assets/logo_unitaxi.png) en lugar del cuadro rojo
  con el taxi, centrado junto con UNITAXI y el subtitulo (la columna ocupa todo el ancho)
- Google en el APK (GoogleMovil.idToken): ya no se borra el estado de credenciales antes de abrir el selector
  (Credential Manager respondia "cancelado" y habia que intentar varias veces); se suelta la cuenta despues
  de obtener el token y los "cancelado" que no son de la persona (reauth [16], interrumpido o inmediatos)
  se reintentan solos hasta 3 veces

## Carnet observado (2026-10-01)

- Al confirmar el carnet ("Confirma tus datos", confirmarDatosCarnet devuelve RespuestaCarnet) hay tres
  opciones: Si, son mis datos / No, volver a tomar las fotos / "Observado: mis datos estan mal". Observado
  primero explica (modal naranja) que un administrador verificara lo que lleno el sistema (IA u otro lector)
  con las fotos y que solo el puede corregirlo. Vale en el registro de pasajero con Google, verificar carnet
  y el registro de conductor (formulario, Google y desde pasajero); el cambio de fotos con permiso no lo
  ofrece (conObservado: false). Los requests llevan "observado": true
- persona.situacion_carnet (SituacionCarnet VERIFICADO / OBSERVADO; null = de antes, verificado),
  motivo_observacion y fecha_observacion. CarnetService.revisar: OBSERVADO si la persona lo pidio o si
  NombresPermitidos.problema encuentra groserias, albures, palabras de prueba, numeros, letras repetidas o
  palabras sin vocales (sin rechazar: lo revisa el admin; VERGARA, CONCHA, GIL pasan)
- Con Observado no se compara con la lectura de Gemini ni la licencia con el CI (puede estar mal leido), no
  se aprueba al conductor y no sale ningun correo; la contrasena generada queda sin entregar
  (contrasena_generada). No puede pedir viajes (422) ni aprobarse como conductor desde Conductores
- App: UsuarioResponse.carnetObservado -> lib/comun/carnet_observado.dart, aviso rojo fijo (TarjetaModal,
  TipoDialogo.revision) con "Ver si ya me revisaron" y Cerrar sesion; consulta GET /api/cuenta/yo cada 20 s.
  Al aprobarse: notificacion (id 90001, la misma del push CUENTA_APROBADA) y la app pasa al inicio, que
  muestra "Revisa tu correo". Rechazado: la sesion se corta con el motivo (JwtAuthFilter lo lee de
  motivo_observacion "Rechazado: ...")
- Panel: Personas > Carnets observados (pantalla_carnets_observados.dart, /api/admin/carnets-observados).
  Revisar: fotos del carnet (y "Ver licencia" del conductor) junto a los datos editables; "Aprobar y enviar
  credenciales" (PUT .../{idPersona}/aprobar) los guarda, deja VERIFICADO y envia credenciales y push; con
  aprobarConductor el conductor queda APROBADO (correo de aprobado). Rechazar (PUT .../rechazar, motivo):
  correo con el motivo, push, cuentas de la app y persona en X y se liberan CI, correo y telefono para que
  pueda registrarse de nuevo (RevisionCarnetService)

## Favoritos y panel del pasajero (2026-10-01)

- El nombre de un favorito elegido como destino solo lo ve el pasajero: va en
  solicitud_viaje.destino_nombre_pasajero (request destinoNombre) y destinoDireccion lleva la direccion real
  del punto (Nominatim al elegirlo). SolicitudViajeResponse/ViajeResponse.destinoNombre solo se llena si el
  usuario actual es ese pasajero (sinNombreDestino() para el topic y el aviso al conductor). App:
  destinoTexto = destinoNombre o la direccion; el conductor usa destinoDireccion
- PanelEligiendo y el modal de confirmacion: primero el precio y la forma de pago, luego partida, destino y
  ruta, y al final "Solicitar taxi"

## Correo, credenciales y contrasena olvidada

- CorreoService reintenta el envio (0, 5 y 30 s) si el SMTP falla; el ingreso con Google del APK reintenta
  la verificacion del id_token (tokeninfo) hasta 3 veces ante fallas de red o 5xx y registra el motivo si
  Google lo rechaza (antes un corte puntual perdia el correo de credenciales y obligaba a reintentar Google)
- spring-boot-starter-mail; SMTP por spring.mail.* (MAIL_USUARIO / MAIL_PASSWORD; valores reales en el perfil
  xexel, cuenta unitaxi@uap.edu.bo de Google Workspace). communication/service/CorreoService encola el correo
  como evento y lo envia @Async despues del commit; si falla solo queda en el log
- identity/service/CredencialesCorreoService: contrasena legible (10 caracteres) y textos cortos.
  Pasajero con Google: correo de bienvenida con usuario y contrasena al registrarse. Conductor: nada al
  registrarse; al pasar a APROBADO (GestionConductorService.cambiarSituacion) recibe el correo. Si su
  contrasena la genero el sistema (usuario.contrasena_generada = true, registro con Google) se le crea
  una nueva y se envia; si la eligio el, el correo le recuerda el usuario
- "¿Olvidaste tu contraseña?" en el login: POST /api/auth/contrasena/olvido {correo} (codigo de 6 digitos
  por correo, 15 min, 5 intentos, uno por minuto, en memoria) y POST /api/auth/contrasena/restablecer
  {correo, codigo, nueva, confirmacion}: cambia juntas las cuentas de pasajero y conductor
- Quien entra sin correo ve lib/comun/completar_correo.dart (POST /api/cuenta/correo) antes de seguir

## GPS obligatorio y notificaciones

- lib/widgets/requiere_gps.dart envuelve las vistas de pasajero y conductor: con el GPS apagado o sin
  permiso tapa todo con el boton para activarlo (la vista sigue viva debajo)
- Conductor: lib/core/notificador.dart (flutter_local_notifications, tambien web en https/localhost)
  avisa cada solicitud nueva que aparece en la consulta periodica. Vibra (Vibracion.corta, USAGE_NOTIFICATION) y el canal
  solicitudes_viaje_v2_* lleva patron de vibracion (2026-10-02; los canales viejos no vibraban en algunos telefonos). Llega con la app abierta o
  minimizada; con la app cerrada del todo haria falta FCM. Android: POST_NOTIFICATIONS y desugaring
- Pasajero: aviso de taxistas libres en el panel (DisponibilidadTaxis); si pide sin ninguno libre, modal
  naranja (mostrarAviso) de que puede demorar. Los paneles de solicitud y viaje se bajan para ver el mapa
  completo con la ruta (PanelPlegable) y se vuelven a abrir tocando la barra

## Historial, calificacion y paneles (2026-09-29)

- Historial de la app (pasajero y conductor): solo viajes COMPLETADOS. GET /api/{pasajero|conductor}/viajes/historial
  ?periodo=RECIENTES|MES_ACTUAL|MES_ANTERIOR&pagina=N (HistorialViajesResponse: 10 por pagina, totales del
  periodo). En la app: chips Ultimos 10 | Este mes | Mes anterior y paginador (lib/comun/historial_viajes.dart).
  GET /viajes (lista completa) queda para los lugares frecuentes y la calificacion pendiente
- Lugares frecuentes: se pueden quitar (tacho); lo quitado y los favoritos eliminados se guardan en el
  telefono (taxiuap_frecuentes_ocultos) para no volver a sugerirlos
- Calificacion del pasajero: solo se ofrece la del ULTIMO viaje completado y una sola vez: al mostrar el
  cuadro se marca en el servidor (viaje.calificacion_ofrecida_pasajero, POST /api/pasajero/viajes/{id}/
  calificacion/ofrecida) y en el telefono. Cerrarlo con atras cuenta como omitir
- PanelPlegable (lib/widgets/paneles.dart). Pasajero: eligiendo destino empieza compacto (tarifa, distancia,
  tiempo, taxistas libres y pago Efectivo/QR; se pide con el boton central); buscando conductor es un panel
  pequeno fijo; desde que un conductor acepta, plegable. Conductor: detalle de solicitud y todas las fases
  del viaje plegables; plegado deja la ruta y el boton del siguiente paso. Con solicitud abierta o viaje, el
  boton verde de conectarse no se muestra. Los paneles quedan por encima del boton central
- Mapa: capas Calles y Satelite (sin Claro); se gira con dos dedos y BotonBrujula (vista_mapa.dart) vuelve
  al norte; los marcadores quedan derechos (MarkerLayer rotate)
- Correos: enlace "Iniciar sesion" a <taxiuap.url-publica>/ingresar?rol=... (EnlaceIngresoController):
  en Android abre la app (esquema taxiuap://ingresar, intent-filter en el manifest) o, si no esta, la web;
  en PC abre /app o /admin
- Barra de estado del telefono con iconos blancos (BarraSistema.sobreAzul en lib/core/tema.dart); las
  pantallas de fondo claro arriba (pedir correo, activar GPS) usan sobreClaro

## Archivos subidos (PDF y fotos)

- Nunca en la BD: solo la ruta relativa. Carpeta raiz en configuracion_sistema (clave archivos.raiz),
  por defecto ${user.home}/Documentos Unitaxi; el admin la cambia en Sistema > Carpeta de archivos
  (explorador de carpetas del servidor, solo bajo el home, /media y /mnt). Al cambiarla se copian y
  verifican todos los archivos, se guarda la ruta nueva y se borran los originales
- Una carpeta por persona, lo general separado de lo del conductor:
  personas/<id>_<ci>/general/foto_perfil_<rol>.jpg y personas/<id>_<ci>/conductor/documentos/<TIPO>_<fecha>.pdf.
  Si la persona ya tiene carpeta se reutiliza aunque cambie su CI. Reemplazar un PDF conserva el anterior
- Fotos de perfil: el servidor recorta el cuadrado central a 512x512 JPEG (ProcesadorImagen)
- config/ArchivosInitializer mueve los PDF con la ruta vieja (taxiuap.archivos.directorio) a esta estructura

## Expediente en el panel y permisos de edicion

- El ojo "Ver mas" de Conductores y Pasajeros abre el expediente (TablaDatos/ListadoRemoto: alVer):
  conductor = Datos y moto, Documentos (PDF en modal, revisar, editar, reemplazar, eliminar), Viajes (con
  la ruta en el mapa), Calificaciones (quitar comentario o eliminar; el promedio se recalcula) y Permisos;
  pasajero = Datos, Favoritos, Viajes, Calificaciones dadas
- permiso_edicion_conductor: el admin elige que puede cambiar el conductor (DATOS y/o el PDF de documentos
  puntuales). Cada permiso se cierra al usarlo o vence en taxiuap.permisos.minutos-edicion (60). Sin
  permiso el conductor solo ve sus datos y documentos; el PDF nuevo queda PENDIENTE
- config/CalificacionesInitializer recalcula al arrancar el promedio y total de cada conductor

## Apps: perfil, credenciales y calificacion

- Cabecera del inicio: foto de perfil en el cuadro rojo (AvatarCabecera); sin foto, moto (conductor) o
  silueta (pasajero)
- Mi perfil (pasajero y conductor, lib/comun/pantalla_perfil.dart + datos_perfil.dart): foto con galeria
  o camara (image_picker), siempre editable. "Editar" (2026-09-30) solo cambia correo y telefono, y la
  licencia / categoria del conductor mientras esten en blanco; el resto lo cambia el admin. Se confirma
  con la huella o la contrasena (PUT /api/cuenta/datos con password) y avisa al correo anterior si
  cambio el correo
- Carnet con Google (2026-09-30): persona.ingreso_google se marca al entrar o registrarse con Google.
  Sin CI, UsuarioResponse.requiereCarnet y la app muestra lib/comun/verificar_carnet.dart (despues de
  completar correo). SelectorCarnet (lib/comun/selector_carnet.dart): foto de anverso y reverso con
  camara o galeria; en el APK se leen con ML Kit en el telefono (lib/core/carnet/ocr_carnet*.dart,
  prueba la foto girada) y solo se acepta si es un carnet boliviano del lado correcto
  (lib/core/carnet/lectura_carnet.dart, con tests): numero tras "N°"/"No" (o la MRZ I<BOL), complemento
  solo si va pegado con guion, fecha de nacimiento (etiqueta, MRZ o "Nacido el"). En la web no hay OCR:
  se escriben a mano. POST /api/cuenta/carnet (multipart datos/anverso/reverso). El registro de conductor
  con Google exige las fotos (partes CARNET_ANVERSO / CARNET_REVERSO). Se guardan en
  personas/<id>_<ci>/general/carnet/ y sus rutas en persona.carnet_anverso_url / carnet_reverso_url.
  Lectura en cualquier posicion (2026-10-01, ocr_carnet_movil.dart): se mide hacia donde corre el texto
  (cornerPoints de las lineas) y se gira la foto hasta dejarlo derecho antes de aceptar la lectura; de
  cabeza ML Kit desordenaba lineas y pegaba palabras. Carnet antiguo: "A:" queda sola y el nombre en la
  linea de antes o de despues; se limpia la basura pegada delante ("uAXEL", "3AXEL"). Probado con fotos
  reales en el emulador (sonda en el scratchpad, nunca en el repo): 16 combinaciones de giro, mismo resultado.
  Foto inclinada (2026-10-01): ML Kit lee la etiqueta "A:" como "A", "SA", "2A" o la pierde y mete el
  texto vertical del borde (ESTADO PLURINACIONAL...) entre las lineas; si no hay "A:" el nombre se busca junto a
  "Nacido el", y se descartan lineas con minusculas, pedazos del borde y departamentos. Tambien I leida como
  ! o 1 y "Nacido el27de". Probado de -15 a +20 grados en el emulador.
  ocr_carnet_movil arma ademas el texto por FILAS segun la posicion de cada linea (enderezada con el angulo
  del texto, sin las lineas del borde vertical) y lo pone antes del texto crudo de ML Kit: "A:" y el nombre
  quedan en una fila aunque ML Kit los separe en bloques. Si aun asi el nombre no sale, los campos se
  habilitan y cada palabra escrita debe estar en las fotos (DatosCarnet.palabrasDelCarnet, una letra de
  tolerancia); vale para verificar carnet, registro de conductor y cambio de fotos. RapidOCR (Python) se
  probo y no mejoraba a ML Kit (peor con la foto de costado): no se usa
  android/app/proguard-rules.pro: -keep de ML Kit (sin eso R8 quitaba sus constructores por reflexion y
  en el APK release toda lectura fallaba) y dontwarn de los alfabetos que no se usan. Cada foto se
  prueba en 4 rotaciones: acepta el carnet de cabeza o de costado. Probado en emulador con ML Kit real
- Credenciales con Google (2026-09-30): el pasajero sin CI NO recibe correo al registrarse (contrasena
  generada queda sin entregar); le llega "Bienvenido" recien al guardar su carnet (CarnetService). El
  conductor con Google recibe al registrarse (carnet incluido) sus credenciales y el aviso de que esta en
  revision (CredencialesCorreoService.conductorEnRevision); entra con acciones restringidas (Cuenta en
  revision) y al aprobarlo el correo le recuerda su contrasena. RegistroMotoConductorService ignora las
  partes CARNET_* (las valida CarnetService)
- Fotos del carnet en el panel: boton "Ver carnet" en Datos personales del expediente (conductor y
  pasajero) -> modal_carnet.dart con anverso y reverso; GET /api/admin/usuarios/{id}/carnet/{anverso|reverso}
  (solo ADMIN)
- Inicio de la app: tocar la foto o el saludo de la cabecera va a Mas; el buscador "¿A donde vas?" va
  blanco con sombra justo debajo de la cabecera (8 px). Datos personales: la calificacion solo la ve el
  conductor
- Icono de la app: logo UNITAXI recortado por su marco azul marino; adaptativo con fondo #012852
  (mipmap-anydpi-v26) para que la forma del lanzador no lo corte; tambien web/icons y favicon
- Ningun PDF bloquea la app (desde 2026-09-30 documentosFaltantes llega vacio: el carnet y la licencia
  van como fotos). En Mis documentos se ven las fotos del carnet y la licencia y los PDF, y se agrega el
  SOAT si falta (POST /api/conductor/documentos?tipo=SOAT)
- Login: "Recordar usuario y contraseña" con flutter_secure_storage; al cerrar sesion quedan los campos
- Conductor: Mis documentos (PDF en modal: pdfx en Android, iframe en web) y edicion con permiso
- Pasajero: al terminar el viaje un cuadro pequeno (estrellas y comentario) una sola vez; si lo omite
  no se vuelve a ofrecer
- Guia de inicio (lib/widgets/guia_inicio.dart, mostrarGuiaInicio + PasoGuia con GlobalKey): la primera vez
  que entra cada cuenta, fondo oscuro con el boton iluminado y un cuadro "1 de 5" con Saltar / Siguiente.
  Pasajero: destino, Moto, boton pedir, Historial, Mas. Conductor: conectarse, solicitudes, Historial,
  Opiniones, Mas (espera a que este habilitado). usuario.guia_vista: false al crear la cuenta
  (CuentaUsuarioService.crearUsuario), null en las anteriores (no la ven); UsuarioResponse.mostrarGuia;
  al terminar o saltar POST /api/cuenta/guia-vista. Espera al GPS listo (RequiereGps.listo)

---

## Arranque unico (iniciar.sh)

- ./iniciar.sh: docker compose up -d --wait, compila admin-panel (--base-href /admin/) y app-movil
  (--base-href /app/) si cambio su codigo, y arranca el backend. config/SitiosWebConfig sirve
  admin-panel/build/web en /admin y app-movil/build/web en /app (propiedades taxiuap.web.admin y
  taxiuap.web.app); "/" redirige a /app. Mismo origen que la API: no hace falta CORS
- flutter run sigue sirviendo para programar con recarga en caliente (CORS por cors.origenes)

## Controllers

Agrupados por actor en com.taxiuap.backend.controller:

- auth/       registro de pasajero y conductor, login, refresh
- publico/    catalogos sin autenticacion
- pasajero/   perfil, solicitar viaje, ver y aceptar ofertas, direcciones guardadas, matricula
              estudiantil, calificar, chat, SOS, contactos de emergencia
- conductor/  perfil, vehiculos, documentos, disponibilidad, ofertas, viaje en curso,
              billetera, calificar, chat
- admin/      personas, usuarios (alta de administradores), pasajeros, aprobacion de conductores y
              documentos, verificacion estudiantil, tarifas, descuentos, zonas, reportes, alertas SOS

Dentro de cada carpeta, un controller por funcionalidad. La division fina la decide el orquestador.

---

## Alcance: entidades completas, CRUD selectivo

### Entidades: TODAS

Se crean las 40 entidades JPA del modelo, con todos sus campos, relaciones, indices
y enums. Cada una con su repositorio Spring Data (JpaRepository) aunque todavia no
tenga servicio ni controller. Esto permite que Hibernate genere el esquema completo
desde el arranque.

### CRUD: solo lo esencial

No generar CRUD completo para todas las entidades. Se implementa asi:

**CRUD completo (create, read, update, delete logico) - panel admin**
- institucion, carrera, tipo_institucion
- tipo_vehiculo, categoria_servicio
- zona
- tarifa
- regla_descuento_estudiantil
- descuento
- etiqueta_calificacion

**CRUD parcial (create, read, update; sin delete) - operacion**
- persona, usuario, pasajero, conductor  (create via registro, update de perfil). Ademas el admin puede
  registrar y editar personas (/api/admin/personas) y crear cuentas de usuario para una persona existente
  (POST /api/admin/personas/{id}/usuarios, multipart). El admin registra pasajero, conductor, ambos o
  administrador; ademas hay registro publico desde la app (ver "Registro publico y Google"). Una persona tiene a lo sumo una cuenta por rol; sus cuentas de pasajero
  y conductor comparten nombre de usuario y contrasena. Al habilitar un conductor se registra su moto
  (primera etapa: solo MOTO) y sus documentos PDF (CI y LICENCIA obligatorios), que quedan PENDIENTE.
  Personas y usuarios tambien se eliminan (borrado logico; eliminar una persona desactiva sus cuentas)
- vehiculo, documento_conductor
- estudiante, matricula_estudiante
- direccion_guardada  (este si lleva delete)
- contacto_emergencia (este si lleva delete)

**Solo create + read - registros inmutables**
- calificacion, respuesta_calificacion
- pago, comision
- mensaje, notificacion
- alerta_sos, reporte, reporte_comentario
- verificacion_estudiante

**Sin CRUD - se manejan por flujo de negocio, no por endpoints genericos**
- solicitud_viaje, oferta_viaje, viaje: se controlan con acciones de negocio
  (solicitar, ofertar, aceptar, iniciar, finalizar, cancelar), no con PUT/DELETE genericos
- historial_estado_viaje, punto_recorrido: se escriben desde el servicio de viaje
- ubicacion_conductor, disponibilidad_conductor: se actualizan por WebSocket
- billetera_conductor: se actualiza como efecto de pagos y comisiones
- calificacion_etiqueta: se crea junto con la calificacion
- rol, administrador, dispositivo, tutor_estudiante: gestion interna

Regla general: si una entidad no esta en las listas de arriba, tiene entidad y
repositorio pero NO controller propio.

Ademas, el delete siempre es logico: cambiar estado_<entidad> a X. Los listados solo devuelven registros en A.
Nunca usar DELETE fisico sobre la BD.

---

## Datos de prueba (seed)

Objetivo: dejar la BD poblada para poder probar el backend y luego los frontends
sin tener que cargar datos a mano.

### Implementacion

- Paquete com.taxiuap.backend.seed
- Una clase DataSeeder con @Component y @Profile("xexel"), que implemente CommandLineRunner
- Se ejecuta solo si taxiuap.seed.habilitado=true
- Debe ser idempotente: antes de insertar, verificar si ya existen datos
  (por ejemplo, si rolRepository.count() > 0 no hacer nada). Nunca duplicar
- Dividir la carga en metodos privados por dominio, en orden de dependencias:
  roles -> catalogos -> personas y usuarios -> instituciones -> vehiculos ->
  zonas y tarifas -> viajes historicos
- Contrasena de todos los usuarios de prueba: "Taxi123*" (hasheada con BCrypt)
- Coordenadas reales de Cobija, Pando (aproximadamente -11.02, -68.76)

### Volumen de datos a generar

Catalogos:
- rol: PASAJERO, CONDUCTOR, ADMIN
- tipo_institucion: UNIVERSIDAD, INSTITUTO, COLEGIO
- institucion: al menos UAP (Universidad Amazonica de Pando, sigla UAP, Cobija)
  y 2 instituciones mas
- carrera: 5 carreras de la UAP
- tipo_vehiculo: SEDAN (4), MOTO (1), VAN (7)
- categoria_servicio: ESTANDAR y EJECUTIVO para SEDAN, MOTO para moto
- etiqueta_calificacion: 6 positivas y 4 negativas, repartidas entre CONDUCTOR y PASAJERO
- zona: 2 zonas de Cobija con poligonos simples

Usuarios:
- 1 administrador
- 8 pasajeros, de los cuales 4 son estudiantes de la UAP con matricula:
  2 con situacion_verificacion APROBADA, 1 PENDIENTE, 1 RECHAZADA
- 6 conductores: 4 con situacion_aprobacion APROBADO (cada uno con vehiculo y
  documentos aprobados), 1 PENDIENTE, 1 RECHAZADO
- billetera_conductor para cada conductor, con saldos distintos
- disponibilidad_conductor y ubicacion_conductor para los 4 aprobados,
  con coordenadas distintas dentro de Cobija

Precios:
- tarifa vigente por cada categoria_servicio y zona
- regla_descuento_estudiantil: 20 por ciento para UNIVERSIDAD en SEDAN,
  maximo 5 Bs por viaje, 4 viajes por dia
- descuento: 2 cupones vigentes y 1 vencido

Viajes de prueba:
- 10 viajes COMPLETADOS con fechas de los ultimos 30 dias, cada uno con su
  solicitud_viaje, su oferta_viaje aceptada, pago, comision, historial de estados
  y entre 5 y 10 punto_recorrido
- De esos 10, al menos 3 con descuento estudiantil aplicado
- 8 calificaciones sobre esos viajes (de ambos lados), 2 con etiquetas y 1 con respuesta
- 2 viajes CANCELADOS, uno por el pasajero y otro por el conductor
- 1 solicitud_viaje en situacion PENDIENTE sin ofertas
- 1 solicitud_viaje en situacion CON_OFERTAS con 3 ofertas pendientes
- 1 viaje en situacion EN_CURSO
- mensajes de chat en 2 de los viajes
- 1 alerta_sos ATENDIDA y 1 reporte RESUELTO

### Advertencia

El seeder solo debe existir para el perfil xexel. Nunca debe ejecutarse en produccion
ni insertar datos si la BD ya tiene registros reales.

---

## Modelo de datos completo

Convenciones:
- Todos los campos estado_<entidad> son varchar con valores A (activo) / X (eliminado); borrado logico
- Los campos situacion_* son varchar con valores de negocio especificos (indicados en cada entidad)
- Los valores de situacion y tipo se modelan como enums Java guardados con @Enumerated(EnumType.STRING)
- geography: Point o Polygon con SRID 4326

### Dominio: identity

**persona** — datos de una persona real
- id_persona bigint PK
- ci varchar, complemento_ci varchar
- nombres varchar, apellidos varchar
- fecha_nacimiento date
- correo varchar (unico), telefono varchar (unico) — contacto de la persona, compartido por sus cuentas
- estado_persona varchar

**rol**
- id_rol int PK
- codigo varchar (PASAJERO / CONDUCTOR / ADMIN)
- nombre varchar
- estado_rol varchar

**usuario** — cuenta de acceso
- id_usuario bigint PK
- id_persona bigint FK -> persona
- id_rol int FK -> rol
- nombre_usuario varchar — unico por rol (uk_usuario_nombre_rol) y de una sola persona
- password_hash varchar
- foto_url varchar
- fecha_registro timestamp
- estado_usuario varchar

**pasajero**
- id_pasajero bigint PK
- id_usuario bigint FK -> usuario (1-1)
- calificacion_promedio decimal, total_calificaciones int
- estado_pasajero varchar

**conductor**
- id_conductor bigint PK
- id_usuario bigint FK -> usuario (1-1)
- numero_licencia varchar, categoria_licencia varchar
- situacion_aprobacion varchar (PENDIENTE / APROBADO / RECHAZADO / SUSPENDIDO)
- calificacion_promedio decimal, total_calificaciones int
- fecha_aprobacion timestamp
- estado_conductor varchar

**administrador**
- id_admin bigint PK
- id_usuario bigint FK -> usuario (1-1)
- cargo varchar
- estado_admin varchar

**dispositivo** — tokens FCM
- id_dispos bigint PK
- id_usuario bigint FK -> usuario
- token_fcm varchar, plataforma varchar (ANDROID / IOS)
- ultima_conexion timestamp
- estado_dispos varchar

### Dominio: institution

**tipo_institucion**
- id_tipo_inst int PK
- codigo varchar (UNIVERSIDAD / COLEGIO / INSTITUTO)
- nombre varchar
- estado_tipo_inst varchar

**institucion**
- id_inst bigint PK
- id_tipo_inst int FK -> tipo_institucion
- nombre varchar, sigla varchar, ciudad varchar
- estado_inst varchar

**carrera**
- id_carrera bigint PK
- id_inst bigint FK -> institucion
- nombre varchar
- estado_carrera varchar

**estudiante**
- id_estudiante bigint PK
- id_persona bigint FK -> persona
- id_inst bigint FK -> institucion
- codigo_estudiante varchar
- estado_estudiante varchar

**matricula_estudiante**
- id_mat_est bigint PK
- id_estudiante bigint FK -> estudiante
- id_carrera bigint FK -> carrera
- curso_grado varchar, periodo_academico varchar, plan_estudio varchar
- codigo_matricula varchar
- fecha_matricula timestamp
- imagen_matricula_url varchar
- situacion_verificacion varchar (PENDIENTE / APROBADA / RECHAZADA / VENCIDA)
- fecha_vencimiento date
- estado_mat_est varchar

**verificacion_estudiante**
- id_verif_est bigint PK
- id_mat_est bigint FK -> matricula_estudiante
- id_admin_revisor bigint FK -> administrador
- fecha_envio timestamp, fecha_revision timestamp
- resultado varchar (APROBADO / RECHAZADO)
- motivo_rechazo text
- estado_verif_est varchar

**tutor_estudiante**
- id_tutor_est bigint PK
- id_estudiante bigint FK -> estudiante
- id_persona bigint FK -> persona
- telefono varchar, parentesco varchar
- autorizacion_aceptada boolean, fecha_autorizacion timestamp
- estado_tutor_est varchar

### Dominio: vehicle

**tipo_vehiculo**
- id_tipo_veh int PK
- codigo varchar (SEDAN / MOTO / VAN)
- nombre varchar, capacidad_pasajeros int
- estado_tipo_veh varchar

**categoria_servicio**
- id_cat_serv int PK
- id_tipo_veh int FK -> tipo_vehiculo
- nombre varchar (ESTANDAR / EJECUTIVO)
- estado_cat_serv varchar

**vehiculo**
- id_vehiculo bigint PK
- id_conductor bigint FK -> conductor
- id_tipo_veh int FK -> tipo_vehiculo
- id_cat_serv int FK -> categoria_servicio
- placa varchar, marca varchar, modelo varchar, color varchar, anio int
- estado_vehiculo varchar

**documento_conductor**
- id_doc_cond bigint PK
- id_conductor bigint FK -> conductor
- id_vehiculo bigint FK -> vehiculo
- id_admin_revisor bigint FK -> administrador
- tipo_documento varchar (CI / LICENCIA / SOAT / RUAT / INSPECCION_TECNICA / ANTECEDENTES)
- archivo_url: ruta relativa del PDF dentro de la carpeta raiz de archivos (ver "Archivos subidos")
- archivo_url varchar
- fecha_vencimiento date
- situacion_revision varchar (PENDIENTE / APROBADO / RECHAZADO)
- estado_doc_cond varchar

### Dominio: location

**zona**
- id_zona int PK
- nombre varchar
- poligono geography(Polygon, 4326)
- estado_zona varchar

**ubicacion_conductor** — actualizada via WebSocket
- id_ubic_cond bigint PK
- id_conductor bigint FK -> conductor (1-1)
- ubicacion geography(Point, 4326)
- rumbo decimal, velocidad decimal
- actualizado_en timestamp
- estado_ubic_cond varchar

**disponibilidad_conductor**
- id_disp_cond bigint PK
- id_conductor bigint FK -> conductor
- disponibilidad varchar (DISPONIBLE / OCUPADO / DESCONECTADO)
- desde timestamp
- estado_disp_cond varchar

**direccion_guardada**
- id_dir_guar bigint PK
- id_pasajero bigint FK -> pasajero
- nombre varchar, direccion varchar
- ubicacion geography(Point, 4326)
- estado_dir_guar varchar

### Dominio: trip

**solicitud_viaje**
- id_sol_viaje bigint PK
- id_pasajero bigint FK -> pasajero
- id_cat_serv int FK -> categoria_servicio
- origen geography(Point, 4326), destino geography(Point, 4326)
- origen_direccion varchar, destino_direccion varchar
- precio_sugerido decimal
- situacion_solicitud varchar (PENDIENTE / CON_OFERTAS / ACEPTADA / CANCELADA / EXPIRADA)
- fecha_solicitud timestamp
- estado_sol_viaje varchar

**oferta_viaje**
- id_ofer_viaje bigint PK
- id_sol_viaje bigint FK -> solicitud_viaje
- id_conductor bigint FK -> conductor
- precio_ofertado decimal, tiempo_llegada_min int
- situacion_oferta varchar (PENDIENTE / ACEPTADA / RECHAZADA / EXPIRADA)
- fecha_oferta timestamp
- estado_ofer_viaje varchar

**viaje**
- id_viaje bigint PK
- id_sol_viaje bigint FK -> solicitud_viaje (1-1)
- id_pasajero bigint FK -> pasajero
- id_conductor bigint FK -> conductor
- id_vehiculo bigint FK -> vehiculo
- id_cat_serv int FK -> categoria_servicio
- id_tarifa bigint FK -> tarifa
- id_estudiante bigint FK -> estudiante (nullable)
- id_regla_desc bigint FK -> regla_descuento_estudiantil (nullable)
- id_descuento bigint FK -> descuento (nullable)
- origen geography(Point, 4326), destino geography(Point, 4326)
- distancia_km decimal, duracion_min int
- precio_original decimal, monto_descuento decimal, precio_final decimal
- situacion_viaje varchar (CONFIRMADO / CONDUCTOR_EN_CAMINO / CONDUCTOR_LLEGO / EN_CURSO / COMPLETADO / CANCELADO)
- cancelado_por varchar (PASAJERO / CONDUCTOR / SISTEMA), nullable
- fecha_inicio timestamp, fecha_fin timestamp
- estado_viaje varchar

**historial_estado_viaje**
- id_hist_viaje bigint PK
- id_viaje bigint FK -> viaje
- id_usuario_cambio bigint FK -> usuario
- situacion_viaje varchar
- fecha timestamp
- estado_hist_viaje varchar

**punto_recorrido**
- id_pto_rec bigint PK
- id_viaje bigint FK -> viaje
- ubicacion geography(Point, 4326)
- registrado_en timestamp
- estado_pto_rec varchar

### Dominio: pricing

**tarifa**
- id_tarifa bigint PK
- id_cat_serv int FK -> categoria_servicio
- id_zona int FK -> zona
- tarifa_base decimal, precio_km decimal, precio_minuto decimal, tarifa_minima decimal
- vigente_desde date, vigente_hasta date
- estado_tarifa varchar

**regla_descuento_estudiantil**
- id_regla_desc bigint PK
- id_tipo_inst int FK -> tipo_institucion
- id_tipo_veh int FK -> tipo_vehiculo
- porcentaje decimal, monto_maximo decimal
- viajes_maximos_dia int
- vigente_desde date, vigente_hasta date
- estado_regla_desc varchar

**descuento** — cupones o promociones
- id_descuento bigint PK
- codigo varchar, descripcion varchar
- porcentaje decimal, monto_maximo decimal
- usos_maximos int
- vigente_desde date, vigente_hasta date
- estado_descuento varchar

**pago**
- id_pago bigint PK
- id_viaje bigint FK -> viaje
- metodo_pago varchar (EFECTIVO / QR / TARJETA)
- monto decimal
- situacion_pago varchar (PENDIENTE / COMPLETADO / FALLIDO / REEMBOLSADO)
- referencia_transaccion varchar
- fecha_pago timestamp
- estado_pago varchar

**comision**
- id_comision bigint PK
- id_viaje bigint FK -> viaje (1-1)
- porcentaje decimal, monto decimal
- estado_comision varchar

**billetera_conductor**
- id_bill_cond bigint PK
- id_conductor bigint FK -> conductor (1-1)
- saldo decimal, deuda_comision decimal
- actualizado_en timestamp
- estado_bill_cond varchar

### Dominio: rating

**calificacion**
- id_calif bigint PK
- id_viaje bigint FK -> viaje
- id_usuario_emisor bigint FK -> usuario
- id_usuario_receptor bigint FK -> usuario
- tipo varchar (PASAJERO_A_CONDUCTOR / CONDUCTOR_A_PASAJERO)
- puntuacion int (1 a 5), comentario text
- fecha timestamp
- estado_calif varchar

**etiqueta_calificacion**
- id_etiq_calif int PK
- nombre varchar
- tipo varchar (POSITIVA / NEGATIVA)
- aplica_a varchar (CONDUCTOR / PASAJERO)
- estado_etiq_calif varchar

**calificacion_etiqueta** — relacion N:M
- id_calif_etiq bigint PK
- id_calif bigint FK -> calificacion
- id_etiq_calif int FK -> etiqueta_calificacion
- estado_calif_etiq varchar

**respuesta_calificacion**
- id_resp_calif bigint PK
- id_calif bigint FK -> calificacion (1-1)
- id_conductor bigint FK -> conductor
- texto text, fecha timestamp
- estado_resp_calif varchar

**reporte_comentario**
- id_rep_coment bigint PK
- id_calif bigint FK -> calificacion
- id_usuario_reporta bigint FK -> usuario
- id_admin_revisor bigint FK -> administrador
- motivo varchar
- situacion_revision varchar (PENDIENTE / REVISADO / DESESTIMADO)
- estado_rep_coment varchar

### Dominio: communication

**mensaje** — chat durante un viaje
- id_mensaje bigint PK
- id_viaje bigint FK -> viaje
- id_usuario_emisor bigint FK -> usuario
- contenido text, leido boolean, fecha timestamp
- estado_mensaje varchar

**notificacion**
- id_notif bigint PK
- id_usuario bigint FK -> usuario
- titulo varchar, cuerpo text
- tipo varchar (VIAJE / PAGO / SISTEMA / ALERTA)
- leida boolean, fecha timestamp
- estado_notif varchar

**contacto_emergencia**
- id_cont_emerg bigint PK
- id_usuario bigint FK -> usuario
- nombre varchar, telefono varchar, parentesco varchar
- estado_cont_emerg varchar

**alerta_sos**
- id_alerta_sos bigint PK
- id_viaje bigint FK -> viaje
- id_usuario bigint FK -> usuario
- ubicacion geography(Point, 4326)
- situacion_alerta varchar (ACTIVA / ATENDIDA / FALSA_ALARMA)
- fecha timestamp
- estado_alerta_sos varchar

**reporte** — incidente en un viaje
- id_reporte bigint PK
- id_viaje bigint FK -> viaje
- id_usuario_reporta bigint FK -> usuario
- motivo varchar, descripcion text
- situacion_reporte varchar (PENDIENTE / EN_REVISION / RESUELTO / CERRADO)
- fecha timestamp
- estado_reporte varchar

---

## Reglas de negocio clave

1. Un conductor no recibe solicitudes si situacion_aprobacion != APROBADO
2. Un conductor opera apenas su situacion_aprobacion pasa a APROBADO, aunque sus documentos sigan en
   revision (pedido del usuario, 2026-09-30). Solo lo frena la licencia vencida (conductor.licencia_vencimiento).
   Desde 2026-10-01 queda APROBADO al registrarse si la app leyo su licencia con OCR y la verifico con el
   carnet (DatosConductorRequest.licenciaVerificada; LicenciaService.aprobarSiVerificada, despues de
   validarDatosRegistro: categoria M, vigente, numero = CI) y le llega "Tu cuenta de conductor fue
   aprobada". Desde la lectura con Gemini (ver su seccion) lo decide el servidor con su propia lectura de la
   licencia; leida con ML Kit o escrita en la web sigue PENDIENTE hasta que lo apruebe el admin
3. El descuento estudiantil solo aplica si matricula_estudiante.situacion_verificacion = APROBADA
   y fecha_vencimiento >= hoy, respetando viajes_maximos_dia y monto_maximo de la regla
4. Un pasajero solo puede tener una solicitud_viaje activa (PENDIENTE o CON_OFERTAS) a la vez
5. Aceptar una oferta debe ser atomico: UPDATE condicional sobre la situacion de la solicitud
   para evitar que dos ofertas se acepten al mismo tiempo (mismo patron que los puestos de uniFex).
   Si el UPDATE afecta 0 filas se lanza ConflictoException (409)
6. Cada cambio de situacion_viaje se registra en historial_estado_viaje
7. Al completar un viaje se crean pago y comision, se actualiza billetera_conductor
   y se habilita la calificacion para ambas partes
8. ubicacion_conductor se actualiza via WebSocket, no via REST
9. Una alerta SOS notifica a los contactos de emergencia y a los administradores
10. Solo se pueden calificar viajes COMPLETADOS, una vez por cada parte
11. Todo borrado es logico: cambiar estado_<entidad> a X, nunca DELETE fisico
12. Una persona tiene a lo sumo una cuenta activa por rol; pasajero y conductor comparten credenciales
13. Los documentos del conductor se suben como PDF (se valida la firma %PDF-, maximo 5 MB)

---

## Comandos del proyecto

```bash
# Base de datos (PostGIS en Docker, puerto 5436)
docker compose up -d
docker compose down          # detener (los datos quedan en el volumen)

# Backend
cd backend && ./gradlew bootRun
cd backend && ./gradlew build

# Verificar tablas creadas por Hibernate
docker exec taxiuap-db psql -U postgres -d taxiuap -c "\dt"

# Panel admin (Flutter Web). Flutter esta en ~/development/flutter (PATH en ~/.bashrc)
./iniciar.sh                                                 # todo junto: /admin y /app en el 8080
cd admin-panel && flutter run -d chrome --web-port 5173     # puerto 5173: ya permitido por cors.origenes
cd admin-panel && flutter build web --release --no-tree-shake-icons --no-web-resources-cdn
# --no-tree-shake-icons: el recorte de fuentes descarta iconos Font Awesome Solid (se ven como cuadros vacios)
# --no-web-resources-cdn: CanvasKit se sirve desde el build, sin depender de gstatic.com (funciona sin internet)
# Otra URL de backend: --dart-define=API_URL=http://servidor:8080

# Flutter (apps moviles; falta instalar Android Studio / Android SDK)
cd app-movil && flutter run -d chrome --web-port 5174       # prueba en navegador
cd app-movil && flutter run
cd app-movil && flutter build appbundle --release
```

---

## Estado del proyecto

- [x] Estructura de carpetas del monorepo
- [x] Proyecto Spring Boot en backend/ con dependencias completas
- [x] Configuracion base y conexion a BD taxiuap (perfil xexel)
- [x] config/ y config/security/ adaptados de uniFex (JWT, roles, auditoria)
- [x] shared/ (ApiResponse, excepciones, manejador global)
- [x] Entidades y repositorios: dominio identity
- [x] Entidades y repositorios: dominio institution
- [x] Entidades y repositorios: dominio vehicle
- [x] Entidades y repositorios: dominio location
- [x] Entidades y repositorios: dominio trip
- [x] Entidades y repositorios: dominio pricing
- [x] Entidades y repositorios: dominio rating
- [x] Entidades y repositorios: dominio communication
- [x] Verificacion: esquema en la BD - 43 de 43 tablas (PostGIS en Docker)
- [x] CRUD de catalogos (panel admin) + lectura publica
- [x] Registro y login (auth) + AdminInitializer
- [x] CRUD parcial de perfiles, vehiculos y matriculas
- [x] Flujo de viaje (solicitud -> oferta -> viaje -> pago) - implementado; falta prueba end-to-end por la API
- [x] DataSeeder con datos de prueba - ejecutado y verificado (corre despues de AdminInitializer via @Order)
- [x] Backend arrancando contra la BD en Docker; login, 401/403 y endpoints con geography verificados
- [x] Panel admin: tabla con N°, ojo que abre modal de detalle, menu Ordenar; modales animados (verde / naranja / rojo)
- [x] Repositorio GitHub: https://github.com/XeXeL27/UniTaxi-V0.2 (publico). Sin properties ni .env
- [ ] SIGUIENTE (fase 2 del panel, pendiente de aprobacion): grupos Instituciones, Vehiculos, Tarifas y
      descuentos, Calificaciones con la misma TablaDatos + flujos_crud; luego revision de documentos y
      verificaciones estudiantiles
- [x] Una sola app (app-movil) con login unico y cambio de modo; arranque unico con ./iniciar.sh y
      links /admin y /app servidos por el backend (probado en Chrome, 2026-09-28)
- [x] App Flutter pasajero: login, GPS como partida, destino tocando el mapa, favoritos, precio fijo,
      solicitar, seguimiento del viaje y calificacion. Probado de punta a punta en Chrome
- [x] App Flutter conductor: solicitudes con ruta antes de aceptar, estados del viaje, cierre automatico
      a 50 m, historial y comentarios. Probado de punta a punta en Chrome
- [x] Conductores en linea en el mapa del pasajero, estado FINALIZADA, cerrar sesion en la cabecera,
      volver desde la ruta de una solicitud (probado de punta a punta en Chrome, 2026-09-28)
- [x] Expediente de conductores y pasajeros en el panel, carpeta de archivos configurable, fotos de
      perfil, permisos de edicion con vencimiento, recordar credenciales, calificacion en cuadro pequeno
      (probado en Chrome, 2026-09-28)
- [x] Rediseno de la app estilo Karona en azul/rojo (barra inferior, Mas comun, buscador, capas, selector
      Moto/Auto, conectarse), login unico responsive con entrada de admin, cambio de contrasena, huella,
      mapa en vivo del admin con filtros y movimiento suave (probado en Chrome, 2026-09-28)
- [x] Login con Google (rama appu-dev fusionada en main, a57481f) y registro publico de pasajero y
      conductor desde la app (probado en Chrome con un Google falso, 2026-09-28)
- [x] Pago en efectivo o QR (QR del conductor, pedido de cambio que acepta el conductor, comision 0),
      buscador solo Cobija, panel de solicitudes desplegable y sin Moto/Auto en el conductor (probado en
      Chrome, 2026-09-29)
- [x] Correos con credenciales (pasajero al registrarse, conductor al aprobarlo), contrasena olvidada
      por codigo, correo obligatorio, GPS obligatorio, notificacion de solicitud nueva al conductor,
      aviso sin taxistas libres y panel plegable del pasajero (2026-09-29; SMTP sin probar desde aqui)
- [x] Admin desde el login de la app (tambien APK), foto en la cabecera, Mi perfil editable con
      contrasena/huella, bloqueo por documentos faltantes, seguimiento en vivo de appu-dev fusionado
      (probado en Chrome, 2026-09-29; el WebView del APK no se pudo probar aqui)
- [x] Carnet y licencia por foto (licencia M con OCR), confirmacion con contrasena o huella, permisos
      CARNET/LICENCIA, aviso de credenciales, conductor habilitado sin recargar, GPS despues del login,
      avisos de red, vibracion, moto en el viaje, nombre UNITAXI (2026-09-30; backend probado por la API)
- [ ] Siguiente para las apps: prioridad de solicitudes por cercania del conductor (pedido del usuario,
      pospuesto), chat, SOS, descuento estudiantil
- [ ] Instalar Android Studio / Android SDK para compilar el APK
- [x] Estado A/X en todas las tablas; contacto en persona; nombre_usuario; login con rol (BD recreada 2026-09-23)
- [x] Endpoints admin: personas (CRUD + borrado logico), habilitar usuarios (pasajero/conductor/ambos/admin,
      con moto y PDF), usuarios (listar, eliminar), pasajeros, conductores (documentos y descarga del PDF)
- [~] Panel admin Flutter Web - grupo Personas completo: menu retractil, tabla responsive (tabla o tarjetas),
      busqueda, filtros por tipo, orden, paginacion, exportar Excel/CSV/PDF, modales de confirmacion/exito/
      eliminado, habilitar usuario con PDF, documentos del conductor. Faltan: grupos Instituciones,
      Vehiculos, Tarifas y descuentos, Calificaciones; revision de documentos y verificaciones estudiantiles
