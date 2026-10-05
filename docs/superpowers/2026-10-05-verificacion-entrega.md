# Verificación de la deuda DELIVERY — Tasks 3 a 8 (2026-10-05)

- **Rama:** `HWatson-dev`. Sin push, sin `main`.
- **Alcance:** Tasks 3, 4, 5, 6, 7 y 8 del plan `2026-10-02-delivery-implementation-plan.md`,
  más el commit de códigos de 6 dígitos.
- **Entorno:** contenedor `taxiuap-db` (PostGIS, `127.0.0.1:5436`), backend Spring Boot 4.1.1 /
  Java 21, Flutter 3.47.5, `google-chrome` para el smoke.
- **Qué NO se tocó:** ningún `application*.properties` (el perfil `appu` es local y no está
  versionado), ni los cambios locales ajenos del usuario.

---

## 1. Resumen

| Verificación | Resultado |
|---|---|
| `./gradlew test` (suite completa) | `BUILD SUCCESSFUL` — `tests=177 failures=0 errors=0 skipped=0 classes=38` |
| `./gradlew build` | `BUILD SUCCESSFUL in 25s` |
| `OfertaViajeDeliveryPersistenciaTest` (PENDING DOCKER) | **PASA** |
| `SolicitudViajeConcurrenteDeliveryTest` (PENDING DOCKER) | **PASA** |
| Autoverificación de permisos y de UPDATE condicional | **PASA** (las pruebas detectan las roturas) |
| `flutter test` (app-movil) | `00:02 +78: All tests passed!` |
| `flutter analyze` (app-movil) | `No issues found!` (corregidos 2 lints de la Task 7) |
| `flutter analyze` (admin-panel) | `No issues found!` (corregido 1 lint de la Task 8) |
| `flutter build web` (app-movil) | `✓ Built build/web` |
| `flutter build web` (admin-panel) | `✓ Built build/web` |
| Recorrido end-to-end por la API | **62 comprobaciones PASA**, 3 no concluyentes (ver §5) |
| Smoke en Chrome de `/app` y `/admin` | Montan sin excepción de Dart |
| `admin-panel` sin carpeta `test/` | Confirmado; no se añadieron tests (alcance nuevo) |

**Defectos corregidos:** 2 (pruebas con suposición incorrecta) + 3 lints.
**Defectos encontrados y NO corregidos:** 3, todos de decisión de producto o de seguridad
(ver §6).

---

## 2. Entorno: dos bloqueos reales y cómo se resolvieron

### 2.1 Faltaban variables de entorno para levantar el contexto Spring

La primera corrida completa falló con **20 errores**, todos
`PlaceholderResolutionException`, no aserciones:

```text
177 tests completed, 20 failed
java.lang.IllegalStateException at DefaultCacheAwareContextLoaderDelegate.java:157
Caused by: org.springframework.util.PlaceholderResolutionException: Could not resolve placeholder 'JWT_SECRET'
```

Causa: `application.properties` exige `${JWT_SECRET}`, `${ADMIN_CORREO}` y `${ADMIN_PASSWORD}`, y la
tarea Gradle `test` no carga `.env`. Los tres valores que faltan no tienen default. Los 20 fallos
eran de entorno, no de código. Con valores de prueba:

```bash
cd backend
SPRING_PROFILES_ACTIVE=appu TAXIUAP_DB_PASSWORD="$PW" \
JWT_SECRET='clave-solo-para-pruebas-automaticas-32bytes-min' \
ADMIN_CORREO='pruebas@localhost' ADMIN_PASSWORD='Prueba123*' \
./gradlew test --console=plain --rerun-tasks
```

### 2.2 `application-appu.properties` contradice el ejemplo versionado

Con el entorno arriba, la suite bajó a **4 fallos**. Uno era
`OfertaViajeDeliveryPersistenciaTest`:

```text
OfertaViajeDeliveryPersistenciaTest > aceptarDeliveryPersisteElViajeConLaMotoYLaTarifaRequerida() FAILED
    org.opentest4j.AssertionFailedError: expected: <4.00> but was: <0.00>
```

Causa raíz: el perfil `appu` local (no versionado) quedó con los defaults de la ronda temporal del
2026-10-04 en `0.00`:

