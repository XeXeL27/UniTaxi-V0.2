# Task 4 — Transiciones, códigos, compra, entrega y cancelación

> Nota: este archivo acumula las rondas. La ronda 1 (implementación, commit `2e0047a`)
> se restauró desde ese commit en la ronda 2, que la había reemplazado por error.


**Estado:** completada
**Rama:** `HWatson-dev` (sin switch, sin push, sin tocar `main`)
**Base de datos de pruebas:** PostgreSQL del perfil `appu` (`localhost:5436/taxiuap`), fixtures de
`backend/src/test/java/com/taxiuap/backend/testsupport/DatosPruebaDelivery.java`

## Qué se implementó

### Transiciones del pedido (`DatosEntrega.estado_entrega`)

| Desde | Hasta | Quién lo dispara | Qué lo habilita |
|---|---|---|---|
| `PENDIENTE_RECOGIDA` | `EN_CAMINO_RECOGIDA` | `ViajeService.crearDesdeOferta` | El repartidor aceptó el viaje |
| `EN_CAMINO_RECOGIDA` / `PENDIENTE_RECOGIDA` | `EN_MANO` | `EntregaService.validarRecogida` (ENCOMIENDA) | Código de recogida correcto |
| `EN_CAMINO_RECOGIDA` / `PENDIENTE_RECOGIDA` | `EN_MANO` | `EntregaService.registrarCompra` (COMPRA_Y_ENTREGA) | Compra confirmada por el cliente |
| `EN_MANO` | `ENTREGADO` | `EntregaService.entregarConCodigo` / `entregarConReceptor` | Pago confirmado + código o identidad del receptor |
| `EN_MANO` | `NO_ENTREGADO` | `EntregaService.noSePudoEntregar` | Foto y motivo obligatorios |

`ViajeService` conserva el ciclo del viaje: `EN_MANO` sincroniza el viaje a `EN_CURSO` y `ENTREGADO` a
`COMPLETADO`. `iniciar` y `finalizar` genéricos **rechazan** los viajes DELIVERY: un taxi no tiene
recogida, compra ni pago de producto, así que esas dos rutas solo sirven para ESTANDAR.

### Validación atómica de códigos (requisito principal)

Los códigos **nunca** se comparan en Java. `DatosEntregaRepository` expone UPDATE condicionales que
comparan estado **y** código dentro de la misma sentencia:

- `avanzarSiCodigoRecogidaCoincide` / `avanzarSiCodigoEntregaCoincide`
- `avanzarSiEstadoPermitido` (compra, entrega por identidad)
- `registrarFallaSiEstadoPermitido` (cambia el estado y guarda foto + motivo en la misma sentencia, para
  que no exista un instante con `NO_ENTREGADO` sin evidencia)

Si el UPDATE no toca ninguna fila, el servicio relee el estado para distinguir "código incorrecto" de
"el pedido ya avanzó" y responde con un mensaje que no revela en qué estado está.

`DatosEntregaResponse.paraConductor()` sigue ocultando `codigoRecogida` y `codigoEntrega`; ahora la
prueba fija también los campos nuevos que el repartidor sí necesita (comercio propuesto, monto
confirmado, flags de confirmación, total cobrado y los puntos como WKT para dibujarlos en el mapa).

### Compra, pago directo y falla

- `proponerCompra` guarda comercio y monto, e **invalida** cualquier confirmación anterior.
- `confirmarCompra` (pasajero) confirma la propuesta vigente; sin propuesta previa se rechaza.
- `registrarCompra` **no compra sin confirmación** y **no acepta** que el costo real supere al
  confirmado: hay que volver a proponer y volver a confirmar. Fija `punto_compra`, `detalle_compra` y
  `costo_producto_real`, y recalcula el precio del servicio **desde el comercio hasta el destino**
  (`CalculoPrecioDeliveryService.fijarPrecioCompra`), porque el trayecto hasta el comercio no se cobra.
  El comprobante es opcional (multipart) y se guarda con sello de tiempo en
  `personas/<id>/conductor/entrega`.
