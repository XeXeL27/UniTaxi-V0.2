# Bitácora de cambios

> Registro acumulativo e indefinido de cambios, implementaciones y arreglos del proyecto.
> Nueva entrada arriba: `## FECHA` seguida de uno o más `### TIPO · Título`.

| Fecha | Tipo | Descripción |
|---|---|---|
| 2026-10-05 | ✨ | Task 8 DELIVERY: panel administrativo, evidencia y resolución de reportes |
| 2026-10-05 | ✨ | Task 7 DELIVERY: flujo del repartidor en app móvil |
| 2026-10-05 | Arreglo | Task 6 DELIVERY: correcciones de serialización, precios, reportes y responsive |
| 2026-10-05 | ✨ | Task 6 DELIVERY: flujo de pasajero en app móvil |
| 2026-10-05 | Arreglo | Task 5 DELIVERY: prueba completa de asociación del reporte de paquete no coincidente y su evidencia |
| 2026-10-05 | Arreglo | Task 5 DELIVERY: cobertura completa de asociación de evidencia y matriz de permisos administrativos |
| 2026-10-05 | Arreglo | Task 5 DELIVERY: transición administrativa cerrada, evidencia y pruebas de permisos/persistencia añadidas |
| 2026-10-05 | ✨ | Task 5 DELIVERY: reportes automáticos y resolución administrativa de incidentes |
| 2026-10-04 | Nuevo | Task 4 DELIVERY: transiciones de pedido, validación atómica de códigos, compra confirmada por el cliente, pago directo, entrega y falla de entrega |
| 2026-10-04 | Arreglo | Task 3 fix round 2 DELIVERY: tarifa técnica zona nula on-demand, defaults MOTO, placa compatible y catálogo de tarifas seguro |
| 2026-10-04 | Arreglo | Task 3 DELIVERY: precio OSRM por snapshot, estimado marcado al asignar, moto compatible, tarifa de referencia y revalidación de aceptación |
| 2026-10-02 | 📚 | Pausa documentada de implementación DELIVERY en Task 3; Tasks 1 y 2 revisadas, Task 3 implementada pendiente de re-review |
| 2026-10-02 | Arreglo | Correcciones del reviewer para Task 3 DELIVERY: tipo MOTO explícito, flujo focal y bloqueo de aceptación |
| 2026-10-02 | Nuevo | Flujo backend de solicitudes y aceptación DELIVERY (Task 3) |
| 2026-10-02 | Arreglo | Correcciones directas de Task 2: OSRM sin fallback y validación de rutas |
| 2026-10-02 | Nuevo | Precio DELIVERY por OSRM y límite de adelanto del repartidor (Task 2) |
| 2026-10-02 | Arreglo | Correcciones del reviewer para Task 1 DELIVERY |
| 2026-10-02 | Nuevo | Modelo backend y catálogo DELIVERY (Task 1) |
| 2026-10-02 | 📚 | DELIVERY: spec rediseñada y consolidada con precio, códigos, compra, límites, estados, cancelaciones y resolución administrativa |
| 2026-10-02 | 📚 | Diseño del módulo DELIVERY (fase 1): completadas y decididas las reglas de cancelación; spec limpiada y reescrita |
| 2026-10-02 | 🔧 | Puesta en marcha local: se crea application-xexel.properties y se corrige el .env (correo SMTP movido a properties, contraseña real de la BD) |
| 2026-10-02 | 📚 | Diseño del módulo Fletes (spec para retomar en otra sesión): categoría FLETE, datos_flete, chat efímero con fotos por REST |

## 2026-10-05

### ✨ Nuevo · Task 8 DELIVERY: panel administrativo y contratos de evidencia

- **Módulo / área:** backend (`communication`, `trip`) y admin-panel (`reportes`, `expediente`).
- **Descripción:** se completó la consulta administrativa de incidentes DELIVERY con evidencia operativa y resolución documentada, sin movimientos automáticos de dinero ni lectura del chat efímero.
- **Cambios clave:** códigos de recogida y entrega de exactamente ocho dígitos aleatorios e independientes; contrato administrativo enriquecido con contacto, tipo de envío y evidencia; límite de adelanto visible en expedientes; menú, listado, filtros, detalle responsive, foto de falla y modal de resolución con tipos y observación.
- **Archivos afectados:** `backend/src/main/java/com/taxiuap/backend/trip/entity/DatosEntrega.java`, `backend/src/main/java/com/taxiuap/backend/trip/dto/ValidarCodigoEntregaRequest.java`, `backend/src/main/java/com/taxiuap/backend/trip/service/SolicitudViajeService.java`, `backend/src/main/java/com/taxiuap/backend/communication/dto/ReporteResponse.java`, `backend/src/main/java/com/taxiuap/backend/communication/service/ReporteService.java`, `admin-panel/lib/core/menu.dart`, `admin-panel/lib/core/rutas.dart`, `admin-panel/lib/modulos/expediente/modelos.dart`, `admin-panel/lib/modulos/expediente/expediente_conductor.dart`, `admin-panel/lib/modulos/reportes/modelos.dart`, `admin-panel/lib/modulos/reportes/reportes_api.dart`, `admin-panel/lib/modulos/reportes/pantalla_reportes_entrega.dart`.
- **Verificación:** revisión de código y diff; pruebas, análisis, builds y pruebas manuales quedaron diferidos por instrucción explícita de la tarea.

