# Diseño: módulo DELIVERY en UniTaxi (fase 1)

- Fecha: 2026-10-02
- Estado: diseño consolidado; listo para convertir en plan de implementación
- Alcance: entregas con moto propia, separadas de taxis y de FLETE
- Decisiones incorporadas: precio, códigos, compra, límites, cancelaciones, reportes y
  resolución administrativa

## 1. Objetivo y alcance

DELIVERY permite solicitar una entrega con una moto habilitada para la categoría
`DELIVERY`. La fase 1 contempla dos tipos de pedido:

- `ENCOMIENDA`: el cliente entrega un paquete en A y se transporta hasta B.
- `COMPRA_Y_ENTREGA`: el cliente solicita un producto, el repartidor coordina dónde
  comprarlo, lo adelanta con su propio dinero y lo entrega en B.

La plataforma registra el pedido, el seguimiento, el costo del servicio, la comisión y
los incidentes. El dinero se paga directamente al repartidor en la entrega, en efectivo
o mediante el QR del repartidor. No existe pasarela de pagos en esta fase.

FLETE es un módulo separado y queda fuera de este diseño. Los conductores con moto
`ESTANDAR` no ven ni aceptan solicitudes `DELIVERY`.

## 2. Participantes y categoría

- `categoria_servicio` incorpora `DELIVERY`, vinculada únicamente a `MOTO`.
- Solo conductores aprobados con una moto registrada en categoría `DELIVERY` reciben
  solicitudes DELIVERY.
- La categoría de la moto la asigna el administrador al habilitarla.
- El repartidor usa el mismo registro de conductor: CI, licencia M, carnet, teléfono y
  documentos correspondientes.
- Cada repartidor DELIVERY define en su perfil un `limite_adelanto_compra` en Bs.
  Representa el máximo que está dispuesto a adelantar para un pedido de compra.
- Una solicitud `COMPRA_Y_ENTREGA` no se muestra a repartidores cuyo límite sea menor
  que el costo estimado del producto.

## 3. Datos de la entrega

Entidad nueva `datos_entrega`, relación 1-1 con `solicitud_viaje` y solo válida cuando
la categoría de servicio es `DELIVERY`.

### Datos comunes

- `tipo_envio`: `ENCOMIENDA` o `COMPRA_Y_ENTREGA`.
- `descripcion`: contenido del paquete o producto solicitado.
- `costo_producto_estimado`: monto estimado del producto en Bs; obligatorio en
  `COMPRA_Y_ENTREGA`, cero o nulo en `ENCOMIENDA`.
- `costo_producto_real`: monto que el repartidor pagó; obligatorio antes de completar
  una compra.
- `foto_paquete_url`: foto opcional del paquete en ENCOMIENDA.
- `estado_entrega`: `PENDIENTE_RECOGIDA`, `EN_CAMINO_RECOGIDA`, `EN_MANO`,
  `ENTREGADO` o `NO_ENTREGADO`.
- `foto_falla_url`: evidencia obligatoria al usar "No se pudo entregar".
- `motivo_falla`: motivo registrado al no entregar.

### Datos de ENCOMIENDA

- `solicitud_viaje.origen`: Point A (recogida).
- `solicitud_viaje.destino`: Point B (entrega).
- `solicitud_viaje.origen_direccion` y `destino_direccion` conservan las direcciones
  mostradas; no se duplican estos campos en `datos_entrega`.
- `nombre_remitente` y `telefono_remitente`.
- `nombre_receptor` y `telefono_receptor`.
- `codigo_recogida`: código de 6 dígitos para validar que el remitente entrega el
  paquete.
- `codigo_entrega`: código de 6 dígitos para validar que el receptor recibe el paquete.
- El remitente ve únicamente el código de recogida.
- El receptor ve únicamente el código de entrega.
- El repartidor no ve los códigos en la pantalla antes de que la persona se los dicte.

El precio A -> B queda fijo al crear la solicitud. El código de recogida únicamente
confirma la entrega física del paquete y no modifica el precio.

El cliente declara el contenido y puede agregar una foto, pero la foto no es obligatoria.
También confirma que el paquete cabe en una moto y que no contiene artículos prohibidos.

### Datos de COMPRA_Y_ENTREGA

- `solicitud_viaje.destino`: Point B.
- `nombre_receptor` y `telefono_receptor` no se solicitan: el receptor siempre es el
  cliente que creó el pedido.
