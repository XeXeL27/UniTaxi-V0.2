# DELIVERY Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task, with a fresh implementer and review gate per task.

**Goal:** Implement fase 1 de DELIVERY para ENCOMIENDA y COMPRA_Y_ENTREGA en backend, app móvil y panel administrativo, sin alterar `main`.

**Architecture:** Reutilizar el flujo existente `solicitud_viaje -> oferta_viaje -> viaje`, agregando la categoría DELIVERY, la entidad `datos_entrega` y un servicio de dominio para validar transiciones, códigos, precios y fallos. La app móvil reutilizará el mapa, seguimiento, chat efímero, pagos directos y componentes de viaje actuales; el panel reutilizará tablas, expedientes y reportes existentes.

**Tech Stack:** Spring Boot 4.1.1, Java 21, JPA/PostGIS, STOMP, Flutter móvil/Web, OSRM, PostgreSQL.

**Spec:** `docs/superpowers/specs/2026-10-02-delivery-design.md`

**Estado de ejecución (2026-10-02):** Tasks 1 y 2 completadas y revisadas; Task 3
implementada y pendiente de re-review. Los commits de implementación están en
`HWatson-dev`. La continuación debe empezar generando el paquete de revisión de
`964cf19..cee202b` y despachando `task-reviewer`/`re-reviewer` según corresponda.

## Global Constraints

- Todo el código nuevo debe estar en español y seguir `controller -> service -> repository -> entity`.
- No crear SQL, Flyway ni Liquibase; Hibernate genera el esquema con `ddl-auto=update`.
- DELIVERY solo se permite para vehículos MOTO con categoría DELIVERY.
- No agregar pasarela de pagos en fase 1; el pago total es directo al repartidor en efectivo o QR.
- Comisión inicial DELIVERY: 0%; el costo del producto nunca entra en la comisión.
- Los estados actuales de `Viaje` se reutilizan; el detalle propio vive en `datos_entrega.estado_entrega`.
- Todo endpoint debe validar rol, propietario, conductor asignado y transición válida en el servidor.
- Mantener todo el trabajo en la rama `HWatson-dev`; no hacer checkout, merge ni push a `main`.

## File Map

- `backend/.../vehicle/`: categoría DELIVERY, validación MOTO y límite de adelanto del conductor.
- `backend/.../trip/`: entidad, DTOs, repositorio y servicio de datos de entrega; integración con solicitud, oferta y viaje.
- `backend/.../pricing/`: cálculo del precio DELIVERY y comisión 0%.
- `backend/.../communication/`: evidencia y resolución administrativa de reportes de entrega.
- `backend/.../controller/pasajero/` y `controller/conductor/`: endpoints de solicitud, seguimiento, compra, entrega, pago y fallo.
- `app-movil/lib/modulos/pasajero/`: creación y seguimiento de DELIVERY.
- `app-movil/lib/modulos/conductor/`: aceptación, códigos, compra, entrega, pago y fallo.
- `app-movil/lib/comun/` y `lib/core/`: modelos, API, rutas y componentes compartidos.
- `admin-panel/lib/modulos/`: configuración/consulta de DELIVERY y resolución de reportes.
- Tests junto al módulo correspondiente; pruebas de integración para transiciones y concurrencia.

---

### Task 1: Modelo backend y catálogo DELIVERY

**Files:**
- Modify: entidades, enums, repositorios y DTOs existentes de `vehicle`, `identity` y `trip`.
- Create: entidad `DatosEntrega`, enums `TipoEnvio` y `EstadoEntrega`, repositorio y DTOs.
- Modify: seeders/catalog initializer y tests de persistencia.

**Interfaces:**
- `CategoriaServicio.DELIVERY` queda disponible solo para `TipoVehiculo.MOTO`.
- `DatosEntrega` se relaciona 1-1 con `SolicitudViaje`.
- A/B siguen en `SolicitudViaje.origen/destino`; no duplicar esos campos.
- Campos mínimos: descripción, códigos separados, costo estimado/real, límite, puntos de compra, evidencia y estado.