### ✨ Nuevo · Flujo DELIVERY del repartidor

- **Módulo / área:** app-movil (`conductor/viaje`).
- **Descripción:** se añadieron acciones de recogida, coordinación de compra, registro de costo, pago, entrega y reportes con evidencia.
- **Cambios clave:** códigos no expuestos en respuestas, validación visual de códigos de ocho dígitos, recibo opcional, advertencia por paquete no coincidente y regla visual de diez minutos/dos intentos.
- **Archivos afectados:** `app-movil/lib/comun/modelos_viaje.dart`, `app-movil/lib/core/cliente_api.dart`, `app-movil/lib/modulos/conductor/viaje/acciones_delivery.dart`, `app-movil/lib/modulos/conductor/viaje/conductor_api.dart`, `app-movil/lib/modulos/conductor/viaje/flujo_conductor.dart`, `app-movil/lib/modulos/conductor/viaje/panel_delivery_conductor.dart`, `app-movil/lib/modulos/conductor/viaje/paneles_conductor.dart`, `app-movil/test/acciones_delivery_conductor_test.dart`.
- **Verificación:** no se ejecutaron tests, análisis, build ni pruebas manuales por instrucción de la tarea.

### 🐛 Arreglo · Correcciones de revisión Task 6 DELIVERY

- **Módulo / área:** app-movil (`pasajero/viaje`), modelos y formulario responsive.
- **Descripción:** se corrigieron hallazgos de revisión del flujo DELIVERY del pasajero.
- **Cambios clave:** aceptación de prohibiciones en ambos tipos, etiquetas de precio fijo/estimado/definitivo, estado y evidencia de reporte disponibles, pantalla completa bajo 600 px.
- **Archivos afectados:** `app-movil/lib/comun/modelos_viaje.dart`, `app-movil/lib/modulos/pasajero/viaje/formulario_entrega.dart`, `app-movil/lib/modulos/pasajero/viaje/paneles_pasajero.dart`, `app-movil/test/entrega_test.dart`.
- **Verificación:** `flutter test test/entrega_test.dart`, `flutter test`, `flutter analyze`, `flutter build web --no-tree-shake-icons`.

### ✨ Nuevo · Task 6: flujo DELIVERY para pasajero

- **Módulo / área:** app-movil (`pasajero/viaje`), modelos, API y paneles.
- **Descripción:** selección de encomienda o compra y entrega, captura de datos y seguimiento del pedido.
- **Cambios clave:** validación de remitente/receptor, descripción, monto estimado, política de artículos, estados, desglose y cancelación bloqueada en `EN_MANO`; categoría DELIVERY resuelta desde el catálogo público.
- **Archivos afectados:** `app-movil/lib/comun/modelos_viaje.dart`, `app-movil/lib/modulos/pasajero/inicio/pantalla_inicio.dart`, `app-movil/lib/modulos/pasajero/viaje/formulario_entrega.dart`, `app-movil/lib/modulos/pasajero/viaje/flujo_pasajero.dart`, `app-movil/lib/modulos/pasajero/viaje/paneles_pasajero.dart`, `app-movil/lib/modulos/pasajero/viaje/viaje_api.dart`, `app-movil/test/entrega_test.dart`.
- **Verificación:** `flutter test`, `flutter analyze`, `flutter build web --no-tree-shake-icons`.

### ✨ Nuevo · Task 5: reportes y administración de incidentes DELIVERY