- `punto_compra_propuesto`: comercio o ubicación propuesta por el repartidor antes de
  comprar, cuando exista.
- `detalle_compra_propuesto`: nombre o descripción del comercio propuesto.
- `punto_compra`: ubicación GPS real donde el repartidor compró el producto.
- `detalle_compra`: nombre real del comercio.
- `costo_producto_estimado`: monto declarado inicialmente por el cliente.
- `costo_producto_real`: monto pagado por el repartidor.
- `foto_comprobante_url`: foto opcional del recibo. Los comercios informales pueden no
  entregar comprobante.
- `observacion_compra`: explicación opcional cuando no existe recibo o hay una
  particularidad de la compra.

El cliente describe el producto y el repartidor coordina el comercio. Antes de pagar,
el cliente debe confirmar el comercio, el producto y el monto estimado. Si el monto
real supera el monto confirmado, el repartidor no compra hasta recibir una nueva
confirmación. No se acepta ninguna diferencia automática.

## 4. Estados del pedido

Se reutilizan los estados actuales de `viaje`:

```text
CONFIRMADO -> CONDUCTOR_EN_CAMINO -> CONDUCTOR_LLEGO -> EN_CURSO
                                                        -> COMPLETADO
```

El campo `datos_entrega.estado_entrega` aporta el detalle propio de DELIVERY:

| Estado de entrega | ENCOMIENDA | COMPRA_Y_ENTREGA |
|---|---|---|
| `PENDIENTE_RECOGIDA` | Solicitud creada, falta recoger en A | Falta comprar |
| `EN_CAMINO_RECOGIDA` | Repartidor aceptó y va a A | Repartidor coordina la compra |
| `EN_MANO` | Código de recogida validado | Cliente confirmó y repartidor compró |
| `ENTREGADO` | Código de entrega validado | Cliente identificado y pago recibido |
| `NO_ENTREGADO` | No se pudo entregar | No se pudo entregar |

Transiciones principales:

- Al aceptar el viaje: `PENDIENTE_RECOGIDA` -> `EN_CAMINO_RECOGIDA`.
- ENCOMIENDA: código de recogida correcto en A -> `EN_MANO` y viaje `EN_CURSO`.
- COMPRA_Y_ENTREGA: compra confirmada y registrada -> `EN_MANO`, `punto_compra`
  obligatorio y viaje `EN_CURSO`.
- ENCOMIENDA: código de entrega correcto en B y pago confirmado -> `ENTREGADO` y
  viaje `COMPLETADO`.
- COMPRA_Y_ENTREGA: cliente identificado y pago confirmado -> `ENTREGADO` y viaje
  `COMPLETADO`.
- Fallo de entrega autorizado -> `NO_ENTREGADO` y viaje `CANCELADO`.

El servidor debe validar que solo el repartidor asignado puede avanzar el pedido y que
cada transición ocurre una sola vez.

## 5. Precio del servicio

La distancia se obtiene por calles mediante OSRM. Si OSRM no responde, la solicitud no
puede continuar ni fijar precio; no se utiliza distancia en línea recta como respaldo.

### ENCOMIENDA

- El precio se calcula al crear la solicitud sobre la ruta A -> B.
- El precio queda fijo desde la solicitud.
- El tramo del GPS del repartidor hasta A no se cobra.
- El código de recogida no modifica el precio.

### COMPRA_Y_ENTREGA

- Antes de asignar repartidor no hay un precio definitivo.
- Al asignarse el repartidor se muestra un estimado usando su GPS actual -> B.
- El estimado es informativo, no es el precio definitivo y se identifica claramente
  como estimado.
- Al confirmar "Ya tengo el pedido", se calcula y fija el precio definitivo desde
  `punto_compra` real -> B.
- El trayecto del repartidor hasta el comercio no se cobra.
- Después de fijarse, el precio del servicio no disminuye ni aumenta por los reportes
  posteriores de GPS.

El precio de la plataforma se registra separado del costo del producto:

```text
total_cliente = costo_producto_real + precio_servicio_final
comision = precio_servicio_final * porcentaje_comision
ganancia_repartidor = precio_servicio_final - comision
```

La comisión inicial de DELIVERY es 0%, igual que la configuración actual. Debe quedar
preparada para configurarse posteriormente, sin aplicar comisión al producto.

## 6. Flujo de COMPRA_Y_ENTREGA

1. El cliente indica el producto, la descripción, el monto estimado y B.
2. La solicitud solo se muestra a repartidores cuyo límite de adelanto alcanza el
   monto estimado.
