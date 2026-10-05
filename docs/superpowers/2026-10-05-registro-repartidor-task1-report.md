# Task 1 del plan del repartidor DELIVERY: la moto del conductor puede ser DELIVERY

- **Fecha:** 2026-10-05
- **Rama:** `HWatson-dev`. Sin push, sin `main`.
- **Plan:** `docs/superpowers/plans/2026-10-05-delivery-registro-repartidor-plan.md`, Task 1.
- **Alcance:** solo backend (`identity/dto`, `vehicle`). Nada de `app-movil`, nada del panel, nada de
  `application*.properties`, nada de escrituras a la base.

---

## 1. Situacion de partida (importante para el controlador)

Al empezar, **el codigo de la Task 1 ya estaba escrito y commiteado**: `ddea3cf feat: permitir la
categoria DELIVERY en el registro del conductor` (15:41:28). No lo escribi en esta sesion. Durante mi
trabajo, otra sesion de agente commiteo `f12043c` con el asunto "selector de categoria del servicio en
el registro del conductor" (15:51:34), que es la Task 2 del plan (app movil). Las dos sesiones
comparten el mismo arbol de trabajo.

Por eso el trabajo de esta sesion fue: **revisar el diff commiteado contra el brief, comprobar que
cumple los cinco requisitos y las cinco pruebas, producir la evidencia RED -> GREEN que faltaba
(proxima seccion), y dejar el registro escrito**. No reescribi el codigo porque ya cumplia el brief y
volverlo a escribir habria sido ruido en el diff.

El unico cambio de codigo que aporta esta sesion es un salto de linea al final de
`RegistroMotoConductorCategoriaTest.java` (venia sin el, ver el "\ No newline at end of file" del
diff de `ddea3cf`), mas este reporte.

## 2. Revision del diff de `ddea3cf` contra el brief

| Requisito del brief | Estado | Evidencia |
|---|---|---|
| 1. `DatosConductorRequest` suma `Integer idCategoriaServicio`, opcional y documentado | Cumple | `DatosConductorRequest.java:27-32`, comentario que dice que `null` deja la categoria MOTO estandar |
| 2. Resolver por id: 404 si no existe, 422 si no es compatible con MOTO; `null` -> MOTO estandar **determinista** | Cumple | `RegistroMotoConductorService.java:122-124` y `157-162` |
| 3. Validacion de compatibilidad en un metodo reutilizable | Cumple | `VehiculoService.resolverCategoriaServicio(...)` publico (`VehiculoService.java:99-105`); lo usan `crear`, `actualizar` y `registrar`, y dentro sigue el `validarCategoriaDelTipo` que ya existia |
| 4. Metodo de busqueda determinista en el repositorio y fin del `findFirst()` sin orden | Cumple | `CategoriaServicioRepository.findFirstByTipoVehiculoIdAndEstadoCategoriaServicioAndNombreNotIgnoreCaseOrderByIdAsc`; el `findFirst()` desaparecio del camino del registro |
| 5. Las cinco pruebas | Cumple | `RegistroMotoConductorCategoriaTest`, 5 pruebas reales contra PostgreSQL |

Ademas se agrego `findByIdAndEstadoCategoriaServicio(id, A)`: una categoria con `estado_cat_serv = X`
ahora es 404 tambien por `POST/PUT /api/conductor/vehiculos`, que antes la aceptaba. Es el
comportamiento que pide el brief ("debe existir, estar `A`") y avoids que un camino acepte lo que el
otro rechaza. Queda anotado en el javadoc del metodo.

### Comportamiento con la base real (consulta de solo lectura, sin escribir nada)

Las 16 categorias MOTO activas empiezan asi: `3 MOTO`, `11 DELIVERY`, `12 DELIVERY`, `13 DELIVERY`,
`21 DELIVERY`, ... La consulta nueva (`estado A`, `nombre <> DELIVERY`, `ORDER BY id ASC LIMIT 1`)
devuelve **`3 MOTO`**: el mismo valor que devolvia el `findFirst()` de hoy, o sea que el registro sin
categoria sigue haciendo exactamente lo mismo que antes, pero ahora por una regla escrita.

## 3. Evidencia TDD

Como el codigo ya venia commiteado, la evidencia RED se produjo **revirtiendo el servicio de registro
al estado previo a la Task 1** (`git checkout ddea3cf^ -- .../RegistroMotoConductorService.java`, que
deja el `findFirst()` sin orden y sin mirar `datos.idCategoriaServicio()`), dejando el test en su sitio,
y despues restaurando el archivo.

### RED (implementacion vieja, pruebas nuevas)

```
cd backend
# .env exportado al entorno (ver seccion 5) y SPRING_PROFILES_ACTIVE=appu
./gradlew test --tests '*RegistroMotoConductorCategoriaTest' --console=plain
```

