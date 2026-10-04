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