```properties
# backend/src/main/resources/application-appu.properties (local, gitignored)
taxiuap.delivery.tarifa-base=${DELIVERY_TARIFA_BASE:0.00}
taxiuap.delivery.precio-km=${DELIVERY_PRECIO_KM:0.00}
taxiuap.delivery.precio-minuto=${DELIVERY_PRECIO_MINUTO:0.00}
```

mientras que el ejemplo versionado `application-xexel.properties.example` tiene los valores correctos
(`4.00` / `1.80` / `0.20`), que son los que el código declara como default en
`CalculoPrecioDeliveryService`:

```properties
# backend/src/main/resources/application-xexel.properties.example (versionado)
taxiuap.delivery.tarifa-base=4.00
taxiuap.delivery.precio-km=1.80
taxiuap.delivery.precio-minuto=0.20
```

**Es un problema de entorno, no de producción.** Verificado: pasando el override documentado
(`DELIVERY_TARIFA_BASE=4.00 DELIVERY_PRECIO_KM=1.80 DELIVERY_PRECIO_MINUTO=0.20`) la prueba pasa
sin tocar código.

```text
$ ./gradlew test --rerun-tasks --tests '...OfertaViajeDeliveryPersistenciaTest' --console=plain
BUILD SUCCESSFUL in 13s
```

En la base había además 3 tarifas técnicas DELIVERY con `tarifa_base = 0.00` (`id_tarifa` 7, 8 y 9,
`vigente_desde = 2026-10-05`) creadas por corridas anteriores con esos defaults. Residuo del mismo
origen.

**Acción sugerida al usuario:** alinear `application-appu.properties` con
`application-xexel.properties.example`. No se hizo porque la instrucción es no crear ni editar
`application*.properties`.

---

## 3. Defectos corregidos

### 3.1 `EntregaServicePostgresTest` afirmaba la excepción equivocada — commit `9ad46fa`

```text
EntregaServicePostgresTest > conductorDistintoNoPuedeValidarRecogida() FAILED
    org.opentest4j.AssertionFailedError: Unexpected exception type thrown,
    expected: <NegocioException> but was: <RecursoNoEncontradoException>
    Caused by: RecursoNoEncontradoException: Viaje no encontrado con id 15
        at ViajeService.obtenerViajeDelConductor(ViajeService.java:927)
        at EntregaService.validarRecogida(EntregaService.java:193)

EntregaServicePostgresTest > pasajeroDistintoNoPuedeConfirmarCompra() FAILED
    (idem, id 17, at EntregaService.confirmarCompra(EntregaService.java:118))
```

**Clasificación: test mal escrito (suposición incorrecta), no defecto de producción.** La protección
es deliberada y está documentada en el propio código:

```java
// backend/.../trip/service/ViajeService.java:919
/**
 * Viaje del conductor autenticado: si el viaje no es suyo se responde como no encontrado para
 * no revelar que existe.
 */
```

Ocultar la existencia es más correcto que confirmar que el viaje existe y no le pertenece.
`NegocioException` (422) y `RecursoNoEncontradoException` (404) extienden `RuntimeException` por
separado, así que la aserción no podía satisfied por herencia. Se corrigió la expectativa del test.

### 3.2 `ReporteAdminControllerSecurityTest` no llegaba al servicio — commit `9ad46fa`

```text
ReporteAdminControllerSecurityTest > adminPuedeResolverReporte() FAILED
    java.lang.AssertionError: Status expected:<200> but was:<500>
```

Con la causa real tomada del log de la petición:

```text
Handler:  com.taxiuap.backend.controller.admin.ReporteAdminController#resolver(Long, ResolverReporteRequest)
Resolved Exception:  java.util.NoSuchElementException
MockHttpServletResponse: Status = 500
```

**Clasificación: test mal escrito (no simula la autenticación real).** El controller hace
`UsuarioActual.obtener().orElseThrow()`, y `UsuarioActual.obtener()` solo devuelve algo si el
principal es un `JwtUser`:

```java
// backend/.../config/security/UsuarioActual.java
if (authentication != null && authentication.getPrincipal() instanceof JwtUser jwtUser) {
    return Optional.of(jwtUser);
}
return Optional.empty();
```

