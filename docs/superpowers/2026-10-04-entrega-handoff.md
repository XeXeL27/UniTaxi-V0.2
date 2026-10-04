# Handoff — fase 1 DELIVERY (2026-10-04)

Estado al cierre de la sesion. Rama `HWatson-dev`, sin push, `main` intacto.
Rama local 7 commits por delante de `origin/HWatson-dev`.

## Donde esta todo

- Plan: `docs/superpowers/plans/2026-10-02-delivery-implementation-plan.md`
- Diseno (manda sobre el plan): `docs/superpowers/specs/2026-10-02-delivery-design.md`
- Reportes y revisiones: `.superpowers/sdd/2026-10-02-delivery-implementation-plan/`
- Bitacora: `docs/CHANGELOG.md`

## Commits de esta sesion

| Commit | Que es |
|---|---|
| `5f70ef2` | Task 3: precio OSRM A→B, estimacion GPS en COMPRA_Y_ENTREGA, moto DELIVERY, tarifa tecnica, defaults 4.00/1.80/0.20 |
| `70d34ef` | Task 3: tarifa DELIVERY resoluble en la aceptacion |
| `a1dc95f` | Pruebas de base autosuficientes (`testsupport/DatosPruebaDelivery`) |
| `79c28b9` | Evidencia de la verificacion con PostgreSQL |
| `2e0047a` | Task 4: `EntregaService`, ocho acciones de entrega, validacion atomica de codigos, compra, pago, falla, cancelaciones, endpoints |
| `dd1d860` | Task 4 ronda de correccion: UPDATE dirigido en `confirmarPago`, `@Size` en `motivoFalla` |
| `8469772` | Restauracion de la evidencia de TDD de la ronda 1 de Task 4 |

## Verificacion real (no reporta de subagentes)

Todas con `SPRING_PROFILES_ACTIVE=appu`, PostgreSQL de Docker, desde `backend/`:

- Task 3 focalizado: `BUILD SUCCESSFUL in 40s`
- Task 3 suite completa: `BUILD SUCCESSFUL in 36s` — `tests=107 failures=0 errors=0 skipped=0 classes=28`
- Task 4 suite completa sobre `dd1d860`: `BUILD SUCCESSFUL in 48s` — `tests=160 failures=0 errors=0 skipped=0`

Con esto quedo verificado contra la base real que: la aceptacion DELIVERY persiste el viaje
`CONFIRMADO` con moto DELIVERY, tarifa tecnica de zona nula con base `4.00` y la respuesta al
repartidor sin codigos; la tarifa se resuelve aunque la categoria DELIVERY se cree despues del
arranque; dos transacciones concurrentes producen un UPDATE de 1 fila y otro de 0 con la solicitud
`ACEPTADA`; y `datos_entrega` es uno a uno con `solicitud_viaje`.

## Como correr las pruebas

```bash
cd backend
SPRING_PROFILES_ACTIVE=appu ./gradlew test --console=plain
```

Las credenciales ya estan en `backend/src/main/resources/application-appu.properties`. **No crear ni
editar `application*.properties`.** Las pruebas de base no pueden depender del seedor de desarrollo:
para eso esta `backend/src/test/java/com/taxiuap/backend/testsupport/DatosPruebaDelivery.java`.

## Pendiente: dos hallazgos importantes de Task 4

Los Cerro y NO se hicieron. El subagente los reporto como hechos y no existian.

1. **`EntregaService` nunca se prueba contra la base real.** Su correctitud depende de
   `@Modifying(clearAutomatically, flushAutomatically)`: todos los tests mockean el repositorio y
   stublean la lectura posterior a la transicion, asi que si alguien quita `clearAutomatically` o el
   UPDATE deja de ser condicional, ningun test falla y el estado se revierte en silencio.
   `DatosEntregaTransicionConcurrenteTest` es un `@SpringBootTest` real, pero mueve
   `DatosEntregaRepository` directo, no `EntregaService`. Falta una prueba de integracion que recorra
   el servicio y verifique el estado **persistido**.
2. **La prueba de permisos es vacua.** `EntregaServiceRecogidaEntregaTest` solo "prueba" el permiso
   haciendo que el helper de propiedad lance excepcion. No hay ninguna prueba que rechace a un actor
   real equivocado. Falta: un conductor que no es el asignado, un pasajero que no es del viaje, y el
   control positivo del conductor real.

Ademas, la prueba nueva de base debe probarse a si misma: romper a proposito la produccion (quitar
`clearAutomatically` o volver el UPDATE incondicional), confirmar que falla, y restaurar.

Un intento anterior de esta prueba quedo a medias y se **descarto**: `EntregaServiceRealDbIntegrationTest`
tenia 4 de 6 pruebas en verde y fallaba al intentar pasar de `EN_CAMINO_RECOGIDA` a `ENTREGADO` sin
pasar por `EN_MANO`. Confirma que el estado lo prohibe correctamente, o sea que era la prueba la que
no recorria el camino completo, no un defecto de produccion. Queda como referencia para los nombres
de las pruebas y la fixture que usaba, pero no se conservo nada de ella.

## Pendiente: bug diferido por decision del usuario

**COMPRA_Y_ENTREGA no se puede entregar si el telefono guardado no es de 8 digitos pelados.**
`EntregaService.validarReceptor` compara `digitos(request.telefono())` con
`digitos(persona.getTelefono())`, y `digitos()` solo quita simbolos. Un pasajero registrado como
`+591 70123456` nunca coincide con el `70123456` que escribe el repartidor, y como
`entregarConCodigo` esta prohibido para COMPRA_Y_ENTREGA, el pedido solo puede terminar en
`noSePudoEntregar`. `Persona.telefono` no tiene restriccion de formato.

Decidido el 2026-10-04: **dejarlo documentado y revisarlo despues.** No lo implementes sin una
decision nueva. Regla candidata: comparar los 8 digitos nacionales despues de quitar el prefijo `591`.

## Menores documentados, sin arreglar

- Aceptaciones concurrentes de solicitudes distintas pueden crear tarifas tecnicas de zona nula
  duplicadas (sin efecto en el precio).
- `confirmarPago` revierte si falla la llamada al QR.
- Foto huerfana cuando se reporta una falla.
- `propose`/`confirm` de compra no miran `situacion_viaje`.
- `ViajeService.java:262` y `:414` mas permisivos que sus llamadores.
- Actualizacion perdida al proponer y confirmar compra a la vez.
- `DatosEntregaDtoTest` se amplia pero no se fortalece.
- Pruebas de invariantes que no pasan por la validacion de Hibernate.

## Decisiones de negocio abiertas

- **Pago parcial o no pago**: el spec exige el total exacto (producto + servicio), asi que hoy no se
  puede registrar que el cliente no pago todo. Queda como pregunta abierta para Task 5, cuyo reporte
  de "no entregados con evidencia" necesitaria ese dato.

## Siguientes pasos

1. Cerrar los dos hallazgos importantes de Task 4 de arriba.
2. Task 5: reportes y administracion backend (`Reporte.PENDIENTE` automatico, resolucion con
   observacion/fecha/identidad/cierre, descarga de foto solo para ADMIN).
3. Tasks 6, 7 y 8: app pasajero, app repartidor, panel admin.
4. Al final, revision global de la rama y re-triaje de los menores.

Proceso: un implementador nuevo y una revision independiente por task
(`subagent-driven-development`), TDD con el comando y la salida reales en el reporte, y un commit por
task.
