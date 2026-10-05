# Task 3 Report: Flujo backend de solicitud y aceptación

## Implementado

- Las solicitudes `DELIVERY` requieren `datos_entrega`; las solicitudes estándar no pueden incluirlo.
- `ENCOMIENDA` persiste precio fijo y genera códigos independientes de recogida y entrega.
- `COMPRA_Y_ENTREGA` persiste el costo estimado y deja el precio del servicio pendiente (`null`) al crear.
- La visibilidad y la aceptación de DELIVERY exigen conductor habilitado, vehículo activo con categoría `DELIVERY` compatible con `MOTO` y, para compra, límite de adelanto suficiente.
- `datos_entrega` se incluye en solicitudes, ofertas y viajes; los códigos se redaccionan en respuestas al conductor.
- La republicación por cancelación temprana conserva datos declarativos y códigos, y reinicia estado y datos operativos de compra.
- No se implementaron transiciones de códigos, compra, entrega ni cancelación avanzada de Task 4.

## Evidencia TDD

### RED

Comando:

```text
./gradlew test --tests 'com.taxiuap.backend.trip.dto.DatosEntregaResponseDeliveryTest'
```

Resultado: fallo de compilación esperado porque `DatosEntregaResponse.paraConductor()` todavía no existía.

### GREEN

Comandos:

```text
./gradlew compileJava
./gradlew test --tests 'com.taxiuap.backend.trip.dto.DatosEntregaResponseDeliveryTest' --tests 'com.taxiuap.backend.trip.dto.DatosEntregaDtoTest' --tests 'com.taxiuap.backend.trip.entity.DatosEntregaTest' --tests 'com.taxiuap.backend.vehicle.entity.CategoriaServicioEntregaTest' --tests 'com.taxiuap.backend.identity.entity.ConductorEntregaTest'
```

Resultado: ambos comandos terminaron con `BUILD SUCCESSFUL`.

## Archivos cambiados

- `backend/src/main/java/com/taxiuap/backend/trip/service/SolicitudViajeService.java`
- `backend/src/main/java/com/taxiuap/backend/trip/service/OfertaViajeService.java`
- `backend/src/main/java/com/taxiuap/backend/trip/service/ViajeService.java`
- DTOs `SolicitudViajeRequest/Response`, `OfertaViajeResponse`, `ViajeResponse` y `DatosEntregaResponse`
- `backend/src/test/java/com/taxiuap/backend/trip/dto/DatosEntregaResponseDeliveryTest.java`
- `docs/CHANGELOG.md`

## Auto-revisión

- Se mantuvo el flujo existente `solicitud -> oferta -> viaje` y la aceptación atómica existente.
- No se modificaron `application.properties` ni `main`; la modificación de `application.properties` permanece preexistente y sin incluir en el commit.
- No se despacharon subagentes.

## Preocupaciones

- `./gradlew test --tests '*Entrega*' --tests '*Delivery*'` incluye `DatosEntregaPersistenciaTest`, que no pudo levantar el contexto JPA por `Hibernate DialectFactory`; el fallo es de infraestructura/configuración de base de datos, no de una aserción del Task 3.
- La fijación de precio por calles y las transiciones operativas de compra quedan para las tareas previstas en el plan.

## Fix report del reviewer

### Correcciones

- `Vehiculo.esMotoDelivery()` ahora exige simultáneamente tipo físico `MOTO` y categoría `DELIVERY`.
- El listado de solicitudes, la creación de ofertas y la aceptación directa reutilizan esa validación; se mantiene el rechazo por conductor no aprobado y por límite de adelanto insuficiente.
- Se conserva el bloqueo `PESSIMISTIC_WRITE` de `ConductorRepository.bloquear()` en ambos caminos de aceptación para serializar dos intentos concurrentes del mismo conductor antes de comprobar viajes activos.
- Se añadieron pruebas focales de creación, visibilidad/límite, republicación, tipo físico y bloqueo de aceptación.
- No se agregaron transiciones de códigos operativos, compra, entrega ni cancelación avanzada de Task 4.

### Verificación del fix

RED del tipo físico:

```text
./gradlew test --tests 'com.taxiuap.backend.vehicle.service.VehiculoEntregaTest'
```

Salida: fallo de compilación esperado porque `Vehiculo.esMotoDelivery()` no existía.

GREEN del tipo físico y flujo:

