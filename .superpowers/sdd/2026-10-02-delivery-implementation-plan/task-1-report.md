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