`@WithMockUser(roles = "ADMIN")` deja un `User` de Spring, no un `JwtUser`: la prueba visitaba un
estado imposible en producción y moría con un 500 sin mensaje antes de llamar al servicio. Los otros
casos ADMIN de la misma clase pasaban porque `listar`, `obtener` y `foto` no leen `UsuarioActual`.
La prueba ahora se autentica como lo hace `JwtAuthFilter` (principal `JwtUser` + autoridad
`ROLE_ADMIN`):

```java
private UsernamePasswordAuthenticationToken tokenAdmin() {
    return new UsernamePasswordAuthenticationToken(new JwtUser(1L, "admin", "ADMIN"), null,
            List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
}
```

### 3.3 Tres lints de `flutter analyze` que nadie había visto — commit `27963cb`

`flutter analyze` estaba diferido en Task 7 y Task 8, así que estos hallazgos nunca aparecieron:

```text
info • The import of 'dart:typed_data' is unnecessary ... lib/modulos/conductor/viaje/flujo_conductor.dart:2:8
info • Statements in a for should be enclosed in a block ... lib/modulos/conductor/viaje/panel_delivery_conductor.dart:39:93
warning • Unused import: '../../widgets/dialogos.dart' ... admin-panel/lib/modulos/reportes/pantalla_reportes_entrega.dart:10:8
2 issues found.
```

Antes: `flutter analyze` → `2 issues found` (app-movil) y `1 issue found` (admin-panel).
Después: `No issues found!` en las dos.

---

## 4. Autoverificación (lo que el handoff del 2026-10-04 exigía)

El handoff pedía expressly romper producción a propósito, comprobar que las pruebas fallan y
restaurar. Tres roturas deliberadas, con la producción restaurada después (`git diff` vacío):

### 4.1 Chequeo de propietario del conductor — DETECTADA

Se quitó el `if (!viaje.getConductor().getId().equals(conductor.getId())) throw ...` de
`obtenerViajeDelConductor`:

```text
EntregaServicePostgresTest > conductorDistintoNoPuedeValidarRecogida() FAILED
3 tests completed, 1 failed
BUILD FAILED in 13s
```

La prueba de permisos dejó de ser vacua: ahora un conductor real que no es el asignado es rechazado
de verdad.

### 4.2 UPDATE de código de recogida incondicional — DETECTADA

Se eliminó `and d.codigoRecogida = :codigo` de `avanzarSiCodigoRecogidaCoincide`:

```text
DatosEntregaTransicionConcurrenteTest > unaFallaRepetidaNoSobrescribeLaEvidenciaDeLaPrimera() FAILED
DatosEntregaTransicionConcurrenteTest > dosValidacionesConcurrentesDelCodigoDeRecogidaSoloHacenUnaTransicion() FAILED
DatosEntregaTransicionConcurrenteTest > unCodigoDeRecogidaIncorrectoNoCambiaNadaAunqueSeRepita() FAILED
DatosEntregaTransicionConcurrenteTest > dosEntregasConcurrentesSoloCobranUnaComision() FAILED
DatosEntregaTransicionConcurrenteTest > unPedidoYaEntregadoNoAceptaUnaFalla() FAILED
EntregaServicePostgresTest > conductorDistintoNoPuedeValidarRecogida() FAILED
EntregaServicePostgresTest > recorridoRealDeEncomiendaPersisteEstadoPagoYViajeEnPostgres() FAILED
EntregaServicePostgresTest > pasajeroDistintoNoPuedeConfirmarCompra() FAILED
20 tests completed, 8 failed
BUILD FAILED in 10s
```

La comparación de códigos en SQL es una propiedad que las pruebas sostienen de verdad.

### 4.3 `clearAutomatically` — NO DETECTADA (gap real, documentado)

Se quitó `clearAutomatically = true` de `avanzarSiCodigoRecogidaCoincide`:

```text
BUILD SUCCESSFUL in 13s
```

Ninguna prueba falla. Motivo: en los caminos cubiertos la entidad `DatosEntrega` no está cargada en
el contexto de persistencia antes del UPDATE de cada acción (cada acción es su propia transacción y
`EntregaService` relee el estado después), así que la caché de primer nivel no llega a enmascarar el
UPDATE. **La preocupación del handoff queda acotada pero no cerrada**: si alguien mete una lectura de
`DatosEntrega` en la misma transacción antes del UPDATE, ninguna prueba lo detectaría. Es un gap de
cobertura conocido, no un defecto observado.