- **Módulo / área:** backend (`communication`, `trip`, `controller/admin`), administración DELIVERY.
- **Descripción:** las fallas de entrega crean un reporte pendiente transaccional; el administrador puede consultarlo, ver su evidencia y registrar resolución sin mover dinero ni suspender automáticamente.
- **Cambios clave:** resolución con tipo, observación, fecha e identidad; advertencia `PAQUETE_NO_COINCIDE`; descarga de foto bajo `/api/admin/reportes/**`.
- **Archivos afectados:** `backend/src/main/java/com/taxiuap/backend/communication`, `backend/src/main/java/com/taxiuap/backend/trip/service/EntregaService.java`, `backend/src/main/java/com/taxiuap/backend/controller/admin/ReporteAdminController.java`, pruebas focalizadas de reportes.
- **Verificación:** `SPRING_PROFILES_ACTIVE=appu ./gradlew test --console=plain --tests 'com.taxiuap.backend.trip.service.EntregaServiceFallaTest' --tests 'com.taxiuap.backend.communication.service.ReporteDeliveryTest'` (4 tests, BUILD SUCCESSFUL); suite completa intentada, con 12 fallos de contexto PostgreSQL/Dialect fuera de esta tarea.

## 2026-10-04

### 🆕 Nuevo · Task 4: transiciones, códigos, compra, entrega y cancelación DELIVERY

- **Módulo / área:** backend (`trip`, `shared/archivo`), dominio DELIVERY.
- **Descripción:** `DatosEntrega.estado_entrega` dejó de ser decorativo. Cada transición tiene su acción y su condición: aceptar el pedido lleva la solicitud a `EN_CAMINO_RECOGIDA`, el código de recogida o la compra confirmada llevan el pedido a `EN_MANO` con el viaje en `EN_CURSO`, el código de entrega o la identidad del receptor con el pago confirmado lo llevan a `ENTREGADO` con el viaje `COMPLETADO`, y "No se pudo entregar" deja `NO_ENTREGADO` con foto y motivo, cancela y no republica.
- **Validación atómica:** los códigos se comparan en la base de datos con UPDATE condicionales de estado y código (`avanzarSiCodigoRecogidaCoincide`, `avanzarSiCodigoEntregaCoincide`, `avanzarSiEstadoPermitido`, `registrarFallaSiEstadoPermitido`), nunca leyendo y guardando. Una doble pulsación o dos pantallas simultáneas hacen que solo una gane. La falla escribe estado y evidencia en la misma sentencia para que no exista un `NO_ENTREGADO` sin foto ni motivo.
- **Compra y pago:** el repartidor propone el comercio y el monto, el cliente lo confirma, y solo entonces se compra. Si el costo real supera al confirmado hay que volver a proponer y volver a confirmar; el recorrido hasta el comercio no se cobra y el precio del servicio se recalcula desde el comercio hasta el destino. El repartidor registra el pago directo (producto + servicio) y el servidor exige que el monto sea exactamente el total a cobrar. El comprobante de compra y la foto de falla son archivos opcionales y obligatorios respectivamente, guardados en la carpeta de entrega del repartidor.
- **Cancelaciones:** con el pedido `EN_MANO` ni el cliente ni el repartidor pueden cancelar: hay que reportar la falla. La cancelación temprana del repartidor republica conservando códigos y comercio propuesto, pero limpiando lo que el repartidor hizo; la del cliente no cobra ni compensa nada. `iniciar` y `finalizar` genéricos rechazan los viajes DELIVERY.
- **Cambios clave:** columnas nuevas `compra_confirmada_por_cliente`, `costo_producto_confirmado`, `pago_confirmado` y `monto_pago_recibido` (creadas por `ddl-auto=update`, sin SQL ni Flyway); invariantes `@AssertTrue` en `DatosEntrega`; `DatosEntregaResponse` expone al repartidor el comercio, los montos y los puntos en WKT, y sigue sin exponerle los códigos; `PuntoDesdeWkt` evita duplicar el parseo de coordenadas; endpoints de entrega en `ViajeConductorController` y `ViajePasajeroController`.
- **Pruebas:** 52 pruebas nuevas (baseline 107 → 159). RED observado en cada slice; las pruebas contra PostgreSQL real encontraron dos bugs de producción que las unitarias no veían (un `@Enumerated` sobre un `Boolean` y columnas `NOT NULL` sin default que `ddl-auto=update` no podía agregar). Suite completa: **159 pruebas, 0 fallos, 0 errores, 0 omitidas**.
- **Fuera de alcance:** la creación del `Reporte` del incidente de falla de entrega es Task 5.
- **Archivos afectados:** `backend/src/main/java/com/taxiuap/backend/trip/service/EntregaService.java`, `PuntoDesdeWkt.java`, `ViajeService.java`, `SolicitudViajeService.java`, `trip/repository/DatosEntregaRepository.java`, `trip/entity/DatosEntrega.java`, `trip/dto/` (cinco requests nuevos y `DatosEntregaResponse`), `controller/conductor/ViajeConductorController.java`, `controller/pasajero/ViajePasajeroController.java`, `shared/archivo/AlmacenamientoArchivos.java`; pruebas en `trip/service`, `trip/entity`, `trip/dto` y `trip/repository`; `.superpowers/sdd/2026-10-02-delivery-implementation-plan/task-4-report.md`.

