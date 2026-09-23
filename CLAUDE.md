# Proyecto: TaxiUAP

App de transporte tipo Uber/inDrive orientada a estudiantes de Bolivia.
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
  passenger-app/    <- Flutter (app del pasajero)
  driver-app/       <- Flutter (app del conductor)
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
- Iconos: Font Awesome (font_awesome_flutter, widget FaIcon). Nunca emojis
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

---

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
  (POST /api/admin/personas/{id}/usuarios, multipart). Solo el admin registra usuarios: pasajero,
  conductor, ambos o administrador. Una persona tiene a lo sumo una cuenta por rol; sus cuentas de pasajero
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
- archivo_url: ruta relativa del PDF dentro de taxiuap.archivos.directorio (por defecto ~/taxiuap-archivos)
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
2. Un conductor no puede operar si algun documento_conductor esta vencido o no aprobado
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
cd admin-panel && flutter run -d chrome --web-port 5173     # puerto 5173: ya permitido por cors.origenes
cd admin-panel && flutter build web --release --no-tree-shake-icons --no-web-resources-cdn
# --no-tree-shake-icons: el recorte de fuentes descarta iconos Font Awesome Solid (se ven como cuadros vacios)
# --no-web-resources-cdn: CanvasKit se sirve desde el build, sin depender de gstatic.com (funciona sin internet)
# Otra URL de backend: --dart-define=API_URL=http://servidor:8080

# Flutter (apps moviles; falta instalar Android Studio / Android SDK)
cd passenger-app && flutter run
cd passenger-app && flutter build appbundle --release
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
- [ ] App Flutter pasajero
- [ ] App Flutter conductor
- [x] Estado A/X en todas las tablas; contacto en persona; nombre_usuario; login con rol (BD recreada 2026-09-23)
- [x] Endpoints admin: personas (CRUD + borrado logico), habilitar usuarios (pasajero/conductor/ambos/admin,
      con moto y PDF), usuarios (listar, eliminar), pasajeros, conductores (documentos y descarga del PDF)
- [~] Panel admin Flutter Web - grupo Personas completo: menu retractil, tabla responsive (tabla o tarjetas),
      busqueda, filtros por tipo, orden, paginacion, exportar Excel/CSV/PDF, modales de confirmacion/exito/
      eliminado, habilitar usuario con PDF, documentos del conductor. Faltan: grupos Instituciones,
      Vehiculos, Tarifas y descuentos, Calificaciones; revision de documentos y verificaciones estudiantiles
