# Reporte de implementación Task 7 DELIVERY

## Implementación

- Se conectaron las acciones del repartidor con los endpoints actuales: validar recogida, proponer y registrar compra, confirmar pago, validar entrega, identificar receptor y reportar fallas.
- Se añadió el multipart para la parte JSON `compra` y el recibo opcional, además de la observación de compra.
- El panel del repartidor separa encomienda de compra y entrega, no muestra códigos provenientes del modelo y exige foto más motivo para fallas o paquete no coincidente.
- Se evitó que el GPS ejecute la finalización genérica en viajes DELIVERY y se corrigió la actualización de datos de entrega durante el sondeo.
- El resultado de una entrega completada o cancelada vuelve correctamente a la lista del conductor.
- Las solicitudes DELIVERY siguen dependiendo del filtrado backend vigente por moto y límite de adelanto; no se duplicó esa regla en la app.

## Archivos cambiados

- `app-movil/lib/comun/modelos_viaje.dart`
- `app-movil/lib/core/cliente_api.dart`
- `app-movil/lib/modulos/conductor/viaje/acciones_delivery.dart`
- `app-movil/lib/modulos/conductor/viaje/conductor_api.dart`
- `app-movil/lib/modulos/conductor/viaje/flujo_conductor.dart`
- `app-movil/lib/modulos/conductor/viaje/panel_delivery_conductor.dart`
- `app-movil/lib/modulos/conductor/viaje/paneles_conductor.dart`
- `app-movil/lib/modulos/pasajero/viaje/paneles_pasajero.dart`

## Verificación diferida

Por instrucción explícita, quedaron diferidos los tests Dart, `flutter test`, análisis, builds y pruebas manuales en Chrome. La revisión realizada fue únicamente lectura del diff y de los contratos backend existentes.

## Bloqueos y preocupaciones

- El requerimiento solicitaba códigos aleatorios de 8 dígitos y el backend generaba 6. Corrección 2026-10-05 (commit `4b9b463`): el contrato del usuario es de **exactamente 6 dígitos aleatorios e independientes** (teléfono, CI e ids no intervienen) y ahora ambos extremos están alineados: `ValidarCodigoEntregaRequest` y `DatosEntrega.PATRON_CODIGO` piden 6, `SolicitudViajeService.codigo()` genera 6, y la app valida 6 (`ValidadorCodigoDelivery`, `maxLength: 6`). Este reporte queda como registro de lo que Task 7 dejó desalineado.
- El backend actual solo expone `comprobante` opcional al registrar compra; no existe endpoint separado para foto de producto o comercio. La app no inventa ese endpoint y solo permite el recibo soportado por el contrato.
- No se modificaron ni incluyeron en el commit los tests, backend, configuración, README, reportes previos ni cambios preexistentes ajenos a Task 7.

## Commit

- `9451bb5 feat: add driver delivery flow`