### 🐛 Arreglo · Cierre de hallazgos de Task 3 DELIVERY

- **Módulo / área:** backend (`trip`, `pricing`, `seed`).
- **Descripción:** ENCOMIENDA ahora fija al crear el precio del servicio calculado por OSRM A -> B e ignora el precio enviado por el cliente. Un fallo de OSRM impide persistir la solicitud. COMPRA_Y_ENTREGA calcula al asignar el GPS actual del repartidor -> B, persiste el snapshot en `SolicitudViaje.precioSugerido` y expone `precioEstimado`; no se agregó ninguna columna ni se implementó la compra de Task 4.
- **Cambios clave:** Las respuestas de solicitud, oferta y viaje usan el snapshot DELIVERY en lugar del precio fijo genérico; el viaje usa exclusivamente precios de `CalculoPrecioDeliveryService`, conserva una tarifa vigente solo como FK requerida y selecciona una moto DELIVERY activa. La aceptación por oferta vuelve a comprobar aprobación, vehículo compatible y límite de adelanto. La comisión DELIVERY usa la configuración propia (0% por defecto) y solo el precio del servicio.
- **Seed:** nueva tarifa DELIVERY idempotente, leída de las propiedades `taxiuap.delivery.*`; se asegura también cuando el seeder normal omite la carga porque ya hay datos de prueba.
- **Archivos afectados:** `backend/src/main/java/com/taxiuap/backend/pricing/service/CalculoPrecioService.java`, `backend/src/main/java/com/taxiuap/backend/seed/SeedOrquestador.java`, `SeedPrecios.java`, `SeedTarifaDelivery.java`, `backend/src/main/java/com/taxiuap/backend/trip/dto/SolicitudViajeResponse.java`, `ViajeResponse.java`, `backend/src/main/java/com/taxiuap/backend/trip/service/OfertaViajeService.java`, `SolicitudViajeService.java`, `ViajeService.java`; pruebas DELIVERY en `backend/src/test/java/com/taxiuap/backend/seed/` y `backend/src/test/java/com/taxiuap/backend/trip/service/`; `.superpowers/sdd/2026-10-02-delivery-implementation-plan/task-3-report.md`.
- **Verificación:** RED observado antes de implementar: 15 pruebas, 8 fallos de comportamiento esperados. GREEN focalizado: 25 pruebas con `BUILD SUCCESSFUL`; `compileJava` y `compileTestJava` correctos. Suite completa: 102 pruebas, 3 fallos durante el arranque de contexto por `DataSourceBeanCreationException`; la prueba de aceptación con persistencia también queda bloqueada por la misma configuración de base de datos. No se declara cobertura ejecutada de concurrencia.

### 🐛 Arreglo · Fix round 2: tarifa de aceptación independiente del seeder

- **Módulo / área:** backend (`pricing`, `trip`, `seed`).
- **Descripción:** La aceptación DELIVERY ahora crea on-demand una tarifa vigente de referencia con `zona=null` si no hay tarifa vigente usable. Primero respeta la tarifa administrativa aplicable y después cualquier otra tarifa administrada vigente; la referencia técnica nunca determina el precio del cliente, que sigue siendo OSRM.
- **Cambios clave:** el seeder de inicio queda como conveniencia; el flujo no depende de `seed.habilitado`, zona `Centro` ni de que la categoría existiera al arrancar. Los defaults configurables de base/km/minuto pasan a `4.00/1.80/0.20`, iguales a MOTO en `SeedPrecios`. La placa en la respuesta de oferta DELIVERY se selecciona entre motos DELIVERY activas. La referencia zona nula queda fuera del listado administrativo por zona y su respuesta por ID no falla.
- **Pruebas:** RED observado para tarifa ausente, defaults cero y placa estándar incorrecta. GREEN focal no-DB: `BUILD SUCCESSFUL`. Se añadieron una prueba de aceptación persistida con categoría creada después del arranque y una prueba PostgreSQL concurrente de ganador único; ambas se compilaron pero quedaron **NOT RUN / BLOCKED** hasta que el usuario inicie Docker. No se inició Docker ni se intentó PostgreSQL.
- **Archivos afectados:** `backend/src/main/java/com/taxiuap/backend/pricing/service/CalculoPrecioService.java`, `CalculoPrecioDeliveryService.java`, `backend/src/main/java/com/taxiuap/backend/seed/SeedTarifaDelivery.java`, `backend/src/main/java/com/taxiuap/backend/trip/service/OfertaViajeService.java`, `backend/src/main/resources/application-xexel.properties.example`, pruebas de `pricing`, `seed` y `trip`, `.superpowers/sdd/2026-10-02-delivery-implementation-plan/task-3-report.md`.

