# Plan: punto de entrega y mapa de la compra y entrega (DELIVERY)

> **For agentic workers:** REQUIRED SUB-SKILL: usa `subagent-driven-development` para ejecutar
> este plan task por task, con un implementer nuevo y una revision independiente por task.
> Al final, `code-reviewer` sobre la rama completa.

**Goal:** que en COMPRA_Y_ENTREGA el punto de entrega sea donde esta el pasajero (no el destino que
eligio), que el mapa dibujar lo que el repartidor tiene que hacer en cada momento (naranja
punteado hasta el pasajero mientras no compro, ruta desde el comercio cuando compro) y que los datos
que el backend ya envia y la app no pintaba (comercio real, observacion, comprobante, telefono del
cliente) se vean.

**Architecture:** no hay arquitectura nueva. El backend ya tiene `punto_compra`,
`detalle_compra`, `costo_producto_real`, `observacion_compra` y `foto_comprobante_url`, y ya cobra
`punto_compra -> destino`; lo que falta es (a) que en una compra el `destino` de la solicitud sea
donde esta el pasajero, (b) que la app use `punto_compra` como punto de partida del mapa, y (c) dos
campos de exposicion (telefono del cliente solo en compra, y el comprobante). Todo el grueso es
app; el backend crece en un campo del DTO y un endpoint.

**Tech Stack:** Spring Boot 4.1.1, Java 21, JPA/PostGIS, Flutter (app movil), PostgreSQL/PostGIS
en Docker.

**Spec:** `docs/superpowers/specs/2026-10-02-delivery-design.md`. Este plan **cambia** las secciones
4, 5, 6 y 10; ver los Rulings 1 a 4 y la Task 6, que actualiza el spec.

**Contexto:** la revision del panel del reparto del 2026-10-06 (el check de "Recibi Bs X") salio
con cuatro huecos de datos que el backend ya tiene y la app no muestra. Al revisarlos con el
usuario aparecio uno mayor: en COMPRA_Y_ENTREGA el punto de entrega es donde esta el pasajero, pero
la app lo pide como si fuera un destino mas, como en un viaje normal.

**Estado de ejecucion (2026-10-06):** plan escrito, ninguna task implementada.

---

## Rulings (decididos con el usuario)

- **`Ruling 1: en COMPRA_Y_ENTREGA el punto de entrega es la ubicacion del pasajero al pedir, y el
  pasajero deja de elegir destino`** — en compra no hay "destino que elegir": el pedido se entrega
  ahi donde esta quien lo pide. El pasajero ya no toca el mapa para elegir B; el panel lo dice
  ("Se entrega donde estas") y la solicitud se crea con `origen = destino = mi ubicacion`. En
  ENCOMIENDA **no cambia nada**: A = punto de recogida elegido y B = punto de entrega elegido.
  Costo si se interpreta mal: el pasajero no puede pedir que le lleven la compra a otra persona; se
  mitiga con ENCOMIENDA, que es justamente el caso de "mandalo a un tercero".
- **`Ruling 2: antes de que haya repartidor, una compra muestra "A calcular"`** — el estimado sale
  de `estimarCompra(gps del repartidor, destino)` cuando el backend asigna alguien, y el precio real
  se fija con `fijarPrecioCompra(punto_compra, destino)` al registrar la compra. Mostrar la tarifa
  base daria un numero que puede no parecerse en nada a lo que se cobre.
- **`Ruling 3: el punto de entrega queda fijado al pedir`** — si el pasajero se mueve despues, el
  punto no se actualiza y el repartidor va a donde estaba. Es lo simple y lo coherente con el
  precio ya calculado sobre ese destino. Moverlo exigiria un endpoint nuevo, recalcular y avisar de
  cada cambio.
- **`Ruling 4: el mapa dibuja el punto real del comercio, no el propuesto`** — mientras el
  repartidor coordina el comercio, el mapa sigue como esta. A pasa a ser el comercio cuando el
  repartidor registra la compra ("Ya tengo el pedido").
- **`Ruling 5: el telefono del cliente se expone solo en COMPRA_Y_ENTREGA`** — es el unico caso en
  que `validarReceptor` lo compara. En ENCOMIENDA el receptor es un tercero con codigo y el
  telefono no aporta nada.
- **`Ruling 6: el comprobante de la compra lo puede ver el pasajero`** — endpoint nuevo, con la
  seguridad de que el viaje sea suyo.
