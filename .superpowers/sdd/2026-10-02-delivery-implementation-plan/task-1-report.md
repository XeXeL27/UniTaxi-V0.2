# Task 1 Report

## Implementación

- Se agregaron los enums `TipoEnvio` y `EstadoEntrega`.
- Se creó `DatosEntrega` como entidad auditable con tabla `datos_entrega`, relación 1-1 lazy y FK única a `SolicitudViaje`.
- Se mantuvieron origen y destino exclusivamente en `SolicitudViaje` y se agregó su relación inversa lazy.
- Se agregaron descripción, remitente, receptor, códigos independientes, costos, política, puntos y detalles de compra, evidencia y estado de entrega.
- Se agregaron `DatosEntregaRequest`, `DatosEntregaResponse` y `DatosEntregaRepository`.
- Se agregó el límite `limite_adelanto_compra` al conductor y se expone en `PerfilConductorResponse`.
- Se agregó la validación de que `DELIVERY` solo se cree o actualice sobre `MOTO`.
- Se agregó `DELIVERY` al catálogo seed y la moto de prueba quedó asociada a esa categoría con límite de adelanto de Bs 100.

## Evidencia TDD

### RED

Comando:

```text
./gradlew test --tests '*Entrega*'
```

Resultado inicial: compilación de tests fallida porque no existían `DatosEntrega`, `TipoEnvio` ni `EstadoEntrega`, y el test usaba el paquete Jackson 2 que no está disponible en Spring Boot 4. El fallo era esperado porque las interfaces del modelo todavía no estaban implementadas.

Durante el ciclo también se observó un fallo de comportamiento esperado en validaciones condicionales; se corrigió el nombre JavaBean de los métodos anotados con `@AssertTrue` y se volvió a ejecutar el test.

### GREEN

Comandos:

```text
./gradlew test --tests '*Entrega*'
./gradlew compileJava
```

Resultado: ambos comandos terminaron con `BUILD SUCCESSFUL`; las 5 pruebas focalizadas pasan.

## Archivos cambiados

- `backend/src/main/java/com/taxiuap/backend/trip/enums/TipoEnvio.java`
- `backend/src/main/java/com/taxiuap/backend/trip/enums/EstadoEntrega.java`
- `backend/src/main/java/com/taxiuap/backend/trip/entity/DatosEntrega.java`
- `backend/src/main/java/com/taxiuap/backend/trip/entity/SolicitudViaje.java`
- `backend/src/main/java/com/taxiuap/backend/trip/repository/DatosEntregaRepository.java`
- `backend/src/main/java/com/taxiuap/backend/trip/dto/DatosEntregaRequest.java`
- `backend/src/main/java/com/taxiuap/backend/trip/dto/DatosEntregaResponse.java`
- `backend/src/main/java/com/taxiuap/backend/vehicle/entity/CategoriaServicio.java`
- `backend/src/main/java/com/taxiuap/backend/vehicle/service/CategoriaServicioService.java`
- `backend/src/main/java/com/taxiuap/backend/identity/entity/Conductor.java`
- `backend/src/main/java/com/taxiuap/backend/identity/dto/PerfilConductorResponse.java`
- `backend/src/main/java/com/taxiuap/backend/identity/service/PerfilConductorService.java`
- `backend/src/main/java/com/taxiuap/backend/seed/SeedCatalogos.java`
- `backend/src/main/java/com/taxiuap/backend/seed/SeedUsuarios.java`
- `backend/src/test/java/com/taxiuap/backend/trip/entity/DatosEntregaTest.java`
- `backend/src/test/java/com/taxiuap/backend/trip/dto/DatosEntregaDtoTest.java`
- `backend/src/test/java/com/taxiuap/backend/vehicle/entity/CategoriaServicioEntregaTest.java`
- `docs/CHANGELOG.md`

## Suite backend

Comando:

```text
./gradlew test
```

Resultado: 67 pruebas ejecutadas, 1 fallo en `TaxiuapApplicationTests.contextLoads()`. La causa raíz está en la conexión de la configuración local al PostgreSQL: `FATAL: password authentication failed for user "postgres"`. No se modificó `application.properties`, conforme a la instrucción de la tarea, y el archivo ya tenía un cambio preexistente.

