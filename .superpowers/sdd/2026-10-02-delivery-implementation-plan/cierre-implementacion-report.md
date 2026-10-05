# Cierre de la implementación DELIVERY (2026-10-05)

Alcance de esta sesión: cerrar los tres puntos pedidos (documentación de códigos, contrato de fotos y
confirmación del panel). **No se ejecutaron ni escribieron tests, ni Gradle, ni `flutter test`, ni
`analyze`, ni builds.** No hubo RED/GREEN que reportar porque el trabajo fue documental más una línea de
presentación en el panel.

## Contrato de códigos: EXACTAMENTE 6 dígitos (confirmado)

Contrato del usuario: códigos de recogida y entrega **aleatorios, independientes y de exactamente 6
dígitos**, sin relación con teléfono, CI, identificadores ni ningún otro número. Verificado en el código
de producción (commit `4b9b463`):

| Punto | Archivo | Estado |
|---|---|---|
| Generación | `trip/service/SolicitudViajeService.codigo()` | `String.format("%06d", ALEATORIO.nextInt(1_000_000))` con `SecureRandom` |
| Independencia entre códigos | `SolicitudViajeService.crearDatosEntrega` | regenerate el de entrega mientras sea igual al de recogida |
| Entidad | `trip/entity/DatosEntrega` | `PATRON_CODIGO = "\\d{6}"` en `codigoRecogida` y `codigoEntrega` |
| Validación API | `trip/dto/ValidarCodigoEntregaRequest` | `@Pattern("\\d{6}")`, mensaje "El codigo debe tener 6 digitos" |
| App repartidor | `acciones_delivery.dart`, `panel_delivery_conductor.dart` | `^\d{6}$`, `maxLength: 6`, mensaje "exactamente 6 dígitos" |
| Privacidad | `SolicitudViajeService.aResponse` | los códigos solo se devuelven al propio pasajero |

Solo para ENCOMIENDA se generan los dos códigos (en COMPRA_Y_ENTREGA el receptor es el cliente y se
valida nombre y teléfono), tal como pide el spec.

### Documentación y reportes corregidos (punto 1)

Todos decirán "ocho/8 dígitos" para el contrato equivocado; ahora dicen 6, con nota de corrección para no
borrar el historial:

- `progress.md`: el ruling de Task 4 cierre.
- `task-4-cierre-brief.md`: requisito 5 (requisito y literals de prueba).
- `task-7-report.md`: el bloqueo que decía que la app conservaba 8 dígitos y el backend 6 (ya no existe:
  ambos están en 6).
- `task-8-report.md`: la línea que decía "ocho dígitos", y la preocupación invertida sobre
  `ddl-auto=update` (ver "Pendientes").

**No se tocó** `docs/CHANGELOG.md`, que sigue diciendo "ocho dígitos" en sus entradas del 2026-10-05
(líneas 37 y 45): la instrucción de esta sesión prohíbe expressly ese archivo. Queda para el
controlador. Tampoco se tocaron las menciones a 8 dígitos de **celulares bolivianos** (`CLAUDE.md`,
`ReglasRegistro`, `formatos.dart`, `datos_perfil.dart`, `formulario_conductor.dart`, handoff del
2026-10-04 sobre la comparación de teléfonos), porque ahí 8 dígitos es el dato correcto.

## Contrato de fotos del pedido (punto 2)

Unificado con el spec `docs/superpowers/specs/2026-10-02-delivery-design.md` (sección 3) sin inventar
endpoints. Las dos fotos del pedido son exactamente estos dos campos:

| Foto | Dónde viaja | Tipo | Columna | Obligatoria |
|---|---|---|---|---|
| Foto del paquete (ENCOMIENDA) | `POST /api/pasajero/solicitudes`, dentro de `datosEntrega` | campo JSON `fotoPaqueteUrl` (`@Size(max = 500)`) | `datos_entrega.foto_paquete_url` | No (spec: "puede agregar una foto, pero la foto no es obligatoria") |
| Foto del comprobante de compra (COMPRA_Y_ENTREGA) | `POST /api/conductor/viajes/{id}/entrega/registrar-compra` | parte multipart `compra` (JSON) + parte `comprobante` (archivo, opcional) | `datos_entrega.foto_comprobante_url` | No (spec: "Los comercios informales pueden no entregar comprobante") |

Verificado extremo a extremo:

- Backend acepta y guarda `fotoPaqueteUrl`: `DatosEntregaRequest` -> `SolicitudViajeService.crearDatosEntrega`
  (línea 238) -> `DatosEntrega.fotoPaqueteUrl`.
- La app móvil envía el campo cuando existe: `DatosEntregaForm.aJson()` lo incluye dentro del bloque de
  ENCOMIENDA (`modelos_viaje.dart`, línea 72). Hoy el formulario no lo pide, así que viaja `null`: es
  correcto porque la foto es opcional y **no hay endpoint de subida para el pasajero**. No se creó uno
  (el spec no lo exige) y la app no manda una URL inventada.
- La app móvil manda el comprobante como parte `comprobante` en el multipart de `registrar-compra`
  (`conductor_api.dart`, línea 120) contra el `@RequestPart(value = "comprobante", required = false)`
  del controller. Es la única foto de compra: no existe endpoint separado para "foto del producto o del
  comercio" porque el spec no lo pide como campo propio.
- Evidencia de incidentes (obligatoria) sigue por su camino: parte `foto` en `no-se-pudo-entregar` y
  `paquete-no-coincide` -> `datos_entrega.foto_falla_url`.