- **`Ruling 7: no tocar `application*.properties`** — hay una modificacion local ajena (perfil por
  defecto `appu` en vez de `xexel`).

---

## Hallazgos que sostienen el plan

Verificados en el codigo el 2026-10-06. No volver a investigarlos.

| # | Hallazgo | Evidencia |
|---|---|---|
| H1 | `puntoCompraWkt` y `puntoCompraPropuestoWkt` se parsean y no se usan en ninguna parte | `app-movil/lib/comun/modelos_viaje.dart:148-149`; ninguna otra lectura en `app-movil/lib` |
| H2 | El backend fija el precio desde el comercio pero **no** cambia `viaje.origen` | `backend/.../trip/service/ViajeService.java:272-282` (solo precios y distancia) |
| H3 | El mapa dibuja siempre `origen -> destino`, en las cuatro pantallas | `flujo_pasajero.dart:454,501`, `flujo_conductor.dart:229,268`, `historial_viajes.dart:498` (los cuatro usan `puntoA`/`puntoB`) |
| H4 | `tieneRuta` es "origen y destino no nulos", asi que una compra sin A dibujaria una ruta de longitud cero | `modelos_viaje.dart:404,512` |
| H5 | El tramo naranja del repartidor va **hasta A**; si no hay A no se dibuja | `app-movil/lib/mapa/controlador_mapa.dart:345-348` (`final hasta = a?.posicion`) |
| H6 | La linea naranja punteada que se pide ya existe, con ese color y ese patron | `app-movil/lib/mapa/vista_mapa.dart:79-95` (`ColoresApp.rutaSecundaria`, `StrokePattern.dashed`) |
| H7 | El pasajero **tiene que** elegir destino hoy, y el panel se lo exige | `flujo_pasajero.dart:354` (`puedeSolicitar` exige `mapa.b != null`), `flujo_pasajero.dart:382-404`, `paneles_pasajero.dart:98-101` |
| H8 | En entrega el backend nunca usa `origen`: el precio es `estimarCompra(gps, destino)` y luego `fijarPrecioCompra(punto_compra, destino)` | `SolicitudViajeService.java:107-114` (en compra `precioSolicitud = null`), `CalculoPrecioDeliveryService.java:42-48` |
| H9 | La app pide cotizacion de taxi (OSRM) tambien en modo entrega, aunque no la muestre | `flujo_pasajero.dart:110-125` no mira el servicio; `flujo_pasajero.dart:150-159` la ignora para el precio |
| H10 | El repartidor no veria nada en el mapa en una compra sin A | `flujo_conductor.dart:225-229` y `:265-269` cortan con `if (!tieneRuta) return` |
| H11 | `LatLng` tiene `operator ==`, asi que se puede detectar que cambio el punto de partida sin relanzar OSRM en cada sondeo | `latlong2-0.10.1/lib/latlong/LatLng.dart:108-111` |
| H12 | `ViajeResponse` no tiene telefono, y `sinNombreDestino()` reconstruye el record entero | `backend/.../trip/dto/ViajeResponse.java:11-57` |
| H13 | `validarReceptor` compara nombre y (si el cliente tiene telefono) telefono | `backend/.../trip/service/EntregaService.java:421-435` |
| H14 | El modelo ya trae `detalleCompra`, `observacionCompra`, `fotoComprobanteUrl` y `montoPagoRecibido`; la app no los pinta | `modelos_viaje.dart:93-101`; `paneles_pasajero.dart:590-611` es todo lo que ve el pasajero |
| H15 | El admin si ve comercio, costo real, observacion y comprobante, pero en la pantalla de reportes | `admin-panel/lib/modulos/reportes/pantalla_reportes_entrega.dart:107-114` |
| H16 | El panel del repartidor rotula "Recoger en (A)" y "Entregar en (B)" tambien en compra | `app-movil/lib/modulos/conductor/viaje/panel_delivery_conductor.dart:85-86` |
| H17 | El patron para servir una imagen al pasajero ya existe dos veces | `QrPagoConductorController.java:43-47,67-72` (conductor y pasajero) y `ReporteAdminController.java:51-57` |
| H18 | El resumen del pasajero dice "Total estimado" siempre, incluso con el costo real ya registrado | `paneles_pasajero.dart:611` |
| H19 | El diseno define B para compra pero no dice de quien es, ni define ningun A | `docs/superpowers/specs/2026-10-02-delivery-design.md:59-60` (encomienda), `:80` (compra), `:146-156` (precio), `:265-270` (seguimiento), `:179-182` (flujo) |

---

## Global Constraints

- Todo el codigo nuevo en espanol, con `controller -> service -> repository -> entity`.
- Sin emojis en codigo, logs, comentarios, commits, mensajes ni respuestas de API.
- No crear archivos `.sql`, ni Flyway, ni Liquibase. El esquema lo genera Hibernate
  (`ddl-auto=update`).
- No exponer los codigos de recogida ni de entrega en las respuestas de la API (siguen en
  `DatosEntregaResponse.paraConductor`).
- Todo endpoint nuevo valida rol y propietario en el servidor.
- No tocar `application*.properties` (Ruling 7). No imprimir la contrasena de la base.
- Los cuatro rulings de producto (1 a 4) van tambien en el spec: si no, otra sesion los lee como
  un defecto. Task 6.
- **Nunca push.** Lo decide el usuario.

## Entorno y comandos

```bash
# Base de datos (PostGIS en Docker, puerto 5436 del host)
docker ps --format "{{.Names}} {{.Status}} {{.Ports}}"     # taxiuap-db debe estar healthy
docker compose up -d --wait