## 2026-10-02

### 📚 Documentación · Pausa de implementación DELIVERY en Task 3

- **Módulo / área:** backend DELIVERY (`trip`, `vehicle`, `pricing`) y SDD.
- **Descripción:** Se detuvo la implementación por solicitud del usuario después de
  completar el implementer de Task 3 y antes de su re-review. El trabajo queda
  documentado para continuar sin repetir contexto.
- **Estado:** Tasks 1 y 2 están implementadas y aprobadas por reviewer. Task 3 tiene
  los commits `662de56` y `cee202b`; el segundo corrige los hallazgos del reviewer,
  pero todavía falta ejecutar la re-review. Tasks 4 a 8 no comenzaron.
- **Cambios clave ya implementados:** modelo `DatosEntrega` y categoría DELIVERY;
  precios OSRM sin fallback a línea recta; límite de adelanto del repartidor; creación,
  visibilidad, filtrado, republicación y aceptación DELIVERY; validación explícita
  MOTO y bloqueo pesimista del conductor.
- **Archivos afectados:** `docs/superpowers/plans/2026-10-02-delivery-implementation-plan.md`,
  `docs/CHANGELOG.md`, `.superpowers/sdd/2026-10-02-delivery-implementation-plan/progress.md`.
- **Verificación:** commits `6bad27a`, `f4d1213`, `2f308bf`, `964cf19`, `662de56` y
  `cee202b`; `compileJava` y suites focalizadas reportadas como correctas. La suite
  backend completa continúa condicionada por la configuración/credenciales locales
  de PostgreSQL.

### ✨ Nuevo · Correcciones reviewer Task 3 DELIVERY

- **Módulo / área:** backend (`trip`, `vehicle`, `identity`)
- **Descripción:** se corrigió la validación de vehículos DELIVERY y se amplió la cobertura del flujo de solicitud, visibilidad, republicación y serialización de aceptación.
- **Cambios clave:** validación explícita de tipo `MOTO`; pruebas de ENCOMIENDA, COMPRA_Y_ENTREGA, límite insuficiente, republicación y bloqueo pesimista del conductor.
- **Archivos afectados:** `backend/src/main/java/com/taxiuap/backend/vehicle/entity/Vehiculo.java`, servicios `trip`, pruebas de flujo DELIVERY y `ConductorRepositoryLockTest`, `.superpowers/sdd/2026-10-02-delivery-implementation-plan/task-3-report.md`.
- **Verificación:** `./gradlew compileJava`; suite focalizada Task 3 con `BUILD SUCCESSFUL`.

### ✨ Nuevo · Flujo backend de solicitudes y aceptación DELIVERY

- **Módulo / área:** backend (`trip`)
- **Descripción:** se integró la creación, visibilidad y aceptación de solicitudes DELIVERY para ENCOMIENDA y COMPRA_Y_ENTREGA.
- **Cambios clave:** códigos independientes para encomiendas; compra sin precio definitivo inicial; filtro por moto DELIVERY, aprobación y límite de adelanto; datos de entrega en respuestas y republicación con reinicio de datos operativos.
- **Archivos afectados:** `backend/src/main/java/com/taxiuap/backend/trip/service/SolicitudViajeService.java`, `OfertaViajeService.java`, `ViajeService.java`, DTOs de `trip`, `backend/src/test/java/com/taxiuap/backend/trip/dto/DatosEntregaResponseDeliveryTest.java`.
- **Verificación:** `./gradlew compileJava`; tests focalizados DELIVERY y DTO (`BUILD SUCCESSFUL`).
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

## 2026-10-02

### 🐛 Arreglo · OSRM bloquea operaciones sin ruta válida