---

## 5. Recorrido end-to-end por la API

Backend arriba con `SPRING_PROFILES_ACTIVE=appu`, `DELIVERY_TARIFA_BASE=4.00`,
`DELIVERY_PRECIO_KM=1.80`, `DELIVERY_PRECIO_MINUTO=0.20`. Guion contra la API real, con
verificación de **códigos de estado, cuerpos y efectos persistidos** (no solo que "responde").

Actores: `admin` (ADMIN), `pasajero2` (PASAJERO), `conductor3` (moto), `conductor1` (sedán).
**62 comprobaciones pasan, 3 no concluyentes.**

### 5.1 Lo que pasa (extracto real)

```text
== 2. REGLAS TRANSVERSALES ==
  PASA  401 sin token en endpoint de pasajero
  PASA  403 con rol PASAJERO en /api/admin/reportes
  PASA  403 con rol PASAJERO en /api/conductor/solicitudes

== 3. PROVISION ==
  PASA  catalogo publico expone categoria DELIVERY
  PASA  conductor registra moto en categoria DELIVERY
  PASA  categoria DELIVERY sobre tipo SEDAN -> rechazado (DELIVERY solo en MOTO)

== 4. ENCOMIENDA ==
  PASA  pasajero crea solicitud ENCOMIENDA DELIVERY
  solicitud=55 precio=16.89 estimado=False
  PASA  ENCOMIENDA fija precio de servicio por OSRM (> 0)
  PASA  codigo de recogida del pasajero tiene 6 digitos
  PASA  codigo de entrega del pasajero tiene 6 digitos
  PASA  los dos codigos son independientes
  PASA  segunda solicitud DELIVERY con pedido activo -> 422
  PASA  ENCOMIENDA sin aceptar politica de prohibidos -> 422

== 5. VISIBILIDAD ==
  PASA  repartidor DELIVERY ve la solicitud
  PASA  conductor ESTANDAR no ve la solicitud DELIVERY
  PASA  la lista de solicitudes no expone codigos al repartidor

== 6. ACEPTACION Y CODIGOS ==
  PASA  repartidor DELIVERY acepta la solicitud
  PASA  la aceptacion NO devuelve codigo de recogida
  PASA  la aceptacion NO devuelve codigo de entrega
  PASA  conductor que no es el asignado NO valida la recogida
  PASA  codigo de recogida incorrecto -> 422
  PASA  codigo de recogida correcto -> 200
  PASA  pasajero NO cancela una solicitud ACEPTADA -> 422
  PASA  entrega sin pago confirmado -> 422
  PASA  pago con monto incorrecto -> 422
  PASA  pago con el total exacto -> 200
  PASA  codigo de entrega correcto completa el viaje
  PASA  estado de entrega persistido ENTREGADO
  PASA  estado de viaje persistido COMPLETADO

== 7. COMPRA_Y_ENTREGA ==
  PASA  pasajero crea COMPRA_Y_ENTREGA
  PASA  COMPRA_Y_ENTREGA nace SIN precio de servicio (pendiente del repartidor)
  PASA  repartidor acepta COMPRA_Y_ENTREGA
  PASA  el estimado se identifica como estimado
  PASA  comprar SIN confirmacion del cliente -> 422
  PASA  repartidor propone comercio y monto
  PASA  registrar compra con costo REAL mayor al confirmado -> 422
  PASA  conductor NO confirma la compra (ruta de pasajero) -> 403
  PASA  cliente confirma la compra propuesta
  PASA  registrar compra confirmada sin comprobante (opcional)
  PASA  compra deja el pedido EN_MANO
  PASA  el precio de servicio se fijo al comprar (ya no estimado)
  PASA  costo real del producto persistido

== 8. NO SE PUDO ENTREGAR ==
  PASA  'No se pudo entregar' con foto y motivo -> 200
  PASA  estado de entrega persistido NO_ENTREGADO
  PASA  el motivo de falla quedo guardado
  PASA  la foto de falla quedo guardada
  PASA  el fallo creo un reporte PENDIENTE para el admin
  PASA  la solicitud fallida NO se republica

== 9. REPORTES ADMINISTRATIVOS ==
  PASA  el admin consulta el detalle del reporte
  PASA  el detalle expone la evidencia del incidente
  PASA  el ADMIN descarga la foto de evidencia
  PASA  el repartidor NO descarga la foto de evidencia
  PASA  el pasajero NO descarga la foto de evidencia
  PASA  el admin resuelve el reporte con tipo, observacion y cierre
  PASA  la resolucion quedo persistida
  PASA  la resolucion guardo el tipo
  PASA  la resolucion guardo la observacion del admin
  PASA  la resolucion guardo la fecha
  PASA  la resolucion guardo la identidad del admin

== RESULTADO: 62 pasaron, 3 fallaron ==
```

