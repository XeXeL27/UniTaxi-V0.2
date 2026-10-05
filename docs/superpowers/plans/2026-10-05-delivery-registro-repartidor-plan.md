# Plan: registro del repartidor DELIVERY y precio de referencia

> **For agentic workers:** REQUIRED SUB-SKILL: usa `subagent-driven-development` para ejecutar
> este plan task por task, con un implementer nuevo y una revision independiente por task.
> Al final, `code-reviewer` sobre la rama completa.

**Goal:** Que una persona pueda registrarse como repartidor de entregas eligiendo la categoria
DELIVERY de su moto, que el administrador pueda cambiar esa categoria, y que el precio del
servicio DELIVERY salga con los mismos valores que la tarifa del taxista.

**Architecture:** DELIVERY no es un rol ni un tipo de cuenta: es la categoria de servicio de la
moto (`categoria_servicio` con nombre DELIVERY, solo compatible con `TipoVehiculo.MOTO`). Un
repartidor es un `CONDUCTOR` cuya moto tiene esa categoria. Por eso el trabajo no crea un
tercer tipo de registro: agrega la eleccion de categoria al registro de conductor que ya
existe, la deja ser corregida por el administrador, y arregla el origen del precio.

**Tech Stack:** Spring Boot 4.1.1, Java 21, JPA/PostGIS, Flutter (app movil y panel web),
PostgreSQL/PostGIS en Docker.

**Spec:** `docs/superpowers/specs/2026-10-02-delivery-design.md` (seccion 2, categoria del
vehiculo). Este plan **cambia** esa regla; ver el Ruling 1.

**Contexto:** el modulo DELIVERY (Tasks 1 a 8) quedo implementado y verificado el 2026-10-05
(`docs/superpowers/2026-10-05-verificacion-entrega.md`, 177 tests backend y 78 Dart en verde),
pero nunca se pudo probar de punta a punta desde el registro porque **no hay forma de crear un
repartidor**: el registro de conductor no pregunta la categoria y asigna la primera categoria
MOTO activa, que es `MOTO` (id 3), no DELIVERY.

**Estado de ejecucion (2026-10-05):** plan escrito, ninguna task implementada.

---

## Rulings (decididos con el usuario)

- **`Ruling: el repartidor elige la categoria DELIVERY al registrarse`** — el selector aparece
  en el registro de conductor. Esto **cambia el spec seccion 2**, que hoy dice que el chofer no
  decide su categoria. La red de seguridad es que la cuenta igual queda `PENDIENTE` y no recibe
  ni una solicitud hasta que el administrador la apruebe, mas el endpoint nuevo para que el
  admin la corrija. Al terminar hay que registrar este ruling en el spec y en el `progress.md`
  del SDD de DELIVERY para que otra sesion no lo lea como un defecto.
  Costo si se interpreta mal: cualquier persona se registra como repartidor; mitigado por la
  aprobacion del administrador.
- **`Ruling: el precio DELIVERY usa los valores de la tarifa del taxista`** — tarifa base
  4,00 Bs, 1,80 Bs por km, 0,20 Bs por minuto (tarifa MOTO zona Centro, `tarifa` id 5, que es
  tambien el default del codigo en `CalculoPrecioDeliveryService`). La comision DELIVERY sigue
  en 0 porque el producto nunca entra en la comision.