# Backend. La tarea Gradle `test` NO carga `.env` (solo `bootRun`): pasa la clave explicita.
cd backend
TAXIUAP_DB_PASSWORD='<clave local>' SPRING_PROFILES_ACTIVE=appu ./gradlew test --console=plain
TAXIUAP_DB_PASSWORD='<clave local>' SPRING_PROFILES_ACTIVE=appu ./gradlew build --console=plain
SPRING_PROFILES_ACTIVE=appu ./gradlew bootRun                 # puerto 8080, este si lee `.env`

# Flutter
cd app-movil && flutter test && flutter analyze
cd app-movil && flutter run -d chrome --web-port 5174        # el mapa solo se comprueba en Chrome
```

El mapa no se puede probar en `flutter test`: `ControladorMapa.ponerRuta` y `_trazarAcercamiento`
llaman a OSRM. La Task 3 y la Task 6 necesitan la pasada manual en Chrome.

---

## Comportamiento del mapa que deja este plan

**COMPRA_Y_ENTREGA**

| Momento | Pasajero ve | Repartidor ve |
|---|---|---|
| Pide el pedido | Su punto fijo (B, donde esta), con el punto de su GPS encima; sin A y sin ruta | — |
| Repartidor asignado, sin comprar | Naranja punteado del repartidor en movimiento hasta el pasajero; el pasajero como punto fijo; sin ruta azul | Naranja punteado desde su GPS hasta el pasajero |
| Propone el comercio / el cliente confirma | no cambia (Ruling 4) | no cambia |
| "Ya tengo el pedido" | A = el comercio ("Comercio: ..."), ruta azul comercio -> pasajero, el naranja se detiene | lo mismo, con el tramo naranja hasta el comercio |
| Pago confirmado + receptor | termina el viaje | termina el viaje |

**ENCOMIENDA**: sin cambios. A = recogida elegida, B = entrega elegida, tramo naranja hasta A y
luego A -> B.

---

## File Map

- `app-movil/lib/comun/modelos_viaje.dart`: `DatosEntrega.puntoComercio`, `partida`, `tieneRuta`,
  `puntoA`.
- `app-movil/lib/modulos/pasajero/viaje/flujo_pasajero.dart`: destino de la compra, `puedeSolicitar`,
  `solicitar`, `_revisarCotizacion`, `textoPrecio`, seguimiento del repartidor.
- `app-movil/lib/modulos/pasajero/viaje/paneles_pasajero.dart`: textos del panel y `_ResumenEntrega`.
- `app-movil/lib/modulos/pasajero/viaje/viaje_api.dart`: cliente del comprobante.
- `app-movil/lib/modulos/conductor/viaje/flujo_conductor.dart`: mapa del repartidor.
- `app-movil/lib/modulos/conductor/viaje/panel_delivery_conductor.dart`: etiquetas de A y B, receptor.
- `app-movil/lib/mapa/controlador_mapa.dart`: destino del tramo naranja.
- `backend/.../trip/dto/ViajeResponse.java` y `trip/service/ViajeService.java`: telefono del cliente.
- `backend/.../controller/pasajero/ViajePasajeroController.java`: endpoint del comprobante.
- Tests junto al modulo correspondiente.

---

### Task 1: El modelo sabe cual es el punto de partida real

**Files:**
- Modify: `app-movil/lib/comun/modelos_viaje.dart`
- Modify: `app-movil/test/entrega_test.dart`

**Interfaces:**
- `DatosEntrega.puntoComercio` -> `PuntoRuta?`: `puntoDesdeWkt(puntoCompraWkt)`, con texto
  `Comercio: <detalleCompra>` (o `Comercio` a secas si no hay nombre). `null` hasta que el
  repartidor registra la compra. **No** usa `puntoCompraPropuestoWkt` (Ruling 4).
- `Viaje.partida` / `Solicitud.partida` -> `PuntoRuta?`: el comercio si existe; el origen en
  encomienda y en taxi; **`null` en una compra que todavia no compro** (no hay punto de recogida:
  el diseno solo define B para compra, `:80`).
- `puntoA` usa `partida`; `tieneRuta` pasa a `partida != null && destino != null`. Para encomienda y
  taxi no cambia nada.
- `puntoB` no cambia.

- [ ] Los getters nuevos con su comentario explicando por que `partida` puede ser null.
- [ ] Tests: compra con `puntoCompraWkt` da `partida` = comercio con su texto; compra sin el punto da
      `partida` null y `tieneRuta` false; encomienda y taxi con origen y destino siguen dando
      `tieneRuta` true y `partida` = origen; `puntoA` de una compra con comercio lleva el nombre del
      comercio.
- [ ] `flutter test test/entrega_test.dart` y `flutter analyze`.
- [ ] Commit: `feat: la compra usa el comercio como punto de partida del mapa`.

### Task 2: El pasajero pide una compra sin elegir destino

**Files:**
- Modify: `app-movil/lib/modulos/pasajero/viaje/flujo_pasajero.dart`
- Modify: `app-movil/lib/modulos/pasajero/viaje/paneles_pasajero.dart`
- Modify: `app-movil/lib/modulos/pasajero/inicio/pantalla_inicio.dart` (buscador de destino)
- Create or Modify: test Dart

**Interfaces:**
- `bool get esCompra`: `tipoEnvio == TipoEnvio.compraYEntrega` (ya existe `tipoEnvio`, H7).
- `puedeSolicitar`: en compra deja de exigir `mapa.b != null`; sigue exigiendo `mapa.a != null` (el
  GPS) y el tipo elegido con su formulario completo.
- `solicitar()`: en compra manda `origen = destino = mapa.a` con la direccion de A y
  `destinoNombre = null`. En encomienda, exactamente como hoy.
- `_revisarCotizacion()`: no llama a `api.cotizar` en modo entrega (H9). En compra, `A == B` hace que
  la llamada sea inutil y OSRM puede responder con una ruta de cero.
- `textoPrecio`: en compra, "A calcular" siempre mientras se elige (Ruling 2). El estimado del
  backend llega con el repartidor asignado y el precio real con la compra registrada; ninguno de
  los dos se conoce al pedir. En encomienda sigue mostrando la tarifa del servicio como hoy.
- `PanelEligiendo`: hoy el precio, el selector de pago y el boton de pedir estan **dentro** de
  `if (b != null)` (`paneles_pasajero.dart:69-155`), y en compra no hay `b`. Regla del plan
  (R-PF1): en compra esas tres piezas se muestran igualmente, y la fila del destino se sustituye por
  "Se entrega donde estas". Sin busqueda de destino, sin favoritos y sin "quitar destino".
  **No** se pone `mapa.b = mapa.a` como solucion: `aSigueGps` mueve A con el GPS y dejaria B
  quieto, trazando una ruta falsa y gastando una llamada a OSRM entre dos puntos casi iguales.
- Regla pura y testeable del destino de una compra, junto a las que ya viven fuera de widget
  (como `etiquetaPrecioDelivery`).

- [ ] `esCompra` y la regla pura del destino, con test.
- [ ] `puedeSolicitar`, `solicitar` y `_revisarCotizacion` con la distincion compra/encomienda.
- [ ] Textos del panel y ocultar el buscador de destino en compra.
- [ ] Tests: en compra se puede pedir sin destino; en encomienda no; en compra no se llama a cotizar;
      el precio de una compra dice "A calcular".
- [ ] `flutter test` y `flutter analyze`.
- [ ] Commit: `feat: en compra y entrega el pedido va a donde esta el pasajero`.

### Task 3: El mapa dibuja lo que toca en cada momento

**Files:**
- Modify: `app-movil/lib/mapa/controlador_mapa.dart`
- Modify: `app-movil/lib/modulos/conductor/viaje/flujo_conductor.dart`
- Modify: `app-movil/lib/modulos/pasajero/viaje/flujo_pasajero.dart`
- Create or Modify: test Dart de la regla de re-trazado

**Interfaces:**
- `_trazarAcercamiento` apunta a `a?.posicion ?? b?.posicion`: en una compra sin A, el tramo naranja
  va hasta el pasajero (H5, H6). Comentado, porque parece un error si no se sabe por que.
- Repartidor: `verSolicitud` y `_entrarViaje` no cortan con `!tieneRuta` cuando hay entrega: ponen B
  y el tramo naranja (H10). La distancia del viaje (`paneles_conductor.dart:143`) usa `partida` y
  se oculta cuando no hay partida.
- Al aparecer el punto real del comercio se vuelve a poner la ruta **solo si cambio la posicion de
  A** (H11), para no relanzar OSRM en cada sondeo.
- El tramo naranja se detiene cuando hay ruta real desde el comercio (el reparto ya no "va hacia"
  el punto, sale de ahi). El marcador del repartidor en el mapa del pasajero sigue moviendose.
- `historial_viajes.dart:498` sigue usando `puntoA`/`puntoB`: en el historial de una compra sale la
  ruta desde el comercio. Sin cambios.

- [ ] Destino del tramo naranja cuando no hay A.
- [ ] El repartidor ve el mapa en una compra sin A.
- [ ] Re-trazado solo cuando cambio la posicion de A (regla pura testeable).
- [ ] El naranja se detiene al aparecer la ruta real, en las dos apps.
- [ ] `flutter test`, `flutter analyze`.
- [ ] **Manual en Chrome (obligatorio):** `flutter run -d chrome --web-port 5174`, pedir una compra,
      ver el naranja hasta el pasajero, aceptarla, proponer y confirmar el comercio (el mapa no
      cambia), registrar la compra y ver la ruta desde el comercio.
- [ ] Commit: `feat: el mapa del reparto dibuja el tramo al pasajero y la ruta desde el comercio`.

### Task 4: Los dos paneles dicen la verdad

**Files:**
- Modify: `app-movil/lib/modulos/conductor/viaje/panel_delivery_conductor.dart`
- Modify: `app-movil/lib/modulos/pasajero/viaje/paneles_pasajero.dart`
- Create or Modify: test Dart

**Interfaces:**
- Repartidor: en compra, antes de comprar solo "Entregar en (B)" con la direccion de donde esta el
  pasajero; despues "Comercio (A)" y "Entregar en (B)" (H16). "Confirmar receptor" muestra a quien
  tiene que recibir (el telefono, si el backend lo manda, llega en la Task 5).
- Pasajero, `_ResumenEntrega`: "Total a pagar" cuando hay `costoProductoReal`, "Total estimado"
  mientras no lo haya (H18); "Comercio" y "Observacion del repartidor" cuando llegan (H14);
  "Pago confirmado: Bs X" con `montoPagoRecibido`, que hoy no se pinta en ninguna parte.
- La miniatura del comprobante llega en la Task 5.

- [ ] Etiquetas de A y B del repartidor segun la fase de la compra.
- [ ] El helper del receptor con el nombre del cliente.
- [ ] Total real, comercio y observacion en el resumen del pasajero.
- [ ] Tests de los textos (ya hay `panel_repartidor_test.dart` y cobertura de `paneles_pasajero`).
- [ ] `flutter test`, `flutter analyze`.
- [ ] Commit: `fix: los paneles del reparto dicen el comercio, el total real y la observacion`.

### Task 5: Telefono del cliente y comprobante (backend y app)

**Files:**
- Modify: `backend/src/main/java/com/taxiuap/backend/trip/dto/ViajeResponse.java`
- Modify: `backend/src/main/java/com/taxiuap/backend/trip/service/ViajeService.java`
- Modify: `backend/src/main/java/com/taxiuap/backend/controller/pasajero/ViajePasajeroController.java`
- Modify: `app-movil/lib/comun/modelos_viaje.dart`
- Modify: `app-movil/lib/modulos/conductor/viaje/panel_delivery_conductor.dart`
- Modify: `app-movil/lib/modulos/pasajero/viaje/viaje_api.dart`
- Modify: `app-movil/lib/modulos/pasajero/viaje/paneles_pasajero.dart`
- Create: test del servicio y test de seguridad del endpoint

**Interfaces:**
- `ViajeResponse.telefonoPasajero`: se llena **solo** si `tipoEnvio == COMPRA_Y_ENTREGA` (Ruling 5,
  H13). El record se reconstruye entero en `sinNombreDestino()`, que tambien lo lleva. La respuesta
  solo la reciben las dos partes del viaje, que es lo que hacen `obtenerViajeDelPasajero` y
  `obtenerViajeDelConductor`.
- `GET /api/pasajero/viajes/{id}/entrega/comprobante`: valida que el viaje sea del pasajero y devuelve
  la foto de `datos_entrega.foto_comprobante_url` como `image/jpeg`, con el patron de
  `ReporteAdminController.java:51-57` y `QrPagoConductorController.java:67-72` (H17). Sin foto ->
  404. Sin permiso -> 404, para no filtrar que existe el viaje.
- App: `PasajeroApi.comprobanteEntrega(idViaje) -> Uint8List?` con `cliente.bytes`; miniatura con
  `Image.memory` y lupa con el `verFoto` de `selector_carnet.dart:647`.

- [ ] `telefonoPasajero` en el DTO y en `aRespuesta`, condicionado al tipo de envio, mas
      `sinNombreDestino()`.
- [ ] Test: en COMPRA_Y_ENTREGA llega el telefono; en ENCOMIENDA no; en un taxi no.
- [ ] Endpoint del comprobante con su test de seguridad (otro pasajero, otro repartidor, sin foto).
- [ ] App: el campo del cliente en el modelo, el helper del receptor, la miniatura del comprobante y
      la lupa.
- [ ] `flutter test`, `flutter analyze`, `./gradlew test` y `./gradlew build`.
- [ ] Commit: `feat: el cliente ve el comprobante y el repartidor su telefono en la compra`.

### Task 6: Spec, verificacion end-to-end y bitacora

**Files:**
- Modify: `docs/superpowers/specs/2026-10-02-delivery-design.md`
- Modify: `docs/CHANGELOG.md`
- Modify: `.superpowers/sdd/2026-10-02-delivery-implementation-plan/progress.md` (si existe y sigue
  vivo)

**Interfaces:**
- El spec dice, en las secciones 4, 5, 6 y 10, que en COMPRA_Y_ENTREGA el punto de entrega B es donde
  esta el pasajero al pedir, que no hay punto de recogida hasta que se registra la compra, y que el
  mapa dibuja el tramo naranja punteado al pasajero mientras tanto (H19, Rulings 1 a 4).
- Una entrada nueva de bitacora por task, con fecha, modulo, descripcion, cambios clave, archivos y
  verificacion.

- [ ] Spec actualizado en 4, 5, 6 y 10, con los rulings citados.
- [ ] Recorrido completo en Chrome, de punta a punta, con el backend en `bootRun`: pedir una compra,
      ver el naranja hasta el pasajero, aceptar, proponer, confirmar, registrar la compra con
      comprobante, ver la ruta desde el comercio, ver el comprobante y el total real desde el
      pasajero, confirmar el pago con el check, identificar el receptor y comprobar que el telefono
      aparece en el panel del repartidor.
- [ ] Repetir el recorrido de una ENCOMIENDA para verificar que no cambio nada.
- [ ] `flutter analyze`, `flutter test`, `./gradlew test` en verde.
- [ ] Bitacora y commit: `docs: el punto de entrega de la compra es donde esta el pasajero`.

---

## Fuera de alcance (pendientes de otra sesion, no tocar aqui)

Hallazgos de la revision del panel del reparto del 2026-10-06 que **no** son de este plan:

1. "Rechazar paquete" aparece tambien en el panel del codigo de entrega, donde el backend no lo
   acepta (solo antes de recoger). Esta en `_codigoPanel`, que se reusa para los dos codigos.
2. Si se cancela la camara, `_elegirFoto` deja la foto anterior y se reenvia en el reporte.
3. "Registrar la falla" no mira `flujo.ocupado`, al contrario que todos los demas botones.
4. `EntregaSinContacto.puedeReportar` exige los 10 minutos y dos intentos de contacto que pide el
   spec (`:217-222`, `:337`) y **nadie lo usa**: "No se pudo entregar" esta disponible desde
   `EN_MANO`.
5. El orden del pago frente al receptor y al codigo de entrega: el spec (`:179-182`, `:198-200`) lo
   dice al reves de como lo pide el backend (`EntregaService.entregarConCodigo` llama a
   `exigirPagoConfirmado` antes de validar el codigo). La Task 6 tambien lo deja escrito.