```text
./gradlew test --tests 'com.taxiuap.backend.vehicle.service.VehiculoEntregaTest'
./gradlew test --tests 'com.taxiuap.backend.trip.service.SolicitudViajeDeliveryFlowTest' --tests 'com.taxiuap.backend.trip.service.ViajeDeliveryRepublicacionTest' --tests 'com.taxiuap.backend.identity.repository.ConductorRepositoryLockTest' --tests 'com.taxiuap.backend.vehicle.service.VehiculoEntregaTest'
```

Salida: ambos comandos terminaron con `BUILD SUCCESSFUL`.

## Fix round: Task 3 delivery pricing and acceptance (2026-10-04)

### Resultado

- `ENCOMIENDA` calcula A -> B con `CalculoPrecioDeliveryService` antes de persistir, ignora el precio solicitado por el cliente y guarda el precio OSRM como snapshot. Si OSRM falla, no se guarda la solicitud.
- `COMPRA_Y_ENTREGA` sigue sin precio al crearse. Al asignar un conductor calcula su GPS actual -> B, guarda el resultado en `SolicitudViaje.precioSugerido` y muestra ese monto con `precioEstimado=true`. Al existir `costoProductoReal`, las respuestas derivan `precioEstimado=false`; no se implementaron registro de compra ni precio final comercio -> B de Task 4.
- Las respuestas de solicitud, oferta y viaje DELIVERY usan el snapshot, no la tarifa fija genérica. El viaje DELIVERY no ejecuta el cálculo genérico ni aplica descuento estudiantil; busca únicamente una `Tarifa` vigente para cumplir la FK no nula existente de `Viaje`.
- La aceptación elige una moto DELIVERY activa aunque haya otros vehículos antes en el listado. Los viajes no DELIVERY mantienen la selección del primer vehículo activo.
- La aceptación directa y la aceptación de una oferta validan conductor habilitado, moto compatible y límite de adelanto. El rechazo de vehículos estándar queda cubierto por prueba de comportamiento.
- Se agregó una tarifa de referencia DELIVERY idempotente, con valores `taxiuap.delivery.*`. Corre después del seeder normal para cubrir bases donde el seed global ya existe y omite toda la carga.
- La comisión de DELIVERY usa `taxiuap.delivery.comision-porcentaje` (0 por defecto) y se calcula a partir del `precioFinal` del servicio, nunca del producto.
- `precioEstimado` se expone en `SolicitudViajeResponse` y `ViajeResponse`; el viaje muestra el importe estimado en `precioFinal` mientras el booleano lo identifica. El pasajero conserva ambos códigos de ENCOMIENDA y las respuestas al repartidor los omiten.

### Evidencia TDD

#### RED

Comando ejecutado antes de cambiar código de producción:

```text
./gradlew test --tests 'com.taxiuap.backend.trip.service.SolicitudViajeDeliveryFlowTest' --tests 'com.taxiuap.backend.trip.service.ViajeDeliveryPricingTest' --tests 'com.taxiuap.backend.trip.service.OfertaViajeDeliveryAcceptanceTest' --tests 'com.taxiuap.backend.seed.SeedPreciosDeliveryTest' --console=plain
```

Salida observada: `15 tests completed, 8 failed`, `BUILD FAILED`. Los fallos de comportamiento eran los esperados: precio de encomienda `8.00` en vez de `17.50`; no se propagaba el fallo OSRM; faltaba el indicador `precioEstimado`; el snapshot de compra no aparecía en la solicitud ni en el viaje; se elegía una moto estándar antes que la moto DELIVERY; no había tarifa sembrada para DELIVERY; y el pasajero podía aceptar una oferta de un conductor que dejó de estar aprobado.

#### GREEN

Comando focal final:

```text
./gradlew test --rerun-tasks --tests 'com.taxiuap.backend.trip.service.SolicitudViajeDeliveryFlowTest' --tests 'com.taxiuap.backend.trip.service.ViajeDeliveryPricingTest' --tests 'com.taxiuap.backend.trip.service.OfertaViajeDeliveryAcceptanceTest' --tests 'com.taxiuap.backend.trip.service.ViajeDeliveryRepublicacionTest' --tests 'com.taxiuap.backend.trip.dto.DatosEntregaResponseDeliveryTest' --tests 'com.taxiuap.backend.seed.SeedPreciosDeliveryTest' --tests 'com.taxiuap.backend.pricing.service.CalculoPrecioDeliveryServiceTest' --console=plain
```