- **`Ruling: no tocar `application*.properties`** — hay una modificacion local ajena con una
  clave JWT hardcodeada. Los valores van por `.env`, que `bootRun` carga solo.
- **`Ruling: no limpiar las categorias DELIVERY duplicadas en este plan`** — hay 15 activas y
  sus 15 tarifas en 0.00 sin zona, basura de las pruebas del 2026-10-05. No afectan el precio
  (ver "Hallazgo" mas abajo) pero son la causa de la ambiguedad que arregla la Task 1.3.
  Se deja como tarea aparte.

---

## Hallazgos que sostienen el plan

Verificados en el codigo y en la base el 2026-10-05. No volver a investigarlos.

| # | Hallazgo | Evidencia |
|---|---|---|
| H1 | No existe registro ni rol "delivery": el registro ofrece solo Pasajero y Conductor | `app-movil/lib/modulos/registro/pantalla_registro.dart:50-69`; `RolSistema` = PASAJERO / CONDUCTOR / ADMIN |
| H2 | El registro de conductor **no pregunta** la categoria y toma la primera MOTO activa | `RegistroMotoConductorService.java:113-127`; `DatosConductorRequest` no tiene `idCategoriaServicio` ni `idTipoVehiculo` |
| H3 | Ese `findFirst()` **no tiene `ORDER BY`**, asi que depende del orden fisico de la BD | `CategoriaServicioRepository.java:15` |
| H4 | Una moto que no es DELIVERY no puede aceptar el pedido | `OfertaViajeService.java:299`: "Solo una moto DELIVERY puede aceptar esta solicitud" |
| H5 | No hay ninguna UI para poner una moto en DELIVERY, ni en la app ni en el panel; solo el endpoint del conductor | `VehiculoConductorController` (`POST`/`PUT /api/conductor/vehiculos` con `idCategoriaServicio`); en `app-movil` no hay ninguna referencia a `idCategoriaServicio`; no existe `VehiculoAdminController` |
| H6 | Los tres caminos de registro del conductor comparten el mismo DTO y la misma pantalla | `RegistroConductorGoogleRequest.java:25` y `RegistroConductorPasajeroRequest.java:25` anidan `DatosConductorRequest`; los tres usan `PantallaFormularioConductor` |
| H7 | El precio DELIVERY sale de las propiedades, **no** de la tabla `tarifa` | `SolicitudViajeService.java:107` -> `CalculoPrecioDeliveryService.calcular()` (`precio = tarifaBase + precioKm*km + precioMinuto*min`) |
| H8 | Las 15 tarifas DELIVERY en 0.00 y sin zona **no afectan el precio** | H7: solo se usan como referencia de persistencia (`SeedTarifaDelivery`) |
| H9 | El panel ya muestra "Categoría de servicio" del vehiculo, pero de solo lectura | `admin-panel/lib/modulos/expediente/expediente_conductor.dart:316-337`, via `GET /api/admin/conductores/{id}/vehiculos` |
| H10 | El pasajero si tiene el camino completo: el selector de tipo de envio esta en el Inicio y la app sola resuelve la categoria DELIVERY | `paneles_pasajero.dart:162-200` (`_SelectorEntrega`), `flujo_pasajero.dart:299-307`, `viaje_api.dart:116-125` |

### Estado de la base de datos (2026-10-05)

Lo que hay ahora, para no perder tiempo en la proxima sesion:

- `categoria_servicio` MOTO activas: `3 MOTO`, y **15 DELIVERY** (ids 11, 12, 13, 21 a 29, 35, 36, 37).
  `findFirst()` devuelve `MOTO` (id 3) hoy, pero por H3 no es una garantía.
- `tarifa` MOTO: id 5 (zona Centro) 4,00 / 1,80 / 0,20 / minima 4,00; id 6 (Periferia) 4,50 / 2,00 / 0,25.
- `tarifa` DELIVERY: 15 filas, todas 0,00 y con `id_zona` nula, creadas el 2026-10-05.
- `vehiculo`: hay motos DELIVERY ya listas, incluidas cinco de `conductor3`
  (`E2E-DLV1`, `91215199`, `91215757`, `91215766`, `91215862`), todas con el conductor `APROBADO`.
- `conductor3` / `Taxi123*` es el repartidor que el seed diseña para DELIVERY
  (`SeedUsuarios.java:162` le da la moto con `deliveryCategoria()`). Sirve para probar el
  flujo sin registrar a nadie, pero **no** sirve para probar el registro, que es lo que hace este plan.

---

## Global Constraints

- Todo el codigo nuevo en espanol, con `controller -> service -> repository -> entity`.
- Sin emojis en codigo, logs, comentarios, commits, mensajes ni respuestas de API.
- No crear archivos `.sql`, ni Flyway, ni Liquibase. El esquema lo genera Hibernate
  (`ddl-auto=update`).
- DELIVERY solo puede asociarse a una `MOTO`; reusar el chequeo de
  `VehiculoService.validarCategoriaDelTipo` en lugar de duplicar la regla.
- No exponer los codigos de recogida ni de entrega en las respuestas de la API.
- Todo endpoint nuevo valida rol y propietario en el servidor.
- Todo el trabajo en la rama `HWatson-dev`. Nunca `main`, nunca checkout, merge ni push a `main`.
- **Nunca push.** Lo decide el usuario.
- Nunca crear ni editar `application*.properties`.
- No imprimir la contraseña de la base en reportes, commits ni logs.

## Entorno y comandos

```bash
# Base de datos (PostGIS en Docker, puerto 5436 del host)
docker ps --format "{{.Names}} {{.Status}} {{.Ports}}"     # taxiuap-db debe estar healthy
systemctl --user start docker-desktop                        # si Docker no responde
docker compose up -d --wait