- **Módulo / área:** app móvil y backend (`pricing`, `mapa`)
- **Descripción:** se eliminó el fallback móvil a línea recta cuando OSRM falla y se validaron distancia, duración y geometría antes de usar una ruta.
- **Cambios clave:** `RutaNoDisponibleException` en el móvil, validación de `RutaResponse` y pruebas de respuestas OSRM negativas.
- **Archivos afectados:** `app-movil/lib/mapa/servicios_mapa.dart`, `backend/src/main/java/com/taxiuap/backend/pricing/dto/RutaResponse.java`, `backend/src/test/java/com/taxiuap/backend/pricing/service/ClienteOsrmTest.java`, `.superpowers/sdd/2026-10-02-delivery-implementation-plan/task-2-report.md`.
- **Verificación:** `./gradlew test --tests 'com.taxiuap.backend.pricing.service.*'`, `./gradlew compileJava`, `flutter test` (70 pruebas Dart).

### ✨ Nuevo · Precio DELIVERY por OSRM y límite de adelanto

- **Módulo / área:** backend (`pricing`, `identity`) y app móvil (`core`, `mapa`)
- **Descripción:** se implementó el cálculo de precios DELIVERY por rutas de calles y la configuración editable del límite que el repartidor adelanta para compras.
- **Cambios clave:** cliente OSRM con timeout y respuesta tipada; precios A-B, GPS-B y comercio-B; fallo de OSRM sin respaldo en línea recta; comisión DELIVERY configurable con valor inicial 0% solo sobre el servicio; filtro reutilizable por límite de adelanto; URL de OSRM configurable en la app.
- **Archivos afectados:** `backend/src/main/java/com/taxiuap/backend/pricing/dto/RutaResponse.java`, `backend/src/main/java/com/taxiuap/backend/pricing/dto/DesglosePrecioDelivery.java`, `backend/src/main/java/com/taxiuap/backend/pricing/service/ClienteRutas.java`, `backend/src/main/java/com/taxiuap/backend/pricing/service/ClienteOsrm.java`, `backend/src/main/java/com/taxiuap/backend/pricing/service/CalculoPrecioDeliveryService.java`, `backend/src/main/java/com/taxiuap/backend/identity/dto/ActualizarPerfilConductorRequest.java`, `backend/src/main/java/com/taxiuap/backend/identity/service/PerfilConductorService.java`, `backend/src/main/resources/application-xexel.properties`, `backend/src/main/resources/application-xexel.properties.example`, `app-movil/lib/core/config.dart`, `app-movil/lib/mapa/servicios_mapa.dart`, pruebas focalizadas.
- **Verificación:** `./gradlew test --tests 'com.taxiuap.backend.pricing.service.*'`, `./gradlew compileJava`; `./gradlew test` ejecutó 77 pruebas y quedó bloqueado por 2 fallos de autenticación/configuración PostgreSQL local.

## Convenciones

- **Fecha:** `YYYY-MM-DD` (no usar texto suelto).
- **Verificación:** cada entrada debe indicar cómo se validó el cambio.
- **Fuente de verdad:** este archivo se mantiene al día al finalizar cada tarea.

---

## 2026-10-02

### Arreglo · Correcciones del reviewer para Task 1 DELIVERY

- **Módulo / área:** backend (`vehicle`, `identity`, `trip`, `seed`)
- **Descripción:** Se cerraron las brechas de validación y persistencia detectadas en la revisión del modelo DELIVERY.
- **Cambios clave:** DELIVERY queda bloqueado para tipos no MOTO en creación/actualización de vehículos y alta de moto; el límite de adelanto es obligatorio y no negativo; COMPRA_Y_ENTREGA exige costo estimado positivo en request y entidad; se agregó prueba JPA real de relación 1-1 y FK única; se corrigió el contador del seeder.
- **Archivos afectados:** `backend/src/main/java/com/taxiuap/backend/vehicle/service/VehiculoService.java`, `backend/src/main/java/com/taxiuap/backend/vehicle/service/RegistroMotoConductorService.java`, `backend/src/main/java/com/taxiuap/backend/identity/entity/Conductor.java`, `backend/src/main/java/com/taxiuap/backend/trip/dto/DatosEntregaRequest.java`, `backend/src/main/java/com/taxiuap/backend/seed/SeedCatalogos.java`, pruebas DELIVERY y reporte Task 1
- **Verificación:** `TAXIUAP_DB_PASSWORD='<12346578>' ./gradlew test --tests '*Entrega*'`; `./gradlew compileJava`; `TAXIUAP_DB_PASSWORD='<12346578>' ./gradlew test`.

### Nuevo · Modelo backend y catálogo DELIVERY

