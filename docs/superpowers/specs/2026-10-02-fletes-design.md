# Diseño: módulo de Fletes en UniTaxi

- Fecha: 2026-10-02
- Estado: propuesto, pendiente de aprobación del usuario (se discutió y el usuario llegó a la sección 4 sin objetar)
- Decisión previa: OPCION A en todas las preguntas (flete como categoría de servicio del conductor existente; flujo de viaje reutilizado; CAMIONETA + CAMION con lista de tipos de carga inspirada en Yango Delivery)

## Resumen

Agregar envíos de carga ("fletes", incluida encomienda de paquetes estilo Yango Delivery)
al TaxiUAP reutilizando el motor de viajes existente:

- flete = `categoria_servicio` FLETE sobre tipos de vehículo nuevos `CAMIONETA` y `CAMION`
- cliente mismo flujo inDrive que ya existe: solicitud → ofertas → aceptar → viaje → pago/comisión
- datos de carga en una tablita nueva `datos_flete` (1-1 con `solicitud_viaje`)
- chat efímero con aviso al usuario y fotos subidas por REST (no por WebSocket)

## 1. Modelo de datos (backend)

- `tipo_vehiculo`: agregar `CAMIONETA` (capacidad_pasajeros / carga aprox. 800 kg) y
  `CAMION` (3000 kg) al catálogo (admin ya lo gestiona por CRUD).
- `categoria_servicio`: nueva `FLETE` ligada a esos tipos.
- Entidad nueva `datos_flete`, 1-1 con `solicitud_viaje`:
  - `tipo_carga`: texto libre con sugerencias UI (muebles, electrodomésticos,
    materiales de construcción, encomienda, etc.)
  - `peso_aprox_kg`, `volumen_aprox` (decimal, opcionales)
  - `ayuda_cargar` (bool), `ayuda_descargar` (bool)
  - `foto_paquete_url`: ruta relativa en `taxiuap.archivos.directorio`
    (igual que `archivo_url` de documentos); opcional
  - `contacto_destino`: nombre + teléfono de quien recibe (Opcional, Yango-style
    para encomiendas; comunicar al destinatario en fase 1 solo con notificación
    interna de la app)
- El `viaje` resultante se crea igual que hoy (ya lleva `id_cat_serv`); no hay cambios
  en viaje, pago, comision, billetera ni historial de estados.
- `datos_flete` viaja dentro del DTO de respuesta de `solicitud_viaje` cuando exista.

## 2. Reglas de negocio

1. Solo conductores con un vehículo aprobado de categoría `FLETE` reciben solicitudes
   de flete (un conductor puede tener además su moto para viajes comunes).
2. Al pedir flete, el cliente puede dejar nota de compra ("compré X y entrégalo
   a la persona Y"): fase 1 es solo texto en `datos_flete`; el precio de lo que
   se pide que compren se acuerda por chat efímero.
3. Al finalizar viaje con FLETE, el fletero confirma la entrega normalmente
   (misma acción de "finalizar").
4. Si el viaje tiene `contacto_destino`, al iniciar y al llegar se envía notificación
   interna de la plataforma (email opcional ya existe con `CorreoService`).

## 3. Chat efímero + fotos

- Banner fijo arriba del input en pasajero y conductor:
  "El chat no se guarda: los mensajes se pierden cuando termina el viaje."
- El chat ya es en memoria (muere con el viaje) — la política se hace explícita:
  ni texto ni fotos se persisten en la BD de mensajes.
- Foto por REST (NO por WebSocket, para no cargar el canal de ubicación/estado):
  `POST /api/pasajero/viajes/{id}/chat/foto`, `POST /api/conductor/viajes/{id}/chat/foto`
  - imagen comprimida del lado cliente (objetivo ≤ 300 KB, max ~1600 px)
  - se entrega por WebSocket como mensaje efímero con URL a recursos servidos
    temporalmente; recib su URL como enlace puro comunicando que no se guada
- El panel admin NO puede leer chats (coherencia con el banner).

## 4. Apps

- Pasajero: opción/botón "Flete" → formulario de origen/destino + tipo de carga,
  peso/volumen, ayudas, foto opcional, contacto de destino (opcional).
  El estado del flujo es idéntico al de viaje normal (radar de ofertas, chat, mapa).
- Conductor: pantallas iguales; su categoría de vehiculo (`FLETE`) decide qué
  solicitudes le asoman. Nota de compra visible en el detalle de la solicitud.
- Panel admin: los listados de viajes/solicitudes ya existentes agregan la columna
  categoría; el CRUD de catálogos sirve para crear CAMIONETA/CAMION/FLETE.
  Sin CRUD nuevo.

## 5. Testing

- Unitarias: solo vehiculo FLETE ve las solicitudes; datos_flete validados
  (tipo_carga obligatorio, peso > 0 si se informa).
- Integración: flujo completo con categoria FLETE hasta pago y comisión
  (reutilizando pruebas de viaje existentes como base).
- Manual: subida de foto en chat (límite de tamaño y degradación si falla),
  banner visible en ambas apps, reinicio de chat al terminar el viaje.

## Fuera de alcance (fase 1)

- App separada de fleteros; pago digital de la mercadería; firmas digitales de
  recibo; repricing automático por peso real (el fletero ajusta por oferta libre);
  tracking multi-parada.