# Backend. La tarea Gradle `test` NO carga `.env` (solo `bootRun`): pasa la clave explicita.
cd backend
TAXIUAP_DB_PASSWORD='<clave local>' SPRING_PROFILES_ACTIVE=appu ./gradlew test --console=plain
TAXIUAP_DB_PASSWORD='<clave local>' SPRING_PROFILES_ACTIVE=appu ./gradlew test --tests '*Entrega*' --console=plain
TAXIUAP_DB_PASSWORD='<clave local>' SPRING_PROFILES_ACTIVE=appu ./gradlew build --console=plain
SPRING_PROFILES_ACTIVE=appu ./gradlew bootRun                 # puerto 8080, este si lee `.env`

# Flutter
cd app-movil   && flutter test && flutter analyze && flutter build web --no-tree-shake-icons --no-web-resources-cdn
cd admin-panel && flutter analyze && flutter build web --release --no-tree-shake-icons --no-web-resources-cdn
```

`--no-tree-shake-icons` y `--no-web-resources-cdn` son obligatorios: sin ellos el recorte de
fuentes deja iconos como cuadros vacios y el build depende de gstatic.com.

## Tarea 0: precio de referencia (sin codigo, antes de empezar)

- [ ] Agregar al `.env` de la raiz (esta ignorado por git):
      `DELIVERY_TARIFA_BASE=4.00`, `DELIVERY_PRECIO_KM=1.80`, `DELIVERY_PRECIO_MINUTO=0.20`.
      `DELIVERY_COMISION_PORCENTAJE` se queda en `0.00`.
- [ ] Reiniciar el backend y comprobar que el precio DELIVERY ya no es `Bs 0,00`.
- [ ] Verificar con una solicitud real de prueba que el total cuadra: `4,00 + 1,80 x km + 0,20 x min`.

No tocar `application-xexel.properties` ni `application-appu.properties` (Ruling 3). No tocar
las filas de `tarifa` DELIVERY (H8).

---

## File Map

- `backend/.../identity/dto/`: `DatosConductorRequest` (campo nuevo).
- `backend/.../vehicle/repository/`: `CategoriaServicioRepository` (busqueda determinista).
- `backend/.../vehicle/service/`: `RegistroMotoConductorService` (resolver categoria),
  `VehiculoService` (reusar validacion).
- `backend/.../controller/admin/`: `ConductorAdminController` (endpoint nuevo).
- `app-movil/lib/modulos/registro/`: `formulario_conductor.dart` (selector) y el cliente de API.
- `admin-panel/lib/modulos/expediente/`: `expediente_conductor.dart` (categoria editable).
- Tests junto al modulo correspondiente.

---

### Task 1: La moto del conductor puede ser DELIVERY

**Files:**
- Modify: `backend/src/main/java/com/taxiuap/backend/identity/dto/DatosConductorRequest.java`
- Modify: `backend/src/main/java/com/taxiuap/backend/vehicle/service/RegistroMotoConductorService.java`
- Modify: `backend/src/main/java/com/taxiuap/backend/vehicle/repository/CategoriaServicioRepository.java`
- Create: test del servicio de registro y de la resolucion de categoria.

**Interfaces:**
- `DatosConductorRequest` suma `Integer idCategoriaServicio`, opcional: si viene `null` se
  comporta exactamente como hoy (MOTO estandar).
- La categoria resuelta debe existir, estar `A` y ser compatible con MOTO. Id inexistente ->
  `RecursoNoEncontradoException` (404). Categoria de un auto -> `NegocioException` (422).
- La eleccion queda en `vehiculo.categoria_servicio`; nada mas cambia.

- [ ] Agregar `idCategoriaServicio` al record, documentando que es opcional y que `null` = MOTO estandar.
- [ ] En `registrar(...)`, resolver por id cuando viene; si no viene, usar la categoria MOTO
      estandar de forma **determinista** (no el `findFirst()` actual).
- [ ] Mover el chequeo de compatibilidad a un metodo reutilizable con `VehiculoService`, para
      que el registro y la edicion no diverjan.
- [ ] Agregar al repositorio el metodo determinista (orden explicito por id o por nombre) y
      dejar de usar el `findFirst()` sin `ORDER BY` en el camino del registro.
- [ ] Pruebas: se acepta DELIVERY en una MOTO; se rechaza una categoria de auto; id
      inexistente da 404; `null` deja MOTO estandar; el default no cambia aunque haya mas
      categorias MOTO activas en la base.
- [ ] Ejecutar los tests del modulo y la suite completa.
- [ ] Commit: `feat: allow delivery category on driver registration`.

### Task 2: Selector de categoria en el registro del conductor

**Files:**
- Modify: `app-movil/lib/modulos/registro/formulario_conductor.dart`
- Modify o Create: el cliente de API de la app para leer las categorias de servicio.
- Create: `app-movil/test/registro_conductor_categoria_test.dart`

**Interfaces:**
- El selector ofrece dos opciones, con el mismo estilo de `_SelectorEntrega`
  (`paneles_pasajero.dart:162-200`): la elegida con fondo azul y texto blanco, la otra con
  borde. Sin flechas ni simbolos especiales.
- Las categorias se leen de `GET /api/publico/categorias-servicio` y se filtran las
  compatibles con MOTO, igual que hace el pasajero en `viaje_api.dart:116-125`.
- El valor viaja dentro del JSON `datos` como `idCategoriaServicio` (multipart).
- Si el backend no devuelve ninguna categoria compatible, avisar y dejar solo la de taxi:
      el registro nunca se rompe por esto.

- [ ] Cargar las categorias al abrir el formulario y guardar el id elegido.
- [ ] Anadir el selector al final de la seccion "Tu moto", despues de "Anio" y antes de la
      nota que dice "El pasajero vera la marca, el modelo, el color y la placa".
- [ ] Texto de las opciones: "Mototaxi (pido pasajeros)" y "Repartidor de entregas". Anclar el
      texto a los valores reales de `TipoEnvio`/`CategoriaServicio.nombre` que ya existen.
- [ ] Mandar `idCategoriaServicio` en el JSON `datos` de los tres caminos (formulario, Google,
      desde pasajero). Como los tres comparten `DatosConductorRequest` (H6), el cambio es uno.
- [ ] Caso sin categorias disponibles: aviso y formulario igual de usable.
- [ ] Test Dart del armado del request con cada valor del selector.
- [ ] `flutter test` y `flutter analyze`.
- [ ] Commit: `feat: add delivery category selector to driver registration`.

### Task 3: El administrador cambia la categoria de la moto

**Files:**
- Modify: `backend/src/main/java/com/taxiuap/backend/controller/admin/ConductorAdminController.java`
- Modify: el servicio que resuelve la categoria (el mismo de la Task 1).
- Create: test de seguridad del endpoint.
- Modify: `admin-panel/lib/modulos/expediente/expediente_conductor.dart`

**Interfaces:**
- `PUT /api/admin/conductores/{id}/vehiculo/categoria`, solo ADMIN, cuerpo con
  `idCategoriaServicio`. Mismas validaciones que la Task 1.
- Si el conductor tiene mas de un vehiculo activo, el body dice cual
  (`idVehiculo`), o el endpoint exige que haya exactamente uno. Decidir y documentar: para el
  caso de uso actual (una moto por repartidor) basta con el vehiculo activo, pero no se
  debe cambiar de vehiculo por sorpresa.
- El panel edita "Categoria de servicio" en la seccion "Vehiculo" del expediente, con el flujo
  estandar: confirmacion naranja -> formulario -> modal verde (`flujoEditar` de
  `lib/widgets/flujos_crud.dart`).

- [ ] Endpoint ADMIN con las validaciones de la Task 1 reusadas.
- [ ] Test de seguridad: 401 sin token, 403 con PASAJERO y con CONDUCTOR, 200 con ADMIN.
- [ ] Test de negocio: id de categoria invalido, y que el cambio se persiste y se ve en el
      endpoint de listado.
- [ ] En el expediente, hacer editable la categoria, mostrando antes el valor actual.
- [ ] `flutter analyze` y build del panel.
- [ ] Commit: `feat: let admin change driver service category`.

### Task 4: Verificacion integral y recorrido manual

**Files:**
- Modify: `docs/CHANGELOG.md` (entradas nuevas, sin tocar las viejas).
- Modify: `docs/superpowers/specs/2026-10-02-delivery-design.md` (Ruling 1 en la seccion 2).
- Modify: `.superpowers/sdd/2026-10-02-delivery-implementation-plan/progress.md` (Ruling 1).

- [ ] `./gradlew build` en verde con la suite completa.
- [ ] `flutter test`, `flutter analyze` y los builds de `app-movil` y `admin-panel` en verde.
- [ ] Recorrido manual completo desde el registro, con las pantallas que el usuario tiene que
      hacer en Chrome:
      1. Registrar un repartidor nuevo eligiendo "Repartidor de entregas", con moto y licencia.
      2. El administrador lo aprueba en el panel.
      3. Registrar un pasajero nuevo con Google y carnet.
      4. En Inicio: "Que quieres enviar?" -> Encomienda -> continuar -> destino en el mapa ->
         confirmar pago -> pedir. El precio ya no es 0,00.
      5. Conectar el repartidor y comprobar que **ve** el pedido (si no lo ve, la categoria no
         quedo bien: revisar `vehiculo.categoria_servicio`).
      6. Aceptar, codigo de recogida, codigo de entrega, pago, entrega.
      7. Repetir con "Compra y entrega": proponer comercio, el cliente confirma, recibo, pago.
      8. "No se pudo entregar" con foto y motivo: el reporte aparece en Sistema > Reportes de
         entrega y se resuelve con el modal de resolucion.
      9. Cambiar la categoria de la moto desde el panel y comprobar que el repartidor deja de
         ver los pedidos.
- [ ] Dejar en el reporte el resultado real de cada comando y de cada paso manual.
- [ ] Registrar el Ruling 1 en el spec y en el `progress.md`.
- [ ] Commit: `docs: record delivery driver registration verification`.

---

## Final Review

- [ ] `task-reviewer` despues de cada implementer, y `re-reviewer` para los hallazgos.
- [ ] `code-reviewer` sobre la rama `HWatson-dev` completa al final.
- [ ] Actualizar `docs/CHANGELOG.md` con cada entrega real y verificada.
- [ ] Ningun commit en `main`, ningun push.

## Fuera de alcance (anotado, no se toca en este plan)

- Las 15 categorias DELIVERY duplicadas y sus 15 tarifas en 0.00 sin zona. No afectan el
  precio (H8); son basura de las pruebas y conviene limpiarlas en una tarea aparte, con el
  cuidado de no borrar una categoria que ya use un vehiculo.
- El repartidor no puede editar su `limite_adelanto_compra`: el permiso `DATOS` lo bloquea
  siempre, contra el spec. Es un defecto conocido, abierto.
- `admin-panel` no tiene carpeta `test/`; la Task 3 se verifica con `flutter analyze` y a mano.
- El bug de comparacion de telefonos del receptor sigue diferido por decision del usuario
  (`docs/superpowers/2026-10-04-entrega-handoff.md`).
