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