Salida observada: `BUILD SUCCESSFUL` (25 pruebas focalizadas). Incluye también el caso en que OSRM falla durante la estimación de compra, vehículos estándar rechazados, snapshot en la respuesta de oferta, códigos ocultos al conductor y comisión DELIVERY cero aplicada solo al servicio.

Prueba de comisión, ciclo propio RED/GREEN:

```text
./gradlew test --tests 'com.taxiuap.backend.trip.service.ViajeDeliveryPricingTest.finalizacionDeliveryCobraSoloElServicioYUsaComisionDeliveryCeroPorDefecto' --console=plain
```

RED observado antes del cambio: `1 test completed, 1 failed` porque la ruta genérica aplicaba su comisión al viaje DELIVERY. GREEN observado tras el cambio: `BUILD SUCCESSFUL`.

Compilación observada:

```text
./gradlew compileJava --console=plain
./gradlew compileTestJava --console=plain
```

Ambos terminaron con `BUILD SUCCESSFUL`.

### Persistencia e infraestructura

Se agregó `OfertaViajeDeliveryPersistenciaTest`, una prueba `@SpringBootTest` que acepta una encomienda con la moto DELIVERY real del seed y consulta el viaje persistido, FK de tarifa y redacción de códigos. No es una prueba de reflexión.

Comando ejecutado:

```text
./gradlew test --tests 'com.taxiuap.backend.trip.service.OfertaViajeDeliveryPersistenciaTest' --console=plain
```

La prueba no llega al método ni a sus aserciones: el contexto falla al crear el `DataSource` (`DataSourceBeanCreationException`). También se intentó el test JPA existente en el perfil `appu`; ese perfil no pudo obtener metadata de JDBC y Hibernate falló al resolver el dialecto (`HibernateException` en `DialectFactoryImpl`). La suite completa ejecutada con `./gradlew test --rerun-tasks --console=plain` reportó `102 tests completed, 3 failed`: `TaxiuapApplicationTests`, `DatosEntregaPersistenciaTest` y la nueva prueba de persistencia, todas bloqueadas durante el inicio del contexto de base de datos.

Por tanto, la cobertura de aceptación con persistencia está escrita, pero no pudo verificarse en este entorno. No se afirma que pasó. El mismo bloqueo impide ejecutar una prueba transaccional genuina de ganador único/concurrencia; no se presenta el test de anotación reflectivo preexistente como cobertura concurrente.

### Archivos cambiados

- `backend/src/main/java/com/taxiuap/backend/pricing/service/CalculoPrecioService.java`
- `backend/src/main/java/com/taxiuap/backend/seed/SeedOrquestador.java`
- `backend/src/main/java/com/taxiuap/backend/seed/SeedPrecios.java`
- `backend/src/main/java/com/taxiuap/backend/seed/SeedTarifaDelivery.java`
- `backend/src/main/java/com/taxiuap/backend/trip/dto/SolicitudViajeResponse.java`
- `backend/src/main/java/com/taxiuap/backend/trip/dto/ViajeResponse.java`
- `backend/src/main/java/com/taxiuap/backend/trip/service/OfertaViajeService.java`
- `backend/src/main/java/com/taxiuap/backend/trip/service/SolicitudViajeService.java`
- `backend/src/main/java/com/taxiuap/backend/trip/service/ViajeService.java`
- `backend/src/test/java/com/taxiuap/backend/seed/SeedPreciosDeliveryTest.java`
- `backend/src/test/java/com/taxiuap/backend/trip/service/OfertaViajeDeliveryAcceptanceTest.java`
- `backend/src/test/java/com/taxiuap/backend/trip/service/OfertaViajeDeliveryPersistenciaTest.java`
- `backend/src/test/java/com/taxiuap/backend/trip/service/SolicitudViajeDeliveryFlowTest.java`
- `backend/src/test/java/com/taxiuap/backend/trip/service/ViajeDeliveryPricingTest.java`
- `backend/src/test/java/com/taxiuap/backend/trip/service/ViajeDeliveryRepublicacionTest.java`
- `docs/CHANGELOG.md`
- `.superpowers/sdd/2026-10-02-delivery-implementation-plan/task-3-report.md`

### Auto-revisión