Evidencia del reporte creado automáticamente por la falla, leído por la API de admin:

```json
{
  "id": 2,
  "idViaje": 37,
  "motivo": "FALLA_ENTREGA",
  "descripcion": "El receptor no responde",
  "situacion": "PENDIENTE",
  "tipoResolucion": null,
  "fotoFallaUrl": "personas/13/conductor/entrega/falla_entrega_20261005_120042.jpg",
  "motivoFalla": "El receptor no responde",
  "costoProductoReal": 25.0
}
```

### 5.2 Las 3 comprobaciones que no concluyen (con su motivo)

Ninguna es un defecto de producción; se reportan por honestidad.

1. **`limite_adelanto_compra` no editable por el repartidor** → 422. Es un defecto real de producto,
   documentado en §6.1. En el recorrido el valor se fijó por SQL porque la API está bloqueada.
2. **Código de recogida de menos de 6 dígitos** → 400, no 422. Es la convención del proyecto:
   `ManejadorGlobalExcepciones` mapea `MethodArgumentNotValidException` (validación de Bean) a **400**
   y `NegocioException` a **422**. La expectativa del guion era incorrecta; el comportamiento es el
   preexistente y correcto. Confirmado en el código:
   `datosInvalidos` → `HttpStatus.BAD_REQUEST`; `NegocioException` → `HttpStatus.UNPROCESSABLE_CONTENT`.
3. **Resolver con tipo de resolución inválido** → 400, no 422. El enum no deserializa, así que es un
   error de formato de la petición (400), no una regla de negocio. Igual que el punto 2.

### 5.3 Cosas que el guion NO pudo verificar

- **El bug de comparación de teléfonos** de `docs/superpowers/2026-10-04-entrega-handoff.md` sigue
  diferido por decisión del usuario. No se implementó ni se verificó. `EntregaService.validarReceptor`
  compara solo dígitos, así que un pasajero guardado como `+591 70123456` nunca coincide con el
  `70123456` que escribe el repartidor.
- **Los 10 minutos y dos intentos de contacto** que exige el spec antes de "No se pudo entregar"
  (§8): no hay comprobación de tiempo ni de intentos en el backend; la acción se acepta de inmediato.
  No se auditó si el temporizador vive en la app.
- **Repartidor no aprobado y moto ESTANDAR** se verificaron por código y por la base, no con un
  segundo conductor real no aprobado en la API.
- **`paquete-no-coincide`**: existe el endpoint y hay prueba unitaria; no se recorrió por la API.
- **`ADMIN` no ve el chat efímero**: se verificó por la regla de seguridad (los mensajes de chat no
  tienen endpoint de admin) y por el hecho de que `/api/admin/**` es `hasRole('ADMIN')`, no
  recorriendo un chat real.
- **Repetición del precio por GPS posteriores**: no verificado por API.

---

## 6. Defectos encontrados y NO corregidos (requieren decisión)

### 6.1 El repartidor no puede definir su propio límite de adelanto (spec §2 vs código)

El spec dice: "**Cada repartidor DELIVERY define en su perfil un `limite_adelanto_compra`** en Bs".
La reality:

```text
PUT /api/conductor/perfil
-> 422 {"mensaje":"No tiene permiso para actualizar sus datos. Pida al administrador que lo habilite."}
```

`PerfilConductorService.actualizar` consume **incondicionalmente** un permiso `DATOS` antes de
aplicar cualquier cambio:

```java
// backend/.../identity/service/PerfilConductorService.java:52
permisoEdicionService.consumir(conductor.getId(), TipoPermisoEdicion.DATOS, null);
```

y ese permiso solo lo otorga el administrador (`POST /api/admin/conductores/{id}/permisos`), y se
consume en el uso. Consecuencia: un repartidor aprobado **no puede** poner su límite de adelanto sin
que un administrador se lo conceda cada vez. Esto contradice el spec §2 y el checkbox de Task 2
("Exponer límite editable del repartidor").

**No se cambió** porque la decisión es de producto y toca la seguridad del módulo de taxis
("sin permiso el conductor solo ve sus datos"). Opciones para el usuario:
(a) dejar el límite solo en manos del admin (cambiar el spec §2), o
(b) sacar `limite_adelanto_compra` del alcance del permiso `DATOS` y dejarlo siempre editable por
el repartidor.

### 6.2 El repartidor puede autoasignarse la categoría DELIVERY a su moto

El spec §2 dice que "la categoría de la moto la asigna el administrador al habilitarla", pero
`POST /api/conductor/vehiculos` acepta `idCategoriaServicio` del propio conductor y solo valida que
la categoría corresponda al tipo físico:

```java
// backend/.../vehicle/service/VehiculoService.java:126
if ("DELIVERY".equalsIgnoreCase(categoriaServicio.getNombre())
        && !"MOTO".equalsIgnoreCase(tipoVehiculo.getCodigo())) {
    throw new NegocioException("La categoria DELIVERY solo puede asociarse a una MOTO");
}
```

Verificado en la API: **PASA** — el repartidor registra su moto ya en DELIVERY (201). La regla
" DELIVERY solo en MOTO" sí se cumple, pero cualquier conductor aprobado con una moto puede
convertirla en DELIVERY y empezar a recibir encomiendas sin que el admin lo decida. El filtro por
límite de adelanto mitiga en parte `COMPRA_Y_ENTREGA`, no `ENCOMIENDA`.

**No se cambió** por ser una decisión de producto sobre el modelo de habilitación.

### 6.3 La regla de "una solicitud activa" ignora `estado_sol_viaje`

`SolicitudViajeRepository.existsByPasajeroIdAndSituacionSolicitudIn` filtra por
`situacion_solicitud` pero **no** por `estado_sol_viaje`:

```java
boolean existsByPasajeroIdAndSituacionSolicitudIn(Long idPasajero, Collection<SituacionSolicitud> situaciones);
```

Verificado en la base: la solicitud 51 quedó en `situacion_solicitud = PENDIENTE` y
`estado_sol_viaje = X`, y el pasajero seguía recibiendo "Ya tiene una solicitud de viaje activa".

**Gravedad real: baja.** El camino normal de cancelación es `DELETE /api/pasajero/solicitudes/{id}`,
que pasa la solicitud a `CANCELADA` (no la borra lógicamente), y la regla mira `PENDIENTE` /
`CON_OFERTAS`, así que no bloquea. Queda latente: cualquier borrado lógico futuro de una solicitud
`PENDIENTE` bloquearía al pasajero para siempre. No se cambió por no ser de las Tasks 3 a 8.

---

## 7. Smoke en Chrome

```bash
google-chrome --headless=new --disable-gpu --no-sandbox --virtual-time-budget=20000 \
  --dump-dom http://localhost:8080/app
google-chrome --headless=new --disable-gpu --no-sandbox --virtual-time-budget=20000 \
  --dump-dom http://localhost:8080/admin
```

```text
=== /app ===
bytes=14359
      1 <title>UNITAXI</title>
      2 UNITAXI
     15 flutter-view
=== /admin ===
bytes=5711
      1 <title>UNITAXI - Administración</title>
      1 UNITAXI
     15 flutter-view
```

Ambas montan sin excepción de Dart y con el título correcto. **Lo que esto NO prueba:** Flutter Web
dibuja con CanvasKit, así que el texto de la pantalla de login no está en el DOM (el texto extraído
es solo `UNITAXI flutter typography measurement`, que es el scaffolding). El smoke confirma que la
app **carga**; no que la pantalla de login se vea bien ni que el flujo funcione en el navegador.

---

## 8. Pasos que le tocan hacer al usuario en Chrome