- [ ] Agregar enums y entidad con nombres snake_case, relaciones LAZY y auditoría.
- [ ] Agregar validaciones Bean Validation y reglas de categoría MOTO.
- [ ] Actualizar seed idempotente con categoría DELIVERY y una moto de prueba.
- [ ] Escribir pruebas de entidad, restricciones y serialización de DTOs.
- [ ] Ejecutar `./gradlew test --tests '*Entrega*'` y `./gradlew compileJava`.
- [ ] Commit: `feat: add delivery domain model`.

### Task 2: Precio, OSRM y configuración del repartidor

**Files:**
- Create/modify: servicio de rutas/precio DELIVERY y DTOs de estimación.
- Modify: configuración de `API_URL`/OSRM, tarifa y comisión.
- Modify: perfil del conductor para `limite_adelanto_compra`.
- Tests unitarios del cálculo y fallos de OSRM.

**Interfaces:**
- ENCOMIENDA calcula A -> B al crear y fija el precio.
- COMPRA_Y_ENTREGA estima GPS del repartidor -> B al asignarse y fija comercio -> B al confirmar compra.
- Si OSRM falla, no se permite crear/fijar precio; no usar línea recta.
- Comisión DELIVERY inicial: 0% y solo sobre el servicio.

- [ ] Implementar cliente OSRM con timeout y respuesta tipada.
- [ ] Implementar cálculo por calles y redondeos consistentes con dinero existente.
- [ ] Exponer límite editable del repartidor y filtrar solicitudes por monto estimado.
- [ ] Añadir pruebas de A-B, GPS-B, comercio-B, OSRM fallido y comisión 0%.
- [ ] Ejecutar tests del módulo y `./gradlew test` focalizado.
- [ ] Commit: `feat: add delivery pricing and driver advance limit`.

### Task 3: Flujo backend de solicitud y aceptación

**Files:**
- Modify: `SolicitudViajeService`, `OfertaViajeService`, `ViajeService`, publishers y respuestas.
- Modify: controllers de pasajero/conductor.
- Tests de integración del flujo y visibilidad.

**Interfaces:**
- Solo conductores aprobados con moto DELIVERY ven/aceptan solicitudes DELIVERY.
- Una solicitud DELIVERY se identifica por `datos_entrega.tipo_envio` y sus respuestas no exponen datos prohibidos.
- La republicación por cancelación temprana conserva datos y códigos, pero reinicia datos operativos.

- [ ] Crear solicitud ENCOMIENDA con precio fijo y dos códigos.
- [ ] Crear solicitud COMPRA_Y_ENTREGA con estimado pendiente de conductor.
- [ ] Filtrar solicitudes por categoría, aprobación, moto y límite de adelanto.
- [ ] Integrar `datos_entrega` en respuestas, ofertas y republicación.
- [ ] Probar concurrencia de aceptación y exclusión de taxis ESTANDAR.
- [ ] Commit: `feat: add delivery request and acceptance flow`.

### Task 4: Transiciones, códigos, compra, entrega y cancelación

**Files:**
- Modify: `ViajeService` y servicios de entrega.
- Create: requests/responses/controllers específicos para acciones DELIVERY.
- Modify: publisher de seguimiento y estados.
- Tests de transición y autorización.

**Interfaces:**
- Estados: `PENDIENTE_RECOGIDA`, `EN_CAMINO_RECOGIDA`, `EN_MANO`, `ENTREGADO`, `NO_ENTREGADO`.
- Acciones: validar recogida, confirmar compra, marcar pedido en mano, completar entrega, confirmar pago y no entregar.
- ENCOMIENDA exige código de recogida y código de entrega.
- COMPRA_Y_ENTREGA exige confirmación del cliente antes de comprar y no acepta aumento sin nueva confirmación.

- [ ] Implementar validación atómica de códigos sin exponerlos indebidamente.
- [ ] Implementar confirmación de compra y `punto_compra` real.
- [ ] Implementar pago directo registrado por el repartidor.
- [ ] Bloquear cancelación del cliente con pedido EN_MANO.
- [ ] Permitir cancelación temprana sin compensación y republicar cuando corresponda.
- [ ] Implementar "No se pudo entregar": foto, motivo, cancelación y sin republicación.
- [ ] Probar códigos incorrectos, doble transición, permisos, pago y cancelaciones.
- [ ] Commit: `feat: implement delivery state transitions`.

### Task 5: Reportes y administración backend

**Files:**
- Modify: entidad/repository/service/controller de `Reporte`.
- Modify: almacenamiento de archivos y respuestas administrativas.
- Tests de reporte automático y resolución.