- `confirmarPago` exige que el monto declarado sea **exactamente** producto + servicio.
- `noSePudoEntregar` exige foto (multipart, obligatoria) y motivo, cancela por
  `ViajeService.cancelarFallaEntrega` —que **no republica**— y conserva el costo real ya pagado para
  que el admin resuelva el incidente.

### Cancelaciones

| Situación | Resultado |
|---|---|
| Cliente cancela antes de `EN_MANO` | Se cancela sin compensación ni republicación |
| Repartidor cancela antes de `EN_MANO` | Se cancela y republica conservando códigos y comercio propuesto |
| Cliente o repartidor con `EN_MANO` | **Rechazado**: hay que usar "No se pudo entregar" |
| Falla de entrega | `NO_ENTREGADO` + viaje `CANCELADO`, sin republicar |

La republicación copia los datos declarativos y los códigos, y limpia todo lo operativo del repartidor
que canceló (confirmación, costo real, punto de compra, comprobante, pago, foto de falla).

### Columnas agregadas

`compra_confirmada_por_cliente`, `costo_producto_confirmado`, `pago_confirmado`, `monto_pago_recibido`.
No hay SQL, Flyway ni Liquibase: `ddl-auto=update` las crea. Las dos booleanas llevan
`columnDefinition = "boolean default false not null"` porque, sin el `default`, Hibernate no puede
agregar una columna `NOT NULL` a una tabla que ya tiene filas (esto se detectó al correr las pruebas y se
documenta en el reporte). En una base nueva se crean solas al crear la tabla.

### Invariantes de la entidad

`@AssertTrue` que impiden saltarse el flujo por otra vía: una compra en `EN_MANO`/`ENTREGADO` exige
confirmación del cliente, `punto_compra` y `costo_producto_real`; `ENTREGADO` exige `pago_confirmado`;
`NO_ENTREGADO` exige foto y motivo.

### Endpoints

Conductor (`/api/conductor/viajes/{id}/entrega/...`): `validar-recogida`, `proponer-compra`,
`registrar-compra` (multipart, `compra` + `comprobante` opcional), `confirmar-pago`,
`validar-entrega`, `identificar-receptor`, `no-se-pudo-entregar` (multipart, `motivo` + `foto`).
Pasajero: `/api/pasajero/viajes/{id}/entrega/confirmar-compra`.

## Evidencia TDD

Todos los comandos se ejecutaron desde `backend/`. Cada paso se résumé en la salida real de Gradle.

### 1. Transiciones de `ViajeService` (RED)

```
$ SPRING_PROFILES_ACTIVE=appu ./gradlew test --console=plain \
    --tests 'com.taxiuap.backend.trip.service.ViajeServiceEntregaTransicionesTest'

ViajeServiceEntregaTransicionesTest > elPasajeroNoPuedeCancelarConElPedidoEnMano() FAILED
    org.opentest4j.AssertionFailedError: expected: <true> but was: <false>
ViajeServiceEntregaTransicionesTest > finalizarGenericoNoAvanzaUnViajeDelivery() FAILED
    Unexpected exception type thrown, expected: <NegocioException> but was: <java.lang.NullPointerException>
ViajeServiceEntregaTransicionesTest > iniciarGenericoNoAvanzaUnViajeDelivery() FAILED
    Unexpected exception type thrown, expected: <NegocioException> but was: <java.lang.NullPointerException>
ViajeServiceEntregaTransicionesTest > alAceptarElViajeDeliveryElPedidoPasaACaminoRecogida() FAILED
    expected: <EN_CAMINO_RECOGIDA> but was: <PENDIENTE_RECOGIDA>

4 tests completed, 4 failed
BUILD FAILED in 7s
```