- **Módulo / área:** backend (`trip`, `vehicle`, `identity`, `seed`)
- **Descripción:** Se agregó el modelo persistente inicial para pedidos DELIVERY y la categoría exclusiva para motos.
- **Cambios clave:** Se crearon `DatosEntrega`, `TipoEnvio`, `EstadoEntrega`, repositorio y DTOs; se relacionaron los datos 1-1 con `SolicitudViaje`; se agregaron validaciones de costos, códigos, evidencia y política de encomiendas; se agregó el límite de adelanto al conductor; el catálogo y seed incluyen `DELIVERY` y asignan una moto de prueba a esa categoría.
- **Archivos afectados:** `backend/src/main/java/com/taxiuap/backend/trip/`, `backend/src/main/java/com/taxiuap/backend/vehicle/`, `backend/src/main/java/com/taxiuap/backend/identity/`, `backend/src/main/java/com/taxiuap/backend/seed/`, `backend/src/test/java/com/taxiuap/backend/trip/`, `backend/src/test/java/com/taxiuap/backend/vehicle/`
- **Verificación:** `./gradlew test --tests '*Entrega*'` pasa; `./gradlew compileJava` pasa; `./gradlew test` ejecuta 67 pruebas y falla solo `TaxiuapApplicationTests.contextLoads()` por credenciales locales de PostgreSQL.

### 📚 Documentación · Spec DELIVERY rediseñada y consolidada

- **Módulo / área:** docs (`docs/superpowers/specs/`)
- **Descripción:** Se consolidaron las respuestas de la sesión en un diseño completo
  para DELIVERY, eliminando ambigüedades de precio, recorrido, compra, códigos,
  límites del repartidor, estados, cancelaciones y resolución de incidentes.
- **Cambios clave:** ENCOMIENDA fija precio A -> B al crear y usa códigos separados
  de recogida y entrega; COMPRA_Y_ENTREGA muestra estimado desde el GPS del repartidor
  y fija comercio -> B al confirmar la compra; el repartidor configura su límite de
  adelanto; no se aceptan diferencias de precio sin confirmación; se reutilizan estados
  de viaje con `estado_entrega`; cancelaciones tempranas no compensan ni repúblican
  después de tener el pedido; fallos exigen foto, motivo y reporte; el admin registra la
  resolución fuera de la app, sin pasarela de pagos; comisión inicial DELIVERY de 0%.
- **Archivos afectados:** docs/superpowers/specs/2026-10-02-delivery-design.md,
  docs/CHANGELOG.md
- **Verificación:** lectura completa del spec; `git diff --check --
  docs/superpowers/specs/2026-10-02-delivery-design.md` sin errores.

### 📚 Documentación · Spec del módulo DELIVERY: cancelaciones decididas

- **Módulo / área:** docs (`docs/superpowers/specs/`)
- **Descripción:** Se revisó junto con el usuario el spec del módulo DELIVERY (que
  estaba con secciones corruptas y cancelaciones PENDIENTE-DECISION). Se discutieron y
  decidieron las reglas de cancelación y se reescribió/limpió el documento completo.
- **Cambios clave:** decisiones de la sección 6: (1) cliente bloqueado de cancelar
  cuando el repartidor ya tiene el pedido en mano ("Ya tengo el pedido" ->
  `estado_entrega = EN_MANO`); (2) repartidor con el pedido en mano solo puede usar
  "No se pudo entregar" con foto + motivo obligatorios, viaje CANCELADO, sin
  república de la solicitud; (3) código de entrega de 6 dígitos solo para ENCOMIENDA;
  (4) todo "No se pudo entregar" crea un reporte automático PENDIENTE para el admin
  (foto, motivo, costo_producto_real, dirección B, teléfono) que resuelve devolución/
  pago/pérdida fuera de la app, porque en fase 1 no hay pasarela de pagos y el dinero
  es directo. Además se agregó al spec el enum `estado_entrega`
  (PENDIENTE_COMPRA/EN_MANO/ENTREGADO/NO_ENTREGADO) como campo de datos_entrega y
  `foto_falla_url`/`motivo_falla`. El spec ya cancela la ambigüedad previa y sirve de
  base para el plan de implementación.
- **Archivos afectados:** docs/superpowers/specs/2026-10-02-delivery-design.md,
  docs/CHANGELOG.md
- **Verificación:** lectura del documento final en pantalla (texto completo, sin
  secciones corruptas; tabla de cancelaciones y fuera de alcance coherentes con lo
  decidido).

### 📚 Documentación · Spec del módulo Fletes