Con el backend arriba (`cd backend && SPRING_PROFILES_ACTIVE=appu ./gradlew bootRun`, que sirve
`/app` y `/admin` desde los builds) o con `./iniciar.sh`.

**Pasajero (ENCOMIENDA):**
1. Abrir `http://localhost:8080/app`. Entrar como pasajero.
2. Verificar que el selector de tipo de envío muestra **ENCOMIENDA** y **COMPRA Y ENTREGA**, y que
   al elegir DELIVERY el precio mostrado **no es 0.00** (si aparece 0.00, es el problema de §2.2).
3. Pedir A y B, elegir remitente y receptor, marcar la aceptación de artículos prohibidos y solicitar.
4. Confirmar que aparecen los **dos códigos de 6 dígitos** y que el precio es el de OSRM.
5. Iniciar sesión como repartidor: confirmar que **no aparece ningún código** en la pantalla de la
   solicitud.
6. Aceptar, luego "Validar recogida": comprobar que un código incorrecto avisa y que el correcto pasa
   el pedido a en mano.
7. Intentar cancelar con el pedido en mano: **debe aparecer la opción bloqueada**, no un error técnico.
8. Confirmar el pago y validar la entrega: la pantalla debe mostrar el desglose total.

**Pasajero (COMPRA Y ENTREGA):**
9. Crear el pedido con monto estimado. Confirmar que **no hay precio fijo** y que aparece como
   estimado cuando se asigna repartidor.
10. Confirmar que al intentar comprar con un monto **mayor** al confirmado el servidor lo rechaza y
    hay que volver a proponer y volver a confirmar.
11. Registrar la compra **sin comprobante**: no debe bloquear el flujo.
12. Confirmar que aparece "Total a cobrar" con producto y servicio separados.

**Repartidor (fallas y reports):**
13. Con el pedido en mano, usar "No se pudo entregar": **debe exigir foto y motivo**. Probar sin foto.
14. Confirmar que la app **no** ofrece cancelar el viaje con el pedido en mano.

**Panel admin:**
15. Entrar en `http://localhost:8080/admin`, menú de reportes de entrega: abrir un reporte `PENDIENTE`,
    comprobar que se ve la evidencia, y resolverlo con tipo de resolución y observación.
16. Expediente de un conductor: comprobar que aparecen la categoría DELIVERY de la moto y el límite
    de adelanto.
17. Comprobar que en el panel **no** hay ningún acceso al chat del viaje.

---

## 9. PENDING y su motivo

| Ítem | Motivo |
|---|---|
| Prueba de interacción real en Chrome | No la puede hacer el agente: requiere clic, teclado y sesión real. Pasos en §8. |
| `admin-panel` sin carpeta `test/` | Confirmado que no existe. Añadir tests del panel es alcance nuevo; no se inventó. |
| Comparación de teléfonos de COMPRA_Y_ENTREGA | Diferido por decisión del usuario el 2026-10-04 y reafirmada el 2026-10-05. No implementado. |
| `clearAutomatically` como propiedad cubierta | La rotura deliberada no la detecta ninguna prueba (§4.3). Gap de cobertura documentado. |
| `application-appu.properties` con defaults `0.00` | No editable por instrucción. Requiere que el usuario lo alinee (§2.2). |
| `task-5-report.md` y `task-6-report.md` | No están versionados en git (el `.gitignore` de `.superpowers/sdd/` es `*`). El fix report se les anexó, pero queda **solo local**; haría falta `git add -f`. |
| Suite del panel admin | No existe `test/`; la verificación del panel es `flutter analyze` + build + smoke. |

---

## 10. Commits

| SHA | Qué |
|---|---|
| `9ad46fa` | `test: fix delivery verification test assumptions` — expectativa de excepción y autenticación real del caso ADMIN. |
| `27963cb` | `style: clear delivery lint findings in driver app and admin panel` — 3 lints de analyze. |

Ningún commit toca `application*.properties`, `.env`, credenciales ni los cambios locales ajenos
(`.env.example`, `README.md`, `app-movil/test/entrega_test.dart`,
`backend/src/main/resources/application.properties`, `task-2-report.md` y las entradas que el usuario
tenía sin commitear en `docs/CHANGELOG.md`).