## Auto-revisión

- El diff se limita al modelo, catálogo, seed y pruebas de Task 1; no se modificó `main`.
- No se agregaron servicios de flujo, precios, endpoints ni cambios de app, que corresponden a tareas posteriores.
- Las pruebas verifican validaciones de entidad, exclusividad MOTO y serialización de DTO.

## Preocupaciones

- La suite completa no queda verde hasta corregir las credenciales locales de PostgreSQL fuera de esta tarea; las pruebas focalizadas y la compilación Java sí pasan.
- La persistencia contra una base real no pudo verificarse por ese mismo bloqueo ambiental.

## Fix Report · Reviewer

### Cambios

- `VehiculoService` ahora rechaza DELIVERY cuando el tipo persistido no es MOTO, además de validar la correspondencia categoría-tipo.
- `RegistroMotoConductorService` protege también la ruta de persistencia de alta de vehículo frente a una categoría DELIVERY incompatible.
- `Conductor.limiteAdelantoCompra` es obligatorio, no negativo y `NOT NULL` en el mapeo.
- `DatosEntregaRequest` aplica la misma regla condicional que la entidad: COMPRA_Y_ENTREGA exige costo estimado estrictamente mayor que cero; ENCOMIENDA no acepta costo positivo.
- Se corrigió el contador del log del seeder de categorías de servicio: 4.
- Se agregaron pruebas de rechazo DELIVERY no-MOTO, validación del límite, validación del request y persistencia JPA de la relación 1-1 con FK única.

### Archivos

- `backend/src/main/java/com/taxiuap/backend/vehicle/service/VehiculoService.java`
- `backend/src/main/java/com/taxiuap/backend/vehicle/service/RegistroMotoConductorService.java`
- `backend/src/main/java/com/taxiuap/backend/identity/entity/Conductor.java`
- `backend/src/main/java/com/taxiuap/backend/trip/dto/DatosEntregaRequest.java`
- `backend/src/main/java/com/taxiuap/backend/seed/SeedCatalogos.java`
- `backend/src/test/java/com/taxiuap/backend/vehicle/service/VehiculoEntregaTest.java`
- `backend/src/test/java/com/taxiuap/backend/identity/entity/ConductorEntregaTest.java`
- `backend/src/test/java/com/taxiuap/backend/trip/dto/DatosEntregaRequestTest.java`
- `backend/src/test/java/com/taxiuap/backend/trip/repository/DatosEntregaPersistenciaTest.java`

### Verificación

- RED: `./gradlew test --tests '*Entrega*'` falló en las pruebas nuevas por reglas ausentes y en la prueba JPA por credenciales no suministradas.
- GREEN focalizado: `./gradlew test --tests 'com.taxiuap.backend.trip.entity.DatosEntregaTest' --tests 'com.taxiuap.backend.trip.dto.DatosEntregaDtoTest' --tests 'com.taxiuap.backend.trip.dto.DatosEntregaRequestTest' --tests 'com.taxiuap.backend.vehicle.entity.CategoriaServicioEntregaTest' --tests 'com.taxiuap.backend.vehicle.service.VehiculoEntregaTest' --tests 'com.taxiuap.backend.identity.entity.ConductorEntregaTest'` terminó `BUILD SUCCESSFUL`.
- Persistencia real: `TAXIUAP_DB_PASSWORD='<12346578>' ./gradlew test --tests 'com.taxiuap.backend.trip.repository.DatosEntregaPersistenciaTest'` terminó `BUILD SUCCESSFUL`.
- Focalizado completo: `TAXIUAP_DB_PASSWORD='<12346578>' ./gradlew test --tests '*Entrega*'` terminó `BUILD SUCCESSFUL`.
- Compilación: `./gradlew compileJava` terminó `BUILD SUCCESSFUL`.
- Suite backend: `TAXIUAP_DB_PASSWORD='<12346578>' ./gradlew test` terminó `BUILD SUCCESSFUL`.

### Preocupaciones

- La prueba JPA requiere que el entorno proporcione `TAXIUAP_DB_PASSWORD`; no se modificó `application.properties`.
