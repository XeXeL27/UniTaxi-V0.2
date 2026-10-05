# Cuentas de prueba del entorno local

> Cuentas de la base de datos de desarrollo (PostgreSQL/PostGIS en Docker, base `taxiuap`,
> puerto 5436 del host). Son de prueba, con datos ficticios, y no existen en ningún otro entorno.
> No son credenciales de producción.

## Repartidor DELIVERY

Se creó el 2026-10-05 para probar el flujo de reparto de punta a punta.

| Campo | Valor |
|---|---|
| Usuario | `repartidor1` |
| Contraseña | `Delivery123*` |
| Nombre | REPARTIDOR PRUEBA DELIVERY |
| CI | 99887766-1A |
| Correo | repartidor.delivery@unitaxi.test |
| Teléfono | 70123456 |
| Situación | `APROBADO` (puede recibir pedidos) |
| Moto | Honda XR150 roja, placa `DEL-2026`, año 2023 |
| Categoría del vehículo | `DELIVERY` (id 11, la de menor id entre las activas) |

Cómo se creó: con el flujo real del panel, `POST /api/admin/personas` y luego
`POST /api/admin/personas/{id}/usuarios` mandando `idCategoriaServicio: 11` dentro del bloque
`conductor`. Sirve para comprobar que un repartidor puede darse de alta con la categoría DELIVERY
elegida y que el administrador puede corregirla después desde
`PUT /api/admin/conductores/{id}/vehiculo/categoria`.

## Pasajero

Para pedir el envío desde la app.

| Usuario | Contraseña |
|---|---|
| `pasajero1` (también `pasajero2` a `pasajero5`) | `Taxi123*` |

## Administrador

| Usuario | Contraseña |
|---|---|
| `admin` | `Taxi123*` |

## Requisitos para que el precio de una entrega no salga en Bs 0,00

El precio de DELIVERY sale de estas variables, no de la tabla `tarifa`:

```bash
DELIVERY_TARIFA_BASE=4.00
DELIVERY_PRECIO_KM=1.80
DELIVERY_PRECIO_MINUTO=0.20
DELIVERY_COMISION_PORCENTAJE=0.00
```

Están en `.env` (ignorado por git) y documentados en `.env.example`. `bootRun` e `iniciar.sh` cargan
el `.env`; la tarea Gradle `test` **no** lo carga, así que para correr las pruebas hay que
exportarlas:

```bash
cd backend
TAXIUAP_DB_PASSWORD='<clave local>' JWT_SECRET='<clave local>' \
DELIVERY_TARIFA_BASE=4.00 DELIVERY_PRECIO_KM=1.80 DELIVERY_PRECIO_MINUTO=0.20 \
DELIVERY_COMISION_PORCENTAJE=0.00 SPRING_PROFILES_ACTIVE=appu ./gradlew build
```

Sin `DELIVERY_TARIFA_BASE` la suite falla en `OfertaViajeDeliveryPersistenciaTest`, que afirma la
tarifa de referencia `4,00`.

## Categorías DELIVERY duplicadas

La base de desarrollo tiene 16 categorías MOTO activas: `3 MOTO` y quince `DELIVERY` (ids 11, 12,
13, 21 a 29, 35, 36, 37), que son basura de las pruebas del 2026-10-05, con sus quince tarifas en
0,00 y sin zona. No afectan el precio (el precio sale de las variables de arriba) pero sí obligan a
que cualquier listado de categorías agrupe por nombre y tome el id menor, tanto en la app como en
el panel. Limpiarlas es una tarea aparte: hay que tener cuidado de no borrar una categoría que ya
use un vehículo.