- DELIVERY usa el snapshot `precioSugerido` en solicitudes/ofertas/viajes. La única llamada a `CalculoPrecioService` en el camino DELIVERY resuelve una tarifa vigente para la FK y no calcula la cantidad cobrada.
- La tarifa estimada de COMPRA_Y_ENTREGA se calcula antes de completar la creación del viaje y se asigna al snapshot en la misma transacción que acepta la solicitud; la excepción de ruta aborta el método antes de guardar el viaje.
- La selección de vehículo filtra tipo físico `MOTO`, categoría `DELIVERY` y estado activo. La rama no DELIVERY conserva la selección original.
- No se añadieron columnas, migraciones, cambios a `main`, transiciones de Task 4 ni trabajo móvil/admin. No se despacharon subagentes, conforme a la instrucción explícita.
- `git diff --check` no reportó errores.

### Preocupaciones

- Se necesita proporcionar una configuración PostgreSQL de pruebas válida para ejecutar `OfertaViajeDeliveryPersistenciaTest`, verificar que el seeder añade la tarifa a una base ya inicializada y completar cobertura transaccional/concurrente. Hasta entonces esas partes permanecen sin evidencia de ejecución, aunque compilan.
- La tarifa DELIVERY sembrada es una referencia técnica para la FK. Los importes expuestos al cliente proceden de OSRM vía `CalculoPrecioDeliveryService`; no se debe usar esa tarifa de referencia para facturar DELIVERY.

## Fix round 2: lazy tariff guarantee and database test preparation (2026-10-04)

### Hallazgos y cambios

- La creación/aceptación del viaje DELIVERY ya no depende de `SeedTarifaDelivery.run()`. En el límite de persistencia, `CalculoPrecioService.tarifaVigente()` conserva primero tarifas vigentes de la zona de origen y tarifas administradas vigentes de la categoría; si no encuentra ninguna, crea y persiste una tarifa técnica vigente con `zona=null`. Las llamadas repetidas reutilizan la referencia existente.
- Una tarifa administrativa con zona se prefiere a la referencia técnica zona nula, incluso si esta última aparece primero en el resultado del repositorio. `SeedTarifaDelivery` de arranque sigue siendo opcional y ya no agrega tarifa de Centro encima de otra tarifa vigente DELIVERY.
- Los defaults de `CalculoPrecioDeliveryService`, la referencia técnica, el seeder y `application-xexel.properties.example` son configurables y coinciden con los de MOTO: base `4.00`, km `1.80`, minuto `0.20`.
- La placa de una oferta DELIVERY ahora se toma de una moto activa que también tenga categoría DELIVERY; la respuesta de ofertas estándar conserva la selección original.
- `TarifaService.listar()` no mezcla la referencia interna zona nula con el catálogo administrativo por zona, y `buscarPorId()` serializa la zona ausente como `null` en vez de fallar.
- La prueba de persistencia fue ajustada para crear una categoría DELIVERY después del arranque y aceptar sin una tarifa previa, comprobando que el viaje usa una referencia zona nula mientras mantiene su precio de servicio.
- `SolicitudViajeConcurrenteDeliveryTest` usa el repositorio real, dos transacciones `TransactionTemplate` en hilos separados y una barrera para competir por `aceptarSiDisponible`; comprueba una respuesta de 1 fila y otra de 0 filas y el estado persistido `ACEPTADA`.

### Evidencia TDD

#### RED

Comando ejecutado después de escribir las pruebas y antes de agregar el fallback de tarifa, cambiar la selección de placa y configurar los defaults del servicio:

```text
./gradlew test --tests 'com.taxiuap.backend.trip.service.ViajeDeliveryPricingTest.creaTarifaTecnicaSinZonaAlAceptarDeliveryCuandoNoHayTarifaVigente' --tests 'com.taxiuap.backend.trip.service.OfertaViajeDeliveryAcceptanceTest.respuestaDeOfertaDeliveryConservaElPrecioDeServicioDeLaSolicitud' --tests 'com.taxiuap.backend.pricing.service.CalculoPrecioDeliveryDefaultsTest' --console=plain
```

Salida observada: `3 tests completed, 3 failed`, `BUILD FAILED`. El viaje falló por `NegocioException` sin tarifa, la oferta devolvió la placa estándar y el cálculo devolvió precio `0.00` en vez de `6.00` para una ruta de 1 km y 1 minuto.

Para validar la tarifa del seeder, se añadió la aserción de valores `4.00/1.80/0.20`, se configuró temporalmente el seed como estaba antes (`0.00/0.00/0.00`) y se ejecutó:

```text
./gradlew test --tests 'com.taxiuap.backend.seed.SeedPreciosDeliveryTest.siembraTarifaDeReferenciaParaCategoriaDelivery' --console=plain
```