3. El repartidor acepta y coordina el comercio con el cliente.
4. El cliente confirma producto, comercio y monto estimado.
5. El repartidor compra y registra `punto_compra`, comercio y costo real.
6. Si el costo real es mayor, debe detenerse y obtener una nueva confirmación; sin ella,
   no compra y cancela antes de tener el pedido.
7. El repartidor marca "Ya tengo el pedido"; se fija el precio comercio -> B.
8. El cliente recibe el pedido verificando nombre y teléfono visibles en la app.
9. El repartidor registra el pago total recibido: producto + servicio.
10. El viaje pasa a `COMPLETADO`.

La foto de recibo es opcional. Si el comercio no entrega recibo, el repartidor puede
registrar una observación y, si lo considera necesario, una foto del producto o del
comercio.

## 7. Flujo de ENCOMIENDA

1. El cliente indica A, B, contenido, remitente y receptor.
2. El cliente acepta la política de artículos prohibidos y declara que el paquete cabe
   en una moto.
3. La app calcula y fija el precio A -> B con OSRM.
4. El repartidor acepta y va a A.
5. El remitente dicta el código de recogida; el repartidor lo introduce.
6. Si el código es correcto, el pedido pasa a `EN_MANO` y el viaje a `EN_CURSO`.
7. El repartidor lleva el paquete a B.
8. El receptor dicta el código de entrega.
9. Si el código es correcto, el repartidor recibe el pago y confirma la entrega.
10. El pedido pasa a `ENTREGADO` y el viaje a `COMPLETADO`.

## 8. Cancelaciones y fallos

| Fase | Cliente | Repartidor |
|---|---|---|
| Solicitud `PENDIENTE` o `CON_OFERTAS` | Puede cancelar | No aplica |
| Aceptado, sin recoger ni comprar | Puede cancelar sin compensación | Puede cancelar; se republica el mismo pedido |
| Pedido en mano (`EN_MANO`) | No puede cancelar | Solo puede usar "No se pudo entregar" |

La cancelación temprana no genera compensación automática al repartidor. La solicitud
republicada conserva los datos originales y ambos códigos; se reinician únicamente los
datos operativos del repartidor. No se conservan `punto_compra`, costo real ni fotos de
una compra que no llegó a realizarse.

### No se pudo entregar

El repartidor puede usar esta acción después de tener el paquete únicamente cuando:

- el receptor no está en B o no responde después de esperar 10 minutos y realizar dos
  intentos de contacto;
- el receptor no paga el total; o
- existe otro impedimento real para completar la entrega.

La acción exige una foto y un motivo. Después:

- `estado_entrega` pasa a `NO_ENTREGADO`;
- el viaje pasa a `CANCELADO`;
- la solicitud pasa a `CANCELADA` y no se republica;
- se crea un `Reporte` en estado `PENDIENTE`;
- se conserva `costo_producto_real` cuando ya hubo compra.

La plataforma no cobra ni paga automáticamente. El admin contacta a las partes y
registra la resolución del caso fuera de la app. Las resoluciones permitidas son:
`DEVOLUCION_AL_REMITENTE`, `CLIENTE_PAGO_DIRECTO`, `REPARTIDOR_ASUME_PERDIDA`,
`CLIENTE_NO_RESPONDIO` u `OTRO`, con observación libre.

### Paquete que no coincide

Si el paquete no coincide con la descripción o no cabe en la moto, el repartidor puede
rechazarlo sin transportarlo. Debe registrar el motivo y una evidencia. Se crea un
reporte sobre el cliente y la solicitud se cancela sin republicarse. Inicialmente la
consecuencia es una advertencia y registro de reincidencia; no hay suspensión automática
ni cobro automático.

## 9. Reportes y administración

Se reutiliza la entidad `Reporte`, vinculada al viaje. La evidencia operativa queda en
`datos_entrega` (`foto_falla_url`, `motivo_falla`, `costo_producto_real`), y el reporte
registra el incidente y su resolución.

El diseño debe contemplar en el reporte la resolución administrativa:

- situación: `PENDIENTE`, `EN_REVISION`, `RESUELTO`, `CERRADO`;
- tipo de resolución;
- observación del admin;
- fecha e identidad del admin que resolvió.

El admin puede consultar la foto de fallo, datos del viaje, costo real, dirección B,
teléfono del contacto e historial del reporte. El admin inicialmente solo registra el
resultado de la gestión; no procesa dinero.

