# Handoff — DELIVERY (2026-10-05)

Sesion corta: **sin cambios de codigo**. Se documento el estado, se decidio la pregunta
abierta de pago parcial y se subio la rama. Rama `HWatson-dev`.

## Donde esta todo

- Plan: `docs/superpowers/plans/2026-10-02-delivery-implementation-plan.md`
- Diseno (manda sobre el plan): `docs/superpowers/specs/2026-10-02-delivery-design.md`
- Handoff anterior (2026-10-04): `docs/superpowers/2026-10-04-entrega-handoff.md`
- Reportes, revisiones y ledger: `.superpowers/sdd/2026-10-02-delivery-implementation-plan/`
  (scratch ignorado por git: `git clean -fdx` lo borra; el registro que sobrevive es este
  documento, el changelog y git)
- Bitacora: `docs/CHANGELOG.md`

## Estado del modulo

Tasks 1-4 implementadas y verificadas contra PostgreSQL. **Task 5 y las apps siguen
pendientes.** El cierre de los dos hallazgos importantes de Task 4 **no se empezó**: los
tres despachos del implementador se cancelaron antes de que escribiera codigo.

### Abierto: cierre de Task 4 (los dos hallazgos importantes)

1. `EntregaService` nunca se prueba contra la base real a traves del servicio. Todos sus
   tests mockean `DatosEntregaRepository` y stublean la lectura posterior a la transicion,
   asi que si alguien quita `clearAutomatically` o vuelve un UPDATE incondicional, ningun
   test falla y el estado se revierte en silencio. Falta un `@SpringBootTest` con perfil
   `appu` que recorra el camino legal completo y verifique el estado **persistido**, mas la
   autoverificacion: romper produccion a proposito, comprobar que la prueba falla, restaurar.
2. La prueba de permisos es vacua. `EntregaServiceRecogidaEntregaTest` "prueba" el permiso
   haciendo que el helper de propiedad lance excepcion. Falta rechazo a un conductor real
   que no es el asignado, a un pasajero real que no es del viaje, y el control positivo.

El brief con los requisitos exactos de este cierre ya esta escrito en el workspace del plan
(`task-4-cierre-brief.md` y `task-4-cierre-dispatch.md`), pero al ser scratch se pierde con
`git clean -fdx`. Si no esta, se reconstruye desde la seccion "Pendiente: dos hallazgos
importantes de Task 4" del handoff del 2026-10-04.

## Decisiones tomadas en esta sesion

- **Pago parcial: se mantiene el spec.** El repartidor registra el total exacto
  (producto + servicio); no existe campo de monto parcial ni flujo de pago incompleto. Si el
  cliente no paga todo, el repartidor usa "No se pudo entregar" con foto y motivo, y el
  reporte guardara el costo real del producto y el total esperado. Quedaba como pregunta
  abierta desde el 2026-10-04; ya es decision firme.
- **El bug de comparacion de telefono sigue diferido.** `EntregaService.validarReceptor`
  compara solo digitos, asi que un pasajero guardado como `+591 70123456` nunca coincide con
  el `70123456` que escribe el repartidor y el pedido COMPRA_Y_ENTREGA solo puede terminar en
  "No se pudo entregar". Decision del usuario del 2026-10-04: documentado y revisado despues.
  **No lo implementes sin una decision nueva.**

## Aclaracion de arquitectura (quedo confirmada)

El repartidor **no es un actor nuevo**: es el mismo `Conductor` de siempre, con el mismo
registro (CI, licencia M, carnet, telefono, documentos) y la misma aprobacion del admin. Lo
unico que cambia es:

1. la categoria de su moto, `DELIVERY` en vez de `ESTANDAR` (solo MOTO; la asigna el admin al
   habilitarla);
2. su campo `limite_adelanto_compra` (cuanto puede adelantar en una compra);
3. el filtro de solicitudes por categoria (una moto `ESTANDAR` no ve pedidos `DELIVERY` y al
   reves).

Por eso Task 1 toco `Conductor` y `CategoriaServicio`: no para crear una estructura nueva,
sino para agregar el campo del limite y el valor de categoria.

## Como correr las pruebas

```bash
cd backend
SPRING_PROFILES_ACTIVE=appu ./gradlew test --console=plain
```

Las credenciales ya estan en `backend/src/main/resources/application-appu.properties`.
**No crear ni editar `application*.properties`.** Las pruebas de base no dependen del seedor
de desarrollo: para eso esta `backend/src/test/java/com/taxiuap/backend/testsupport/DatosPruebaDelivery.java`.

La base de desarrollo es el contenedor `taxiuap-db` (PostGIS, puerto 5436 de Docker). Si
Docker no responde, Docker Desktop es un servicio del usuario aqui:

```bash
systemctl --user start docker-desktop
docker compose up -d --wait
```

## Siguientes pasos

1. Despachar el implementador del cierre de Task 4 (los dos hallazgos de arriba), con el
   proceso de siempre: un implementador nuevo, revision independiente, TDD con el comando y
   la salida reales en el reporte, un commit por task.
2. Task 5: reportes y administracion backend (`Reporte.PENDIENTE` automatico en la falla,
   resolucion con observacion/fecha/identidad/cierre, descarga de foto solo para ADMIN,
   advertencia por declaracion incorrecta sin suspension).
3. Tasks 6, 7 y 8: app pasajero, app repartidor, panel admin. Las tasks 6 y 7 tocan los
   modelos y el mapa compartidos: secuenciales, no en paralelo.
4. Al final, revision global de la rama y re-triaje de los menores documentados.

Proceso: un implementador nuevo y una revision independiente por task
(`subagent-driven-development`), TDD con la salida real en el reporte, y un commit por task.