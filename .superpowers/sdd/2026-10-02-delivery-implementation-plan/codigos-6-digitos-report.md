# Reporte: códigos DELIVERY de seis dígitos

## Implementación

- Se actualizó la generación de códigos DELIVERY a valores aleatorios independientes de exactamente 6 dígitos, conservando la comprobación de desigualdad entre recogida y entrega.
- Se ajustaron la validación backend, las longitudes de columnas y la validación/interfaz de la app móvil.
- Se actualizaron únicamente los literales del test pendiente existente para usar códigos de 6 dígitos.

## Archivos

- `backend/src/main/java/com/taxiuap/backend/trip/service/SolicitudViajeService.java`
- `backend/src/main/java/com/taxiuap/backend/trip/dto/ValidarCodigoEntregaRequest.java`
- `backend/src/main/java/com/taxiuap/backend/trip/entity/DatosEntrega.java`
- `app-movil/lib/modulos/conductor/viaje/acciones_delivery.dart`
- `app-movil/lib/modulos/conductor/viaje/panel_delivery_conductor.dart`
- `backend/src/test/java/com/taxiuap/backend/trip/service/EntregaServicePostgresTest.java`

## Verificación

Queda diferida según la solicitud: no se ejecutaron tests, Gradle, Flutter, analyze ni build.