- **Módulo / área:** docs (`docs/superpowers/specs/`)
- **Descripción:** Se diseñó con el usuario el módulo de fletes (decisión: Opción A en
  todo: categoría FLETE sobre vehículos CAMIONETA/CAMION, flujo solicitud-oferta-viaje
  reutilizado, datos_flete 1-1 con solicitud_viaje, chat efímero con banner y fotos por
  REST). Se dejó la spec escrita para poder retomar el diseño y el plan de
  implementación en una sesión futura sin repetir conversaciones.
- **Archivos afectados:** `docs/superpowers/specs/2026-10-02-fletes-design.md`
- **Verificación:** revisión de la spec (sin "TBD", coherente con el diseño discutido);
  el usuario falta por dar el visto bueno explícito al archivo.

### 🔧 Config · Puesta en marcha local del backend

- **Módulo / área:** backend (configuración) y raíz del monorepo (`.env`)
- **Descripción:** El proyecto no arrancaba: faltaba `application-xexel.properties` (solo
  existía el `.example`, por lo que no había datasource) y el `.env` tenía pegadas
  propiedades de Spring (`spring.mail.*`) que ahí no tienen efecto, porque el `.env` solo
  define variables de entorno (las carga `bootRun` en `backend/build.gradle`).
- **Cambios clave:**
  - Se corrigió `.env`: solo variables (`TAXIUAP_DB_PASSWORD`,
    `MAIL_HOST/MAIL_PORT/MAIL_USUARIO/MAIL_PASSWORD/MAIL_REMITENTE`, Google,
    Firebase, Gemini); las líneas `spring.mail.*` se quitaron.
  - Se creó `application-xexel.properties` (gitignored; no versionar): datasource
    5436/taxiuap, JWT por defecto del `application.properties`, CORS 5173, admin inicial,
    SMTP Google con los valores del `.env`, seed habilitado.
  - La contraseña real de la BD es la del contenedor `taxiuap-db` ya en ejecución
    (proyecto UniTaxi-V0.2, cuyo directorio fue borrado pero el contenedor sigue vivo).
- **Archivos afectados:** `.env`, `backend/src/main/resources/application-xexel.properties`,
  `docs/CHANGELOG.md`.
- **Verificación:** `./gradlew bootRun` arrancó en 8080 ("Started TaxiuapApplication");
  `GET /api/publico/instituciones` devolvió HTTP 200 con las 3 instituciones; la BD
  conserva los datos (16 personas, 29 viajes).

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

## [Ronda corrección Task 4] — 2026-10-04

### Cambios en backend
- `trip/entity/DatosEntrega`: añadido `@Size(max=500)` a `motivoFalla` (coherente con columna `length=500`).
- `trip/repository/DatosEntregaRepository`: nuevo método `confirmarPagoSiEnMano` con UPDATE condicional nativo y `clearAutomatically/flushAutomatically` para evitar escritura completa que borre evidencia en transiciones concurrentes.
- `trip/service/EntregaService`: `confirmarPago` utiliza UPDATE condicional; si no actualiza filas, distingue entre estado cambiado y pago ya confirmado.
- Tests: `DatosEntregaTest` añade `rechazaMotivoDeFallaMuyLargo()`; `DatosEntregaDtoTest` amplía aserciones; `EntregaServiceRecogidaEntregaTest` ajustado para nuevo flujo.

### Decisión sobre pago parcial
- Según `docs/superpowers/specs/2026-10-02-delivery-design.md`, el flujo exige pago **total** (producto+servicio) y validación exacta. No se implementa registro de pago parcial/no pago; queda como pregunta abierta para revisión futura.

### Verificación
- Suite completa con perfil `appu`: `tests=160 failures=0 errors=0 skipped=0` (1 test añadido). BUILD SUCCESSFUL.

## [Sesion 2026-10-05] — sin cambios de codigo

- Se cerro la pregunta abierta del pago parcial: **se mantiene el spec**, el repartidor
  registra el total exacto y no hay campo de monto parcial. Si el cliente no paga todo, el
  repartidor usa "No se pudo entregar" con foto y motivo.
- Se documento en `docs/superpowers/2026-10-05-entrega-handoff.md` el estado de la fase 1 de
  DELIVERY: Tasks 1-4 implementadas, cierre de Task 4 pendiente (los dos hallazgos
  importantes siguen abiertos, no se alcanzo a despachar el implementador) y Task 5 en
  adelante.
- Se confirmo que el repartidor es el mismo `Conductor` con moto de categoria DELIVERY y su
  campo `limite_adelanto_compra`, no un actor nuevo.