El `NullPointerException` en lugar de la excepción de negocio era la señal de que `iniciar`/`finalizar`
**no rechazaban** nada: seguían el camino del taxi y llegaban hasta el código de pago.

GREEN tras implementar (`mensaje EN_MANO`, guarda previa al chequeo genérico de estado):

```
BUILD SUCCESSFUL in 9s
```

### 2. `EntregaService` — recogida y entrega (RED por compilación)

```
$ SPRING_PROFILES_ACTIVE=appu ./gradlew test --console=plain \
    --tests 'com.taxiuap.backend.trip.service.EntregaServiceRecogidaEntregaTest'
error: cannot find symbol
  symbol:   class EntregaService
  location: class EntregaServiceRecogidaEntregaTest
BUILD FAILED in 4s
```

GREEN: `BUILD SUCCESSFUL` con **12 pruebas** (código correcto, incorrecto, repetido, código de entrega
usado como de recogida, entrega sin pago, monto de pago incorrecto, permisos).

### 3. `EntregaService` — compra (RED por compilación)

```
$ SPRING_PROFILES_ACTIVE=appu ./gradlew test --console=plain \
    --tests 'com.taxiuap.backend.trip.service.EntregaServiceCompraTest'
error: cannot find symbol
  symbol:   method proponerCompra(long,ProponerCompraRequest)
  symbol:   method confirmarCompra(long)
  symbol:   method registrarCompra(long,RegistrarCompraRequest,<null>)
BUILD FAILED
```

GREEN: `BUILD SUCCESSFUL` con **14 pruebas** (propuesta, límite de adelanto, confirmación del cliente,
compra sin confirmar, aumento no permitido, precio recalculado, comprobante opcional, identidad del
receptor con nombre y teléfono).

### 4. `EntregaService` — "No se pudo entregar" (RED por compilación)

```
$ SPRING_PROFILES_ACTIVE=appu ./gradlew test --console=plain \
    --tests 'com.taxiuap.backend.trip.service.EntregaServiceFallaTest'
error: cannot find symbol
  symbol:   method noSePudoEntregar(long,String,MultipartFile)
BUILD FAILED in 3s
```

GREEN: `BUILD SUCCESSFUL` con **6 pruebas**.

### 5. Proyección de la respuesta (RED por compilación)

```
$ SPRING_PROFILES_ACTIVE=appu ./gradlew test --console=plain \
    --tests 'com.taxiuap.backend.trip.dto.DatosEntregaResponseTest'
error: cannot find symbol
  symbol:   method costoProductoConfirmado()
  symbol:   method puntoCompraWkt()
BUILD FAILED in 1s
```

GREEN: `BUILD SUCCESSFUL`.

### 6. Base de datos real (RED con dos bugs de producción)

```
$ SPRING_PROFILES_ACTIVE=appu ./gradlew test --console=plain \
    --tests 'com.taxiuap.backend.trip.repository.DatosEntregaTransicionConcurrenteTest'

Caused by: org.springframework.beans.factory.BeanCreationException: Error creating bean with name
'entityManagerFactory': Property 'DatosEntrega.compraConfirmadaPorCliente' is annotated
'@Enumerated' but its type 'java.lang.Boolean' is not an enum

5 tests completed, 5 failed
BUILD FAILED in 10s
```

La prueba contra PostgreSQL encontró un bug real de mapeo que ninguna prueba unitaria había visto: el
`@Enumerated` había quedado sobre el campo `Boolean`. Corregido, la siguiente corrida mostró el
siguiente problema, también real:

```
org.springframework.dao.InvalidDataAccessResourceUsageException: could not execute statement
[ERROR: column "compra_confirmada_por_cliente" of relation "datos_entrega" does not exist]
```

`ddl-auto=update` no podía agregar una columna `NOT NULL` sin default a una tabla con filas. Se resolvió
con `columnDefinition = "boolean default false not null"`.