Salida observada: `1 test completed, 1 failed` por tarifa base distinta del valor MOTO. Se restauraron los defaults configurables de MOTO.

También se verificó el comportamiento idempotente del seeder frente a una tarifa administrada vigente en otra zona:

```text
./gradlew test --tests 'com.taxiuap.backend.seed.SeedPreciosDeliveryTest.mantieneLaTarifaAdministradaDeDeliveryEnOtraZonaSinDuplicarEnCentro' --console=plain
```

RED observado: `1 test completed, 1 failed`; el seeder intentaba crear una tarifa de Centro en lugar de reutilizar la administrada.

La respuesta administrativa ante la nueva tarifa técnica también se probó primero:

```text
./gradlew test --tests 'com.taxiuap.backend.pricing.service.TarifaServiceDeliveryReferenceTest' --console=plain
```

RED observado: `1 test completed, 1 failed` con `NullPointerException` al serializar `zona=null`.

#### GREEN

Comando focal ejecutado, solo con suites no-DB:

```text
./gradlew test --rerun-tasks --tests 'com.taxiuap.backend.pricing.service.CalculoPrecioDeliveryDefaultsTest' --tests 'com.taxiuap.backend.pricing.service.CalculoPrecioDeliveryServiceTest' --tests 'com.taxiuap.backend.pricing.service.TarifaServiceDeliveryReferenceTest' --tests 'com.taxiuap.backend.seed.SeedPreciosDeliveryTest' --tests 'com.taxiuap.backend.trip.service.ViajeDeliveryPricingTest' --tests 'com.taxiuap.backend.trip.service.OfertaViajeDeliveryAcceptanceTest' --tests 'com.taxiuap.backend.trip.service.SolicitudViajeDeliveryFlowTest' --tests 'com.taxiuap.backend.trip.service.ViajeDeliveryRepublicacionTest' --tests 'com.taxiuap.backend.trip.dto.DatosEntregaResponseDeliveryTest' --console=plain
```

Salida observada: `BUILD SUCCESSFUL`.

Compilación de todos los tests (incluidos los DB-backed, sin ejecutarlos):

```text
./gradlew compileTestJava --rerun-tasks --console=plain
```

Salida observada: `BUILD SUCCESSFUL`.

### Pruebas DB

- **NOT RUN / PENDING DOCKER:** `OfertaViajeDeliveryPersistenciaTest` y `SolicitudViajeConcurrenteDeliveryTest`. Por instrucción, no se inició Docker y no se ejecutaron tests de base de datos en esta ronda. El test de concurrencia utiliza transacciones reales y el UPDATE condicional de PostgreSQL; no es Mockito ni reflexión.
- Se notificará al usuario para iniciar Docker antes de ejecutar ambos tests. Hasta entonces no se afirma que persistencia ni concurrencia pasaron.

### Archivos cambiados en este round

- `backend/src/main/java/com/taxiuap/backend/pricing/service/CalculoPrecioService.java`
- `backend/src/main/java/com/taxiuap/backend/pricing/service/CalculoPrecioDeliveryService.java`
- `backend/src/main/java/com/taxiuap/backend/pricing/service/TarifaService.java`
- `backend/src/main/java/com/taxiuap/backend/seed/SeedTarifaDelivery.java`
- `backend/src/main/java/com/taxiuap/backend/trip/service/OfertaViajeService.java`
- `backend/src/main/resources/application-xexel.properties.example`
- `backend/src/test/java/com/taxiuap/backend/pricing/service/CalculoPrecioDeliveryDefaultsTest.java`
- `backend/src/test/java/com/taxiuap/backend/pricing/service/TarifaServiceDeliveryReferenceTest.java`
- `backend/src/test/java/com/taxiuap/backend/seed/SeedPreciosDeliveryTest.java`
- `backend/src/test/java/com/taxiuap/backend/trip/repository/SolicitudViajeConcurrenteDeliveryTest.java`
- `backend/src/test/java/com/taxiuap/backend/trip/service/OfertaViajeDeliveryAcceptanceTest.java`
- `backend/src/test/java/com/taxiuap/backend/trip/service/OfertaViajeDeliveryPersistenciaTest.java`
- `backend/src/test/java/com/taxiuap/backend/trip/service/ViajeDeliveryPricingTest.java`
- `docs/CHANGELOG.md`
- `.superpowers/sdd/2026-10-02-delivery-implementation-plan/task-3-report.md`

### Auto-revisión y preocupaciones