```
RegistroMotoConductorCategoriaTest > elDefaultNoCambiaConMasCategoriasMotoActivas() FAILED
    org.opentest4j.AssertionFailedError at RegistroMotoConductorCategoriaTest.java:149
RegistroMotoConductorCategoriaTest > rechazaUnaCategoriaDeAutoEnLaMotoDelConductor() FAILED
    org.opentest4j.AssertionFailedError at RegistroMotoConductorCategoriaTest.java:99
RegistroMotoConductorCategoriaTest > aceptaLaCategoriaDeliveryEnLaMotoDelConductor() FAILED
    org.opentest4j.AssertionFailedError at RegistroMotoConductorCategoriaTest.java:87
RegistroMotoConductorCategoriaTest > idDeCategoriaInexistenteDa404() FAILED
    org.opentest4j.AssertionFailedError at RegistroMotoConductorCategoriaTest.java:112

5 tests completed, 4 failed
BUILD FAILED in 12s
```

Mensajes exactos de los cuatro fallos:

| Prueba | Fallo | Por que era el fallo esperado |
|---|---|---|
| `aceptaLaCategoriaDeliveryEnLaMotoDelConductor` | `expected: <81> but was: <3>` | el registro ignoraba `idCategoriaServicio` y tomaba la MOTO estandar (id 3) en vez de la DELIVERY pedida (id 81) |
| `rechazaUnaCategoriaDeAutoEnLaMotoDelConductor` | `Expected NegocioException to be thrown, but nothing was thrown.` | sin resolver por id no habia ninguna validacion: la categoria de auto pasaba a la moto |
| `idDeCategoriaInexistenteDa404` | `Expected RecursoNoEncontradoException to be thrown, but nothing was thrown.` | no existia busqueda por id, asi que no habia 404 posible |
| `elDefaultNoCambiaConMasCategoriasMotoActivas` | `expected: <79> but was: <11>` | **este es el que mata el `findFirst()`**: la moto quedo con la categoria `11`, que es una DELIVERY |

### GREEN (implementacion de la Task 1 restaurada)

```
./gradlew test --tests '*RegistroMotoConductorCategoriaTest' --tests '*VehiculoEntregaTest' --console=plain
```

```
BUILD SUCCESSFUL in 11s
```

```
com.taxiuap.backend.vehicle.service.RegistroMotoConductorCategoriaTest: tests=5 failures=0 errors=0 skipped=0
com.taxiuap.backend.vehicle.service.VehiculoEntregaTest: tests=2 failures=0 errors=0 skipped=0
```

### Suite completa y build

```
./gradlew test --console=plain     -> BUILD SUCCESSFUL   tests=182 failures=0 errors=0 skipped=0 classes=39
./gradlew build --console=plain    -> BUILD SUCCESSFUL in 19s
```

(Salida contada con los XML de `backend/build/test-results/test/`, que es donde Gradle deja el
numero real de pruebas.)

## 4. Por que se quito el `findFirst()` y como lo demuestra la prueba

`findByTipoVehiculoIdAndEstadoCategoriaServicio(motoId, A).stream().findFirst()` es una consulta sin
`ORDER BY`: PostgreSQL devuelve las filas en el orden del plan de ejecucion, que en una tabla pequena
suele ser el orden fisico de insercion pero **no es un contrato**. Con las 15 categorias `DELIVERY`
que hay en `categoria_servicio` (basura de las pruebas del 2026-10-05, Ruling 4), el registro de
conductor podia quedarse con una DELIVERY sin que nadie lo pidiera: el conductor se registraria como
repartidor sin haber elegido nada, y su moto no serviria para el taxi.

La prueba `elDefaultNoCambiaConMasCategoriasMotoActivas` reproduce exactamente eso: apaga las
categorias MOTO estandar sembradas, crea una `DELIVERY` y despues una `MOTO-PRUEBA` (la DELIVERY
queda con id menor, como en la base real) y registra un conductor **sin** categoria. Con el
`findFirst()` la moto queda con la categoria `11` (DELIVERY) y la prueba falla; con la consulta
determinista queda con la `MOTO-PRUEBA`, que es la menor activa que no es DELIVERY. O sea: la prueba
no mira la implementacion, mira el resultado, y por eso detecta el `findFirst()`.

## 5. Verificacion: el comando del dispatch no basta

`./gradlew test` **no** carga el `.env` (solo lo carga `bootRun`), asi que hay que exportar el `.env`
a mano. Con solo `TAXIUAP_DB_PASSWORD` la corrida falla antes de arrancar el contexto de Spring:

```
Could not resolve placeholder 'JWT_SECRET'
```