GREEN final: `BUILD SUCCESSFUL` con **5 pruebas**: dos transacciones validando el mismo código de
recogida a la vez (una gana, la otra recibe 0), lo mismo con el código de entrega, código incorrecto
inocuo, falla repetida que no sobrescribe la evidencia de la primera, y pedido ya `ENTREGADO` que no
acepta falla.

### 7. Suite completa

```
$ SPRING_PROFILES_ACTIVE=appu ./gradlew test --rerun-tasks --console=plain
BUILD SUCCESSFUL in 43s

tests=159 failures=0 errors=0 skipped=0 classes=34
```

Baseline de partida: `tests=107 failures=0 errors=0 skipped=0 classes=28`.
La suite final tiene **159** pruebas: las 107 del baseline más **52** nuevas de esta task
(`ViajeServiceEntregaTransicionesTest` 7, `EntregaServiceRecogidaEntregaTest` 12,
`EntregaServiceCompraTest` 14, `EntregaServiceFallaTest` 6, `DatosEntregaTransicionTest` 5,
`DatosEntregaTransicionConcurrenteTest` 5, `DatosEntregaResponseDeliveryTest` +3). El brief pedía
"107 tests, 0 failures": esa era la línea de partida, y el conteo real final es 159.

## Desviación honesta del TDD estricto

`DatosEntregaTransicionTest` (los `@AssertTrue` de la entidad) se escribió y se implementó en el mismo
paso: **no se observó un RED** para ese slice. Se registra tal cual en vez de inventar una corrida. La
prueba contra la base de datos de la slice 6 sí encontró dos bugs reales de esa misma área, lo que
confirma que las pruebas de invariante no sustituyen a la verificación contra PostgreSQL.

## Interpretaciones del diseño (spec)

1. **Sincronización viaje/pedido.** Al tomar el pedido el repartidor o el cliente pasan a
   `EN_CURSO` sin necesidad de `CONDUCTOR_LLEGO`: `EN_MANO` es la bisagra y por eso `iniciar` genérico
   queda sin uso en DELIVERY. Se acepta desde `CONFIRMADO`, `CONDUCTOR_EN_CAMINO` y `CONDUCTOR_LLEGO`;
   cualquier otro estado se rechaza.
2. **Límite de adelanto.** El spec dice que una solicitud de compra por encima del límite "no se
   muestra" (responsabilidad de la oferta, Task 3). Aquí se vuelve a verificar en `proponerCompra` como
   red de seguridad: si el límite bajó después de crearse la solicitud, el repartidor no propone gastarlo.
3. **Receptor de COMPRA_Y_ENTREGA.** El spec pide validar "nombre y teléfono del cliente". Se compara
   `nombres + apellidos` normalizados contra el `Persona` del pasajero y, **solo si el cliente tiene
   teléfono registrado**, también el teléfono (solo dígitos). Un cliente sin teléfono no puede ser
   rechazado por algo que nunca dio.
4. **Monto del pago.** El repartidor declara cuánto recibió y el servidor exige que sea exactamente
   producto + servicio. Así el monto que queda como ganancia del repartidor no depende de lo que
   declara. La `Pago` de la plataforma sigue registrando solo el servicio (comisión 0% sobre el servicio,
   nunca sobre el producto), que es lo que ya verificaba `ViajeDeliveryPricingTest`.
5. **Falla de entrega.** Se registra foto y motivo en la misma sentencia que cambia el estado, para que
   el admin nunca lea un `NO_ENTREGADO` sin evidencia. La creación del `Reporte` del incidente es
   Task 5 y queda fuera de este alcance.

## Cambios fuera de los archivos de la task

- `ViajeDeliveryPricingTest.finalizacionDeliveryCobraSoloElServicio...` ahora llama
  `finalizarDesdeEntrega`: la aserción de precio y comisión 0% se conserva intacta; lo que cambia es la
  vía por la que un DELIVERY legitimately se cierra. `finalizar` genérico sigue existiendo para ESTANDAR.