- No se alteró `Viaje.tarifa` ni la nulabilidad del FK. La tarifa técnica no determina el precio cobrado, la distancia del cliente ni la comisión; el servicio de rutas mantiene esos valores.
- Si ya existe tarifa vigente aplicable se reutiliza. La referencia de zona nula solo se inserta al no existir una vigente en la categoría DELIVERY; queda marcada por `zona=null` y se usa la tarifa administrada con zona antes de ella.
- La creación de la categoría después del arranque queda cubierta en la prueba de aceptación preparada; el runner de inicio puede estar deshabilitado o no encontrar Centro sin impedir la aceptación.
- No se inició Docker, no se ejecutaron tests DB, no se modificó `main`, no hubo push ni trabajo de Task 4.

## Round 3: verificacion contra PostgreSQL (commit `a1dc95f`)

Docker estaba disponible y se ejecutaron las pruebas con el perfil `appu`
(`SPRING_PROFILES_ACTIVE=appu`, credenciales de `backend/src/main/resources/application-appu.properties`).
No se creo ni modifico ningun archivo de configuracion.

### Fallos encontrados y causa

Las dos pruebas de base de datos fallaron en su primera ejecucion, ambas por datos de
seed, no por logica de DELIVERY:

- `OfertaViajeDeliveryPersistenciaTest:72` — buscaba una moto DELIVERY activa del seed con
  `orElseThrow`, mensaje "El seed debe incluir una moto DELIVERY activa".
- `SolicitudViajeConcurrenteDeliveryTest:98` — buscaba un pasajero del seed con
  `orElseThrow`, mensaje "El seed debe incluir un pasajero".
- `DatosEntregaPersistenciaTest:36` — tomaba `solicitudViajeRepository.findAll()` sin filtro y en
  una base de desarrollo esa solicitud ya tiene `datos_entrega`; viola el uno a uno
  (`duplicate key value violates unique constraint`).

Un perfil de desarrollo siembra solo una parte del catalogo, asi que una prueba contra
PostgreSQL no puede asumir que el seed dejo un pasajero ni una moto DELIVERY.

### Correccion

- Nuevo helper `backend/src/test/java/com/taxiuap/backend/testsupport/DatosPruebaDelivery.java`
  que crea sus propios datos con valores unicos (sufijo UUID para correo, usuario y placa):
  `tipoMoto()` (busca o crea el catalogo MOTO), `categoriaDelivery()`, `crearPasajero()`,
  `crearConductorAprobado()`, `crearMotoDelivery(categoria)` y
  `crearSolicitud(categoria, pasajero, precioSugerido)` con origen y destino, que son NOT NULL.
- `OfertaViajeDeliveryPersistenciaTest` y `SolicitudViajeConcurrenteDeliveryTest` usan el helper.
- `DatosEntregaPersistenciaTest` deja de tomar una solicitud existente.
- `SolicitudViajeConcurrenteDeliveryTest.limpiarSolicitud` corrige el orden: primero borra
  `datos_entrega` y la solicitud, y solo despues la categoria. Antes la borraba primero y
  PostgreSQL rechazaba el borrado por la FK de `solicitud_viaje`. Esto tambien cierra el
  hallazgo menor de la re-revision sobre datos que quedaban en la base.

### Evidencia

Focalizado, con perfil `appu`:

    SPRING_PROFILES_ACTIVE=appu ./gradlew test --rerun-tasks \
      --tests 'com.taxiuap.backend.trip.service.OfertaViajeDeliveryPersistenciaTest' \
      --tests 'com.taxiuap.backend.trip.repository.SolicitudViajeConcurrenteDeliveryTest' \
      --console=plain
    BUILD SUCCESSFUL in 40s

Suite completa, con perfil `appu`:

    SPRING_PROFILES_ACTIVE=appu ./gradlew test --console=plain
    BUILD SUCCESSFUL in 36s
    tests=107 failures=0 errors=0 skipped=0 classes=28

Esto verifica con PostgreSQL real que:

- la aceptacion DELIVERY persiste el viaje `CONFIRMADO` con moto DELIVERY, tarifa tecnica de
  zona nula con base `4.00`, precio final `17.50` y la respuesta al repartidor sin codigos;
- la tarifa tecnica se resuelve aunque la categoria DELIVERY se cree despues del arranque;
- dos transacciones concurrentes producen exactamente un UPDATE de 1 fila y otro de 0, y la
  solicitud queda `ACEPTADA`;
- `datos_entrega` es uno a uno con `solicitud_viaje`.

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
