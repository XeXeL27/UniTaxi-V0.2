# Task 2 Report

## Implementación

- Se creó `ClienteRutas` y `ClienteOsrm`, con timeout configurable, respuesta tipada de distancia/duración y rechazo de respuestas HTTP o OSRM inválidas.
- Se creó `CalculoPrecioDeliveryService` para calcular y fijar ENCOMIENDA A-B, estimar COMPRA_Y_ENTREGA GPS-B y fijar comercio-B.
- El cálculo usa tarifa base, precio por kilómetro y precio por minuto configurables, con redondeo monetario a dos decimales.
- La comisión DELIVERY es configurable y por defecto 0%; el costo del producto queda fuera de la comisión.
- Se expuso `limiteAdelantoCompra` en la actualización del perfil del conductor y se agregó el predicado de compatibilidad del monto estimado.
- Se hizo configurable la URL de OSRM en la app móvil mediante `OSRM_URL`.

## Evidencia TDD

### RED

Comando:

```text
./gradlew test --tests 'com.taxiuap.backend.pricing.service.CalculoPrecioDeliveryServiceTest'
```

Resultado inicial: falló la compilación de tests porque no existían `DesglosePrecioDelivery` ni `RutaResponse`. El fallo era esperado porque las interfaces de cálculo todavía no estaban implementadas.

### GREEN

Comandos:

```text
./gradlew test --tests 'com.taxiuap.backend.pricing.service.*'
./gradlew compileJava
```

Resultado: ambos terminaron con `BUILD SUCCESSFUL`; pasan las 2 clases focalizadas, con 6 pruebas en total.

## Archivos cambiados

- `backend/src/main/java/com/taxiuap/backend/pricing/dto/RutaResponse.java`
- `backend/src/main/java/com/taxiuap/backend/pricing/dto/DesglosePrecioDelivery.java`
- `backend/src/main/java/com/taxiuap/backend/pricing/service/ClienteRutas.java`
- `backend/src/main/java/com/taxiuap/backend/pricing/service/ClienteOsrm.java`
- `backend/src/main/java/com/taxiuap/backend/pricing/service/CalculoPrecioDeliveryService.java`
- `backend/src/main/java/com/taxiuap/backend/identity/dto/ActualizarPerfilConductorRequest.java`
- `backend/src/main/java/com/taxiuap/backend/identity/service/PerfilConductorService.java`
- `backend/src/main/resources/application-xexel.properties`
- `backend/src/main/resources/application-xexel.properties.example`
- `app-movil/lib/core/config.dart`
- `app-movil/lib/mapa/servicios_mapa.dart`
- `backend/src/test/java/com/taxiuap/backend/pricing/service/CalculoPrecioDeliveryServiceTest.java`
- `backend/src/test/java/com/taxiuap/backend/pricing/service/ClienteOsrmTest.java`
- `docs/CHANGELOG.md`

## Suite backend

Comando:

```text
./gradlew test
```

Resultado: 77 pruebas ejecutadas, 2 fallos en `TaxiuapApplicationTests.contextLoads()` y `DatosEntregaPersistenciaTest.persisteLaRelacionUnoAUnoYRecuperaElMapeo()`. Ambos fallos ocurren al crear el contexto Hibernate por la autenticación/configuración de PostgreSQL local. No se modificó `application.properties`.

## Auto-revisión

- El diff se limita a cálculo/rutas/configuración DELIVERY, perfil del conductor, app URL de OSRM, pruebas y documentación.
- No se implementó integración del flujo de solicitud/oferta, que corresponde a Task 3.
- El backend no usa distancia en línea recta cuando OSRM falla.

## Preocupaciones

- La suite completa requiere las credenciales locales de PostgreSQL disponibles en el entorno; las pruebas focalizadas y `compileJava` pasan.

## Fix Report · Hallazgos directos de Task 2

### Cambios

- `ServiciosMapa.calcularRuta` ya no genera una línea recta ni una duración aproximada cuando OSRM falla; propaga `RutaNoDisponibleException` y bloquea la operación.
- El cliente móvil valida que distancia, duración y geometría de OSRM sean utilizables antes de crear una `Ruta`.
- `RutaResponse` valida que distancia y duración sean no nulas y no negativas; `ClienteOsrm` propaga el fallo como `NegocioException`.
- No se implementaron listado real de solicitudes ni snapshot de precio; quedan para Task 3 y Task 4.

### Tests y comandos

#### RED

```text
./gradlew test --tests 'com.taxiuap.backend.pricing.service.ClienteOsrmTest'
```

Resultado: 2 pruebas nuevas fallaron porque el cliente aceptaba distancia y duración negativas de OSRM.

El primer `flutter test` posterior al cambio falló en compilación porque la rama HTTP no-200 podía salir de `calcularRuta` sin retorno; se corrigió haciendo que esa rama también lance `RutaNoDisponibleException`.

#### GREEN

```text
./gradlew test --tests 'com.taxiuap.backend.pricing.service.*'
./gradlew compileJava
flutter test
```

Salida verificada: `BUILD SUCCESSFUL` en los dos comandos Gradle, `All tests passed!` en Flutter y 70 pruebas Dart ejecutadas.

### Archivos del fix

- `backend/src/main/java/com/taxiuap/backend/pricing/dto/RutaResponse.java`
- `app-movil/lib/mapa/servicios_mapa.dart`
- `backend/src/test/java/com/taxiuap/backend/pricing/service/ClienteOsrmTest.java`
- `.superpowers/sdd/2026-10-02-delivery-implementation-plan/task-2-report.md`
- `docs/CHANGELOG.md`

### Verificación final

- Se mantuvo sin cambios `backend/src/main/resources/application.properties`.
- No se modificaron `main`, el listado real de solicitudes ni el snapshot de precio.