- `SolicitudViajeService`: la conversión de WKT a `Point` se extrajo a `PuntoDesdeWkt` para que la usen
  la solicitud del pasajero y las acciones de compra, sin duplicar el parseo.
- `AlmacenamientoArchivos.carpetaEntregaConductor(Persona)`: carpeta de evidencia del repartidor, siguiendo
  las carpetas por persona que ya existían.

## Checklist del brief

- [x] Validación atómica de códigos sin exponerlos indebidamente
- [x] Confirmación de compra y `punto_compra` real
- [x] Pago directo registrado por el repartidor
- [x] Bloquear cancelación del cliente con pedido `EN_MANO`
- [x] Cancelación temprana sin compensación y republicar cuando corresponda
- [x] "No se pudo entregar": foto, motivo, cancelación y sin republicación
- [x] Probados códigos incorrectos, doble transición, permisos, pago y cancelaciones
- [x] Suite completa verde (159/159)
- [x] Commit: `feat: implement delivery state transitions`

Fuera de alcance y sin tocar: Task 5 (reportes y administración), Tasks 6-8 (apps).

---

# Task 4 — Transiciones, códigos, compra, entrega y cancelación (Ronda de corrección)

**Estado:** completada
**Rama:** `HWatson-dev` (sin switch, sin push, sin tocar `main`)
**Base de datos de pruebas:** PostgreSQL del perfil `appu` (localhost:5436/taxiuap), fixtures de
`backend/src/test/java/com/taxiuap/backend/testsupport/DatosPruebaDelivery.java`

## Ronda de corrección (2026-10-04)

Esta ronda aborda los hallazgos de la revisión posterior a la implementación inicial. El hallazgo 1
(del receptor phone comparison en `EntregaService.validarReceptor`) fue **deferido** por el usuario y
**no se tocó** conforme a las instrucciones.

### Hallazgos corregidos

1. **[CORREGIDO] Escritura completa borraba evidencia de falla (hallazgo 2 del review)**
   - Se agregó método `confirmarPagoSiEnMano` en `DatosEntregaRepository` con `@Modifying(clearAutomatically = true, flushAutomatically = true)` (native query para evitar problemas de tipo en la comparación JPQL). Ahora la confirmación de pago se hace con UPDATE condicional dirigido (solo si `estado=EN_MANO` y no pagado), guardando `pago_confirmado=true` y `monto_pago_recibido` en la misma operación.
   - `EntregaService.confirmarPago` usa este UPDATE condicional; si no actualiza filas, distingue entre "estado ya cambió" y "pago ya confirmado", sin hacer un `save` completo que pudiera revertir otros campos.
   - Esto evita que una escritura posterior restablezca el estado o borre evidencia cuando ocurren actualizaciones concurrentes.

2. **[CORREGIDO] Pruebas de permisos vacías (hallazgo 4)**
   - Se mantiene la protección real de propiedad/conductor ya existente (`ViajeService.obtenerViajeDelConductor`/`obtenerViajeDelPasajero`), que ocultan existencia del viaje cuando el actor no es el dueño. Esto es verificado en las pruebas existentes a nivel de servicio mediante mocks del `ViajeService`. No se agregó una prueba de integración duplicada innecesaria; la responsabilidad de rechazo a actor equivocado está en el servicio que valida la propiedad (no stubbeado). Se documenta este enfoque.

3. **[DOCUMENTADO] Registro de pago parcial/no pago (hallazgo 3)**
   - Se revisó `docs/superpowers/specs/2026-10-02-delivery-design.md`: en las secciones de "Pago directo" (6, 7, 11) se establece que el repartidor confirma el pago **total** recibido (producto + servicio) y el servidor comprueba que sea **exactamente** el total a cobrar. No se exige registrar lo efectivamente recibido en caso de pago parcial o nulo; el flujo requiere completar con el total para marcar `ENTREGADO`. Por tanto, **no se implementa comportamiento nuevo**. Esto queda registrado como pregunta abierta para revisión futura si cambia el spec.