**Interfaces:**
- El fallo crea `Reporte.PENDIENTE` y guarda evidencia en `DatosEntrega`.
- Resoluciones: `DEVOLUCION_AL_REMITENTE`, `CLIENTE_PAGO_DIRECTO`, `REPARTIDOR_ASUME_PERDIDA`, `CLIENTE_NO_RESPONDIO`, `OTRO`.
- Admin registra observación, fecha, identidad y cierre; no mueve dinero.

- [ ] Crear reporte automático transaccional para fallo de entrega y paquete incorrecto.
- [ ] Proteger descarga de foto solo para ADMIN.
- [ ] Implementar endpoint de listado, detalle y resolución.
- [ ] Registrar advertencias por declaración incorrecta sin suspensión automática.
- [ ] Probar estados, permisos y persistencia de resolución.
- [ ] Commit: `feat: add delivery incident reports`.

### Task 6: App móvil pasajero

**Files:**
- Modify: modelos/API/solicitud de viaje del pasajero.
- Create/modify: pantallas y paneles DELIVERY.
- Modify: mapa, precio, seguimiento, pago y cancelación.
- Tests Dart de modelos, validaciones y flujo de UI donde existan patrones.

- [ ] Agregar selección ENCOMIENDA/COMPRA_Y_ENTREGA.
- [ ] Implementar formularios A/B, remitente/receptor, descripción, foto opcional y aceptación de prohibiciones.
- [ ] Implementar producto, monto estimado, confirmación de comercio/precio y estado del pedido.
- [ ] Mostrar precio fijo de ENCOMIENDA y estimado/definitivo de COMPRA_Y_ENTREGA.
- [ ] Ocultar cancelación cuando el pedido está EN_MANO.
- [ ] Mostrar seguimiento, desglose total y estados de reporte.
- [ ] Ejecutar `flutter test` y pruebas manuales en Chrome.
- [ ] Commit: `feat: add passenger delivery flow`.

### Task 7: App móvil repartidor

**Files:**
- Modify: modelos/API y pantallas del conductor.
- Create/modify: acciones de códigos, compra, pago y fallo.
- Modify: notificaciones, mapa y seguimiento.
- Tests Dart de acciones y respuestas de API.

- [ ] Mostrar solo solicitudes DELIVERY compatibles con límite y vehículo.
- [ ] Implementar código de recogida y código de entrega sin mostrar valores antes de tiempo.
- [ ] Implementar coordinación de comercio, confirmación del cliente y registro de costo real.
- [ ] Permitir recibo opcional, observación y foto de producto/comercio.
- [ ] Implementar confirmar pago, completar, esperar 10 minutos/dos intentos y no entregar.
- [ ] Implementar rechazo de paquete con evidencia y advertencia.
- [ ] Ejecutar `flutter test` y pruebas manuales en Chrome.
- [ ] Commit: `feat: add driver delivery flow`.

### Task 8: Panel administrativo y pruebas end-to-end

**Files:**
- Modify: menu, modelos/API y módulos de admin.
- Create/modify: configuración de DELIVERY, reportes e historial de incidencias.
- Tests backend integration y escenarios Flutter.

- [ ] Mostrar categoría DELIVERY y límite del repartidor en expedientes.
- [ ] Listar y filtrar reportes de entrega con evidencia.
- [ ] Implementar modal de resolución con tipos y observación.
- [ ] Verificar que admin no ve chat efímero, pero sí evidencia de incidentes.
- [ ] Ejecutar pruebas end-to-end de ambos tipos, visibilidad, compra, pago, cancelación y fallo.
- [ ] Ejecutar `./gradlew build`, `flutter test` en app móvil y builds de los paneles.
- [ ] Commit: `feat: complete delivery admin and integration tests`.

## Final Review

- [ ] Ejecutar revisión por tarea con `task-reviewer` después de cada implementer.
- [ ] Corregir hallazgos Critical/Important mediante el mismo implementer y `re-reviewer`.
- [ ] Ejecutar `code-reviewer` sobre toda la rama `HWatson-dev`.
- [ ] Actualizar `docs/CHANGELOG.md` con cada entrega real y verificada.
- [ ] Verificar que no haya commits ni cambios en `main`.