`JWT_SECRET` viene de `application.properties` (`jwt.secret=${JWT_SECRET}`) sin valor por defecto, y
los precios de DELIVERY (`application-appu.properties:45-48`) caen en `0.00` sin
`DELIVERY_TARIFA_BASE`, `DELIVERY_PRECIO_KM` y `DELIVERY_PRECIO_MINUTO`, lo que hace fallar
`OfertaViajeDeliveryPersistenciaTest.aceptarDeliveryPersisteElViajeConLaMotoYLaTarifaRequerida`
(`expected: <4.00> but was: <0.00>`). Con las tres variables de mas, la suite completa pasa.

Comando que uso (no imprime ningun valor):

```bash
cd backend
while IFS= read -r linea; do
  case "$linea" in ''|'#'*) continue;; esac
  clave=${linea%%=*}; valor=${linea#*=}
  valor=${valor%\"}; valor=${valor#\"}; valor=${valor%\'}; valor=${valor#\'}
  export "$clave=$valor"
done < ../.env
export SPRING_PROFILES_ACTIVE=appu
./gradlew test --console=plain
```

La clave de la base nunca se escribio en este reporte, ni en un commit, ni en el log de git.

## 6. Archivos

Commit de la Task 1 (hecho por la sesion anterior, `ddea3cf`):

- `backend/src/main/java/com/taxiuap/backend/identity/dto/DatosConductorRequest.java`
- `backend/src/main/java/com/taxiuap/backend/vehicle/repository/CategoriaServicioRepository.java`
- `backend/src/main/java/com/taxiuap/backend/vehicle/service/VehiculoService.java`
- `backend/src/main/java/com/taxiuap/backend/vehicle/service/RegistroMotoConductorService.java`
- `backend/src/test/java/com/taxiuap/backend/vehicle/service/RegistroMotoConductorCategoriaTest.java`
- `backend/src/test/java/com/taxiuap/backend/vehicle/service/VehiculoEntregaTest.java`

De esta sesion:

- `backend/src/test/java/com/taxiuap/backend/vehicle/service/RegistroMotoConductorCategoriaTest.java`
  (salto de linea final)
- `docs/superpowers/2026-10-05-registro-repartidor-task1-report.md` (este reporte)

## 7. Autorrevision

- **Completitud:** los 5 requisitos y las 5 pruebas del brief estan. Ningun `@Disabled`, ningun test
  saltado (`skipped=0`).
- **Calidad:** el metodo reutilizable quedo en `VehiculoService`, que ya era el dueno de la regla;
  el nombre `resolverCategoriaServicio` dice lo que hace (resolver + validar). Los comentarios
  explican el por que (el `findFirst()` sin orden), no el que.
- **Disciplina:** no se toco `app-movil`, ni el panel, ni `application*.properties`, ni la base. La
  unica consulta a la base fue de lectura para documentar que el default sigue siendo `3 MOTO`.
- **Testing:** las pruebas usan el servicio y los repositorios reales contra PostgreSQL (el
  comportamiento depende de la consulta derivada, con dobles no se probaria) y se deshacen con el
  rollback. La prueba del default calcula la categoria esperada por su cuenta, no reusa el metodo de
  produccion.

## 8. Preocupaciones (para el controlador)

1. **Dos sesiones de agente en el mismo arbol de trabajo.** `ddea3cf` (Task 1, 15:41) y `f12043c`
   (Task 2, 15:51) se hicieron en este repositorio mientras yo trabajaba. Durante mi experimento RED
   deje `RegistroMotoConductorService.java` en su version vieja unos 90 segundos; si la otra sesion
   estaba corriendo `./gradlew` en ese momento, pudo ver un fallo raro. Conviene serializar las tasks
   o usar un worktree por sesion.
2. **`docs/CHANGELOG.md` tiene un cambio sin commitear que borro una entrada vieja.** La entrada de
   la Task 1 esta ya escrita arriba, pero **reemplazo** (no dejo la vieja) la seccion "Verificacion · Deuda de
   verificacion de DELIVERY (Tasks 3 a 8)" completa, que es justo lo que la regla global prohibe. No
   lo toque porque es de otra sesion y el plan asigna el changelog a la Task 4; lo que hay que hacer
   es **volver a poner esa seccion debajo** y dejar las nuevas encima.
3. **"Estandar" se define por nombre.** La consulta determinista es "la activa de menor id cuyo
   nombre no sea DELIVERY". Si manana aparece otra categoria MOTO que no sea de taxi (por ejemplo
   `REPARTO`), el registro sin categoria la podria tomar. El modelo no tiene una columna
   `estandar`; si se quiere blindar, la decision es agregar esa columna (Task aparte, no aqui).
4. **`findByTipoVehiculoIdAndEstadoCategoriaServicio` quedo sin uso en produccion** (solo lo usan las
   pruebas). Se dejo: es una consulta de catalogo razonable y borrar metodos de repositorio fuera del
   alcance de la task seria ruido.
5. Cambios locales ajenos en el arbol (`README.md`, `application.properties`, `task-2-report.md`,
   `app-movil/test/entrega_test.dart`) y sin commitear: no los toque ni los commitee.