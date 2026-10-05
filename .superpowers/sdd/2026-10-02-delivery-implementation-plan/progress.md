# SDD ledger — plan: docs/superpowers/plans/2026-10-02-delivery-implementation-plan.md

## Pre-flight scan

| Elemento | Interfaces/archivos compartidos | Resultado |
|---|---|---|
| Task 1 -> Task 2 | `DatosEntrega`, categoría DELIVERY, límite del conductor | Task 1 produce el modelo que Task 2 consume; consistente |
| Task 1 -> Task 3 | DTOs de solicitud y categoría | Task 3 consume el modelo y la visibilidad; consistente |
| Task 2 -> Task 3 | servicio de precio y filtro por límite | Task 3 usa precio estimado y elegibilidad; consistente |
| Task 3 -> Task 4 | `SolicitudViajeService`, `ViajeService`, respuestas | Task 4 agrega transiciones sobre el flujo producido por Task 3; consistente |
| Task 4 -> Task 5 | `NO_ENTREGADO`, evidencia y `Reporte` | Task 5 persiste la salida del fallo de Task 4; consistente |
| Task 4 -> Task 6/7 | endpoints y estados DELIVERY | Las apps consumen contratos del backend; consistente |
| Task 5 -> Task 8 | endpoints de reportes y resolución | El panel consume el contrato administrativo; consistente |

### Rulings

- `Ruling: trabajar primero backend y después Flutter` — las apps dependen de DTOs y endpoints estables; el costo si falla es re-trabajo de contratos, por eso Task 6/7 esperan Task 4.
- `Ruling: no incluir cambios de application.properties` — existe una modificación local ajena con una clave JWT hardcodeada; el costo si se ignorara es publicar un secreto.
- `Ruling: no usar agentes en paralelo para implementación` — las tareas comparten entidades, servicios y DTOs; el costo de paralelizar sería conflicto y contratos divergentes.

## Estado

- Task 1: pendiente
- Task 2: pendiente
- Task 3: pendiente
- Task 4: pendiente
- Task 5: pendiente
- Task 6: pendiente
- Task 7: pendiente
- Task 8: pendiente

## Task 1 review

- Reviewer: Needs fixes.
- Important: garantizar DELIVERY solo sobre MOTO en todas las rutas de persistencia y agregar prueba de rechazo.
- Important: agregar prueba real de persistencia de `DatosEntrega`.
- Important: validar `limiteAdelantoCompra` como no negativo.
- Important: alinear DTO y entidad para que `COMPRA_Y_ENTREGA` no acepte costo estimado cero.
- Minor deferred: corregir contador del log del seeder y cubrir específicamente create/update del servicio.
- Task 1: complete (commits 6bad27a..f4d1213, review clean; minor deferred: contador de log y cobertura adicional create/update)

## Task 2 review

- Reviewer: Needs fixes.
- Important: el cliente móvil conserva fallback a línea recta cuando OSRM falla.
- Cross-task finding: el filtro de solicitudes por límite se integra en Task 3, cuando existe el listado real de solicitudes.
- Cross-task finding: el snapshot inmutable del precio se persiste en Task 4, cuando se confirma compra/entrega.
- `Ruling: mantener el filtro de listado en Task 3 y el snapshot en Task 4` — Task 2 produce el cliente OSRM y el cálculo; esos flujos son los dueños de la consulta y de la transición que fija el precio. Costo si falla: solicitudes visibles indebidamente o precio recalculado; ambos quedan como criterios obligatorios de sus tareas.
- Task 2: complete (commits 2f308bf..964cf19, review clean; cross-task rulings carried to Tasks 3/4)

## Task 3 review

- Reviewer: Needs fixes.
- Important: validar que el vehículo DELIVERY sea realmente MOTO al listar, ofertar y aceptar.
- Important: agregar pruebas de integración de creación, visibilidad, límite, republicación y concurrencia.
- Important: proteger aceptación concurrente del mismo conductor para evitar dos viajes activos.
- Task 3: implementada, pendiente de re-review (commits 662de56..cee202b).
- Pausa solicitada por el usuario antes de generar el review package de `964cf19..cee202b`.
- Tasks 4-8: no iniciadas.

## Task 4 cierre

- Brief reconstruido en `task-4-cierre-brief.md` desde los handoffs de 2026-10-04 y 2026-10-05.
- `Ruling: los codigos DELIVERY son aleatorios e independientes de 6 digitos` — el usuario confirmo
  que no guardan relacion con telefono, CI, ids ni otros numeros; el costo si se interpreta mal es
  aceptar un contrato de seguridad incorrecto y romper la entrega.
  Correccion 2026-10-05 (commit `4b9b463`): el ruling se escribio con 8 digitos; el contrato vigente es
  de exactamente 6 digitos (`DatosEntrega.PATRON_CODIGO`, `ValidarCodigoEntregaRequest`,
  `SolicitudViajeService.codigo()`). Ver `codigos-6-digitos-report.md`.
- Alcance: pruebas reales de `EntregaService` y permisos, sin tocar la comparacion diferida de
  telefonos ni Task 5.
- Estado: implementacion pendiente.

## Task 5

- Task 5: complete (commits `293bcc1`..`aefdda2`, review clean).
- Implementado: reporte `PENDIENTE` automatico para fallas DELIVERY y paquete incorrecto, evidencia
  asociada a `DatosEntrega`, endpoints administrativos y descarga protegida, resoluciones finales con
  auditoria, advertencias sin suspension automatica.
- Revisions: la resolucion invalida/reapertura fue corregida; se agregaron persistencia, seguridad,
  descarga ADMIN y asociacion del caso `PAQUETE_NO_COINCIDE`.
- Verificacion focalizada reportada por el implementador: GREEN. PostgreSQL real y suite completa quedan
  pendientes por la configuracion de entorno y por decision del usuario de continuar primero con la
  implementacion.
- `Ruling: diferir la prueba PostgreSQL durante la implementacion de Tasks posteriores` — el usuario
  pidio avanzar y probar al final; el costo es que los defectos de contexto/BD pueden aparecer mas tarde.
