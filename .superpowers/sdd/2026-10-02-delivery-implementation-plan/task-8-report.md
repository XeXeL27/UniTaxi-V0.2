# Reporte Task 8: Panel administrativo y pruebas end-to-end

## Qué implementé

- Los códigos DELIVERY de recogida y entrega quedaron alineados con el contrato vigente de **exactamente 6 dígitos aleatorios**, con dos códigos distintos por encomienda e independientes de teléfono, CI e identificadores. Corrección 2026-10-05 (commit `4b9b463`): este reporte decía "ocho dígitos", que fue el error corregido; el texto original queda suplido por esta línea.
- Extendí el contrato administrativo de reportes con tipo de envío, descripción, contacto, destino, costo real y evidencia de compra/falla.
- Permití resolver reportes pendientes o en revisión sin ejecutar movimientos de dinero.
- Mostré el límite de adelanto para compras en el expediente administrativo del conductor y mantuve visible la categoría de servicio del vehículo, incluida DELIVERY.
- Agregué al panel el menú y ruta de reportes de entrega, listado con búsqueda/filtros locales por situación y tipo, detalle responsive con evidencia, contacto e historial de resolución, y modal de resolución con los tipos definidos y observación.
- El panel no incorpora acceso al chat efímero; únicamente consulta la evidencia persistida del incidente.

## Qué testee y resultados

No se ejecutaron tests, análisis estático, builds ni pruebas manuales, por instrucción explícita del usuario. Las pruebas backend de integración y los escenarios Flutter quedaron diferidos para la revisión final.

## Evidencia TDD

No se escribió ni ejecutó código de tests, conforme a la instrucción explícita de no modificar ni ejecutar tests en esta tarea.

## Archivos cambiados

- Backend: `DatosEntrega.java`, `ValidarCodigoEntregaRequest.java`, `SolicitudViajeService.java`, `ReporteResponse.java`, `ReporteService.java`.
- Admin: `core/menu.dart`, `core/rutas.dart`, `modulos/expediente/modelos.dart`, `modulos/expediente/expediente_conductor.dart`, `modulos/reportes/modelos.dart`, `modulos/reportes/reportes_api.dart`, `modulos/reportes/pantalla_reportes_entrega.dart`.
- Documentación: `docs/CHANGELOG.md`.

## Auto-revisión

- Revisé el diff de implementación sin ejecutar tests/builds.
- No toqué credenciales, `.env`, README, `application*.properties`, `task-2-report.md` ni tests existentes.
- No agregué un modelo paralelo para fotos de producto/comercio; la evidencia exigida por el flujo de fallas continúa usando `datos_entrega.foto_falla_url` y el endpoint administrativo existente.
- La resolución solo registra tipo, observación, identidad y fecha; no cambia pagos, comisiones ni saldos.

## Preocupaciones

- Las pruebas automatizadas y compilaciones quedan pendientes deliberadamente y deben ejecutarse en la revisión final.
- El cambio de longitud de columnas de códigos depende de `ddl-auto=update` para ampliar las columnas existentes en la base de datos. Corrección 2026-10-05: al pasar de 8 a 6 dígitos el problema es el inverso, `ddl-auto=update` **no** reduce columnas, así que `codigo_recogida` y `codigo_entrega` quedan como `varchar(8)` en las bases ya creadas. No molesta: los valores siguen siendo de 6 caracteres y el `@Pattern` de la entidad los valida.

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
