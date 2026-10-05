# Reporte de implementación Task 7 DELIVERY

## Implementación

- Se conectaron las acciones del repartidor con los endpoints actuales: validar recogida, proponer y registrar compra, confirmar pago, validar entrega, identificar receptor y reportar fallas.
- Se añadió el multipart para la parte JSON `compra` y el recibo opcional, además de la observación de compra.
- El panel del repartidor separa encomienda de compra y entrega, no muestra códigos provenientes del modelo y exige foto más motivo para fallas o paquete no coincidente.
- Se evitó que el GPS ejecute la finalización genérica en viajes DELIVERY y se corrigió la actualización de datos de entrega durante el sondeo.
- El resultado de una entrega completada o cancelada vuelve correctamente a la lista del conductor.
- Las solicitudes DELIVERY siguen dependiendo del filtrado backend vigente por moto y límite de adelanto; no se duplicó esa regla en la app.

## Archivos cambiados

- `app-movil/lib/comun/modelos_viaje.dart`
- `app-movil/lib/core/cliente_api.dart`
- `app-movil/lib/modulos/conductor/viaje/acciones_delivery.dart`
- `app-movil/lib/modulos/conductor/viaje/conductor_api.dart`
- `app-movil/lib/modulos/conductor/viaje/flujo_conductor.dart`
- `app-movil/lib/modulos/conductor/viaje/panel_delivery_conductor.dart`
- `app-movil/lib/modulos/conductor/viaje/paneles_conductor.dart`
- `app-movil/lib/modulos/pasajero/viaje/paneles_pasajero.dart`

## Verificación diferida

Por instrucción explícita, quedaron diferidos los tests Dart, `flutter test`, análisis, builds y pruebas manuales en Chrome. La revisión realizada fue únicamente lectura del diff y de los contratos backend existentes.

## Bloqueos y preocupaciones

- El requerimiento solicitaba códigos aleatorios de 8 dígitos y el backend generaba 6. Corrección 2026-10-05 (commit `4b9b463`): el contrato del usuario es de **exactamente 6 dígitos aleatorios e independientes** (teléfono, CI e ids no intervienen) y ahora ambos extremos están alineados: `ValidarCodigoEntregaRequest` y `DatosEntrega.PATRON_CODIGO` piden 6, `SolicitudViajeService.codigo()` genera 6, y la app valida 6 (`ValidadorCodigoDelivery`, `maxLength: 6`). Este reporte queda como registro de lo que Task 7 dejó desalineado.
- El backend actual solo expone `comprobante` opcional al registrar compra; no existe endpoint separado para foto de producto o comercio. La app no inventa ese endpoint y solo permite el recibo soportado por el contrato.
- No se modificaron ni incluyeron en el commit los tests, backend, configuración, README, reportes previos ni cambios preexistentes ajenos a Task 7.

## Commit

- `9451bb5 feat: add driver delivery flow`

---

## Fix report del verificador (2026-10-05)

Ejecutado por el agente verificador sobre la rama `HWatson-dev`, con PostgreSQL real
(contenedor `taxiuap-db`, puerto 5436). Resultado completo en
`docs/superpowers/2026-10-05-verificacion-entrega.md`.

### Qué se verificó de esta task

- Suite completa del backend y `./gradlew build`.
- Los dos casos que quedaron **NOT RUN / PENDING DOCKER** en `task-3-report.md`:
  `OfertaViajeDeliveryPersistenciaTest` y `SolicitudViajeConcurrenteDeliveryTest`.
- Recorrido end-to-end por la API de los flujos que la task afirma.

### Resultado

- `./gradlew test` → `tests=177 failures=0 errors=0 skipped=0 classes=38`, `BUILD SUCCESSFUL`.
- `./gradlew build` → `BUILD SUCCESSFUL in 25s`.
- `OfertaViajeDeliveryPersistenciaTest` **sí pasa** contra PostgreSQL: acepta la encomienda con la
  moto DELIVERY y persiste el viaje con la tarifa técnica de zona nula. Necesita que el perfil
  tenga los defaults `taxiuap.delivery.tarifa-base=4.00`, `precio-km=1.80`, `precio-minuto=0.20`;
  con `0.00` falla al comparar la base de la tarifa (no es un defecto de producción).
- `SolicitudViajeConcurrenteDeliveryTest` **sí pasa**: dos transacciones reales, un UPDATE de una
  fila y otro de cero, solicitud en `ACEPTADA`.
- Por la API, ENCOMIENDA fija precio por OSRM (16.89 en la ruta probada), genera dos códigos
  aleatorios de 6 dígitos e independientes, el repartidor DELIVERY ve la solicitud y el taxi
  ESTANDAR no, y la aceptación no devuelve los códigos.

### Defectos corregidos

- `EntregaServicePostgresTest` afirmaba `NegocioException` para un actor equivocado, pero
  `ViajeService.obtenerViajeDelConductor` responde "no encontrado" a propósito para no revelar que
  el viaje existe. Se corrigió la suposición del test (commit `9ad46fa`).
- `ReporteAdminControllerSecurityTest` usaba `@WithMockUser`, que no deja un `JwtUser` en el
  `SecurityContext`; el caso ADMIN de resolución terminaba en 500. Corregido en `9ad46fa`.
- Tres lints de `flutter analyze` de las Tasks 7 y 8 (commit `27963cb`).

### Autoverificación (lo que el handoff del 2026-10-04 pedía)

- Quitado el chequeo de propietario de `obtenerViajeDelConductor`:
  `conductorDistintoNoPuedeValidarRecogida` **falla**. La prueba de permisos ya no es vacua.
- Puesto el UPDATE de código de recogida **incondicional**: fallan **8** pruebas, incluidas
  `recorridoRealDeEncomiendaPersisteEstadoPagoYViajeEnPostgres` y las de concurrencia.
- Quitado `clearAutomatically = true` de `avanzarSiCodigoRecogidaCoincide`: **ninguna prueba
  falla**. En los caminos cubiertos no es una propiedad que cargue el estado, así que la
  preocupación del handoff queda acotada pero no cerrada por las pruebas actuales.
