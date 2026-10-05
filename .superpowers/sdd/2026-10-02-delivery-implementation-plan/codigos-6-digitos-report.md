# Reporte: códigos DELIVERY de seis dígitos

## Implementación

- Se actualizó la generación de códigos DELIVERY a valores aleatorios independientes de exactamente 6 dígitos, conservando la comprobación de desigualdad entre recogida y entrega.
- Se ajustaron la validación backend, las longitudes de columnas y la validación/interfaz de la app móvil.
- Se actualizaron únicamente los literales del test pendiente existente para usar códigos de 6 dígitos.

## Archivos

- `backend/src/main/java/com/taxiuap/backend/trip/service/SolicitudViajeService.java`
- `backend/src/main/java/com/taxiuap/backend/trip/dto/ValidarCodigoEntregaRequest.java`
- `backend/src/main/java/com/taxiuap/backend/trip/entity/DatosEntrega.java`
- `app-movil/lib/modulos/conductor/viaje/acciones_delivery.dart`
- `app-movil/lib/modulos/conductor/viaje/panel_delivery_conductor.dart`
- `backend/src/test/java/com/taxiuap/backend/trip/service/EntregaServicePostgresTest.java`

## Verificación

Queda diferida según la solicitud: no se ejecutaron tests, Gradle, Flutter, analyze ni build.

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