## Panel administrativo (punto 3): los tres puntos ya estaban

1. **Categoría DELIVERY**: existe en el catálogo (seed `SeedCatalogos`, `crearCategoriaServicio(moto,
   "DELIVERY")`, solo sobre MOTO), se administra con el CRUD de catálogo `/api/admin/categorias-servicio`
   y el expediente del conductor la muestra como `Categoría de servicio`
   (`expediente_conductor.dart`, línea 333, dato `nombreCategoriaServicio`). No hace falta texto propio
   en el panel: aparece sola en la moto que la tenga.
2. **Límite del repartidor en expedientes**: `expediente_conductor.dart`, línea 314, muestra
   `Límite de adelanto para compras` con `monedaBs(perfil.limiteAdelantoCompra)`, que el backend expone en
   `PerfilConductorResponse` y el admin edita con `PUT` del perfil del conductor.
3. **Listado de reportes con evidencia y modal de resolución**: menú `Sistema > Reportes de entrega`
   (`core/menu.dart`, línea 39) y ruta `/reportes-entrega` (`core/rutas.dart`, línea 57). La pantalla usa
   `ListadoRemoto`/`ColumnaTabla` con columna `Evidencia`, el ojo abre el detalle con la foto servida por
   `GET /api/admin/reportes/{id}/foto`, y el botón de la fila abre el modal `_FormularioResolucion` con
   los cinco tipos de resolución del spec y observación obligatoria, sobre `PUT .../resolver`.

**Único completamiento (mínimo):** el detalle del reporte mostraba el tipo de resolución y la
observación, pero no la fecha, aunque el modelo ya la traía (`ReporteEntrega.fechaResolucion`) y el spec
(sección 9) pide que la resolución deje fecha. Se añadió una línea con `Formato.fechaHora` en
`pantalla_reportes_entrega.dart`. Sin cambios de API.

## Pendientes y no resuelto (para el controlador)

- **`docs/CHANGELOG.md` sigue con "ocho dígitos"** en las entradas del 2026-10-05 (líneas 37 y 45).
  Entradas viejas: la regla del proyecto es no reescribirlas, así que lo correcto es una entrada nueva
  arriba que aclare el contrato de 6 dígitos. No la escribí porque esta sesión prohibió tocar ese archivo.
- **La regla global de bitácora** pide registrar el cambio en `docs/CHANGELOG.md`; quedó sin hacer por
  la misma prohibición explícita.
- **`ddl-auto=update` no reduce columnas**: en las bases ya creadas, `codigo_recogida` y `codigo_entrega`
  siguen como `varchar(8)` aunque la entidad diga `length = 6`. No molesta (los valores son de 6
  caracteres y el `@Pattern` los valida), pero si se quiere el `varchar(6)` real hay que hacerlo a mano
  una vez en cada base; no se puede por SQL versionado en este proyecto.
- **`ReporteService.listar()` devuelve todos los reportes**, no solo los de DELIVERY. Con el seed actual
  eso mete en "Reportes de entrega" el reporte de taxi "Ruta distinta a la esperada"
  (`SeedComunicacion`, línea 157), que aparece sin tipo de envío y sin evidencia, y se podría "resolver"
  con tipos de resolución de entrega. No lo cambié: el filtro es una decisión de alcance de Task 5
  (revisada y cerrada) y no está en los tres puntos pedidos. Recomendación: filtrar por viajes con
  `datos_entrega` o por `motivo in (FALLA_ENTREGA, PAQUETE_NO_COINCIDE)`.
- **Identidad del admin que resolvió**: el backend envía `idUsuarioAdminResolvio` (un id, no un nombre) y
  el panel no lo muestra. Completarlo exige decidir si se expone el nombre del administrador.
- **Foto del paquete sin captura en la app**: el contrato existe en backend y app, pero la pantalla de
  entrega no ofrece tomar la foto. Con el spec es válido (es opcional), y hacerlo exigiría un endpoint
  de subida para el pasajero, que esta sesión prohíbe inventar.
- **Cambios locales ajenos sin commitear, no tocados**: `.env.example`, `README.md`,
  `backend/src/main/resources/application.properties`,
  `.superpowers/.../task-2-report.md` (nombre de properties) y `app-movil/test/entrega_test.dart`
  (línea agregada sobre `informacionReporte`). Se dejaron como estaban.

## Verificación

No se ejecutó nada por instrucción explícita: sin tests, sin Gradle, sin `flutter test`, sin `analyze`,
sin builds, sin push. La revisión fue lectura de código y de los contratos de los dos extremos.

## Archivos cambiados

- `.superpowers/sdd/2026-10-02-delivery-implementation-plan/cierre-implementacion-report.md` (nuevo)
- `.superpowers/sdd/2026-10-02-delivery-implementation-plan/progress.md`
- `.superpowers/sdd/2026-10-02-delivery-implementation-plan/task-4-cierre-brief.md`
- `.superpowers/sdd/2026-10-02-delivery-implementation-plan/task-7-report.md`
- `.superpowers/sdd/2026-10-02-delivery-implementation-plan/task-8-report.md`
- `admin-panel/lib/modulos/reportes/pantalla_reportes_entrega.dart` (fecha de resolución en el detalle)

`.superpowers/sdd/.gitignore` ignora todo su contenido, así que estos archivos se agregaron con
`git add -f` (igual que se hizo con los reportes de Task 1 a Task 4): si no, un `git clean -fdx`
borra justamente las correcciones de documentación que se hicieron aquí.