Las cancelaciones repetidas del repartidor se registran. En fase 1 no se aplica sanción
automática; el admin puede revisar el patrón posteriormente.

## 10. Seguimiento y chat

- El cliente ve al repartidor en el mapa mediante el seguimiento existente.
- ENCOMIENDA muestra el tramo del repartidor hasta A y luego A -> B.
- COMPRA_Y_ENTREGA muestra el seguimiento del repartidor; después de `punto_compra`
  muestra la ruta real comercio -> B.
- Los precios definitivos no cambian por reportes posteriores de GPS.
- El chat es efímero y muestra el aviso: "El chat no se guarda: los mensajes se pierden
  cuando termina el viaje."
- Las fotos de chat se suben por REST, comprimidas; no se envían por WebSocket.
- El admin no puede leer el chat efímero.

## 11. Validaciones de seguridad

- Solo una moto puede operar como DELIVERY si su categoría es DELIVERY.
- Solo conductores aprobados pueden aceptar pedidos.
- El pedido no se puede aceptar si el monto estimado supera el límite del repartidor.
- Solo el repartidor asignado puede registrar compra, códigos, costo real, pago o fallo.
- El pedido no se puede modificar después de aceptar; el cliente debe cancelar y crear
  otro.
- El código de recogida y el código de entrega se comparan en el servidor y no se
  exponen antes de la interacción correspondiente.
- No se puede marcar `ENTREGADO` sin código correcto en ENCOMIENDA.
- No se puede marcar `ENTREGADO` sin confirmación del pago por el repartidor.
- No se puede cancelar libremente con `estado_entrega = EN_MANO`.
- La foto y el motivo son obligatorios en `NO_ENTREGADO`.
- El servidor debe impedir transiciones duplicadas o fuera de orden.
- El cliente acepta la política de artículos prohibidos antes de crear una ENCOMIENDA.

## 12. Pruebas de aceptación

### Visibilidad y límites

- Una moto ESTANDAR no ve solicitudes DELIVERY.
- Una moto DELIVERY sí ve solicitudes DELIVERY.
- Una solicitud de compra superior al límite del repartidor no se muestra.
- Un repartidor no aprobado no puede aceptar.

### Precio

- ENCOMIENDA calcula A -> B con OSRM y fija el precio al crear.
- El trayecto del repartidor hasta A no se suma.
- COMPRA_Y_ENTREGA muestra estimado GPS del repartidor -> B después de asignarlo.
- Al registrar compra, calcula y fija comercio -> B.
- Un fallo de OSRM impide crear o fijar el precio.
- El GPS posterior no modifica el precio definitivo.
- La comisión inicial es 0% y nunca se aplica al producto.

### Códigos y entrega

- ENCOMIENDA genera códigos independientes de recogida y entrega.
- Cada parte ve únicamente su código.
- Código de recogida incorrecto no permite pasar a `EN_MANO`.
- Código de entrega incorrecto no permite completar.
- COMPRA_Y_ENTREGA valida nombre y teléfono del cliente.
- El repartidor confirma el pago antes de completar.

### Compra

- El cliente confirma comercio, producto y monto antes de la compra.
- Cualquier aumento exige nueva confirmación.
- El recibo puede faltar sin bloquear el flujo.
- El repartidor puede registrar monto, observación y foto opcional.

### Cancelaciones y reportes

- El cliente cancela libremente antes de que el pedido esté en mano.
- No existe compensación automática por cancelación temprana.
- El repartidor puede republicar antes de recoger/comprar.
- La republicación conserva códigos y datos originales.
- Con `EN_MANO`, el cliente no puede cancelar.
- "No se pudo entregar" exige foto y motivo, cancela y no republica.
- Receptor ausente exige 10 minutos y dos intentos de contacto.
- Cliente que no paga no recibe el pedido y genera reporte.
- Paquete incorrecto genera reporte y advertencia.
- El admin puede cerrar el reporte registrando la resolución fuera de la app.

## 13. Fuera de alcance de fase 1

- Pasarela de pagos, cobros automáticos, deudas o compensaciones dentro de la app.
- Catálogo de comercios, integración con comercios o comisión por venta.
- Pago anticipado del producto por la plataforma.
- Entregas a terceros en COMPRA_Y_ENTREGA.
- Reparto multidestino.
- Camionetas o carga grande; corresponde a FLETE.
- Sanciones automáticas por cancelaciones repetidas.
- Foto obligatoria de entregas exitosas.