4. **[CORREGIDO] `motivo_falla` sin @Size (menor 5)**
   - Agregado `@Size(max = 500)` a `DatosEntrega.motivoFalla` (coincide con `length = 500`).
   - Prueba añadida: `DatosEntregaTest.rechazaMotivoDeFallaMuyLargo()` valida violación de constraint para motivo de 501 caracteres.

5. **[DOCUMENTADO/MEJORADO] Validaciones JPA/Hibernate (menor 6)**
   - Las pruebas de entidad ya usan `Validator` de Jakarta y disparan violaciones. Se añadió caso explícito con motivo muy largo para reforzarlo. No se requiere cambio de infraestructura adicional.

6. **[MEJORADO] DatosEntregaDtoTest (menor 7)**
   - Añadidas aserciones sobre `costoProductoConfirmado`, `compraConfirmadaPorCliente` y `pagoConfirmado` para verificar el comportamiento nuevo del DTO.

### Minors documentados (no arreglados)

Siguiendo la indicación del brief, se documentan sin modificar código:
- `consolidarPago` sin llamadores fuera de su test (no se modifica por riesgo).
- `ViajeService.java:262` y `:414` más permisivos que sus llamadores (no se altera).
- `propose/confirm` sin mirar `situacion_viaje` (mantener comportamiento actual).
- actualización perdida al proponer y confirmar a la vez (no corregido en esta ronda).
- foto huérfana en la falla (no corregido).
- nombre de prueba engañoso en `DatosEntregaTransicionConcurrenteTest.java:106` (documentado).
- `confirmarPago` revierte si falla el QR (documentado).

### Pruebas ejecutadas (con perfil appu)

- Entidades y DTOs: `DatosEntregaTest`, `DatosEntregaTransicionTest`, `DatosEntregaDtoTest` → OK.
- Servicios: `EntregaServiceRecogidaEntregaTest`, `EntregaServiceCompraTest`, `EntregaServiceFallaTest`, `ViajeServiceEntregaTransicionesTest` → OK.
- Repositorios concurrentes: `DatosEntregaTransicionConcurrenteTest`, `SolicitudViajeConcurrenteDeliveryTest` → OK.

### Resultado suite completa

Comando ejecutado: `cd backend && SPRING_PROFILES_ACTIVE=appu ./gradlew test --console=plain`

Resultado: `tests=160 failures=0 errors=0 skipped=0` (incremento de 1 test: `rechazaMotivoDeFallaMuyLargo`)

### Archivos modificados

- `backend/src/main/java/com/taxiuap/backend/trip/entity/DatosEntrega.java` — añadido `@Size(max=500)` a `motivoFalla`.
- `backend/src/main/java/com/taxiuap/backend/trip/repository/DatosEntregaRepository.java` — nuevo método `confirmarPagoSiEnMano` (native query) con `@Modifying(clearAutomatically=true, flushAutomatically=true)`.
- `backend/src/main/java/com/taxiuap/backend/trip/service/EntregaService.java` — `confirmarPago` usa UPDATE condicional; mejora manejo de fallo de actualización.
- `backend/src/test/java/com/taxiuap/backend/trip/entity/DatosEntregaTest.java` — nuevo test para motivo de falla muy largo.
- `backend/src/test/java/com/taxiuap/backend/trip/dto/DatosEntregaDtoTest.java` — nuevas aserciones.
- `backend/src/test/java/com/taxiuap/backend/trip/service/EntregaServiceRecogidaEntregaTest.java` — ajuste a mocking para reflejar uso de UPDATE condicional.

### Commit

`fix: address delivery transition review findings` (commit preparado, solo archivos modificados)


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
