# Bitácora de cambios

> Registro acumulativo e indefinido de cambios, implementaciones y arreglos del proyecto.
> Nueva entrada arriba: `## FECHA` seguida de uno o más `### TIPO · Título`.

| Fecha | Tipo | Descripción |
|---|---|---|
| 2026-09-29 | ✨ | Favoritos como segunda pestaña de Historial en la app del pasajero |

## Convenciones

- **Fecha:** `YYYY-MM-DD` (no usar texto suelto).
- **Verificación:** cada entrada debe indicar cómo se validó el cambio.
- **Fuente de verdad:** este archivo se mantiene al día al finalizar cada tarea.

---

## 2026-09-29

### ✨ Nuevo · Favoritos dentro de Historial (app del pasajero)

- **Módulo / área:** `app-movil` (Flutter, pasajero)
- **Descripción:** Favoritos deja de ser una sección propia de la barra inferior y pasa a ser la
  segunda pestaña de la sección Historial, junto a los viajes. Solo afecta al pasajero; el
  conductor y el panel admin quedan intactos. Sin cambios en el backend.
- **Cambios clave:**
  - `PantallaHistorial` acepta un builder opcional `pestanaFavoritos` que recibe los viajes ya
    cargados y el relleno. Con él muestra las pestañas `Historial | Favoritos`; sin él se comporta
    exactamente como antes (una sola lista), que es como lo ve el conductor.
  - La pestaña se reinicia en Historial cada vez que se entra a la sección (`recargar`), con un
    setter para que el cambio de estado no se pierda al recargar.
  - Nuevo `SelectorPestanas` reutilizable en `lib/widgets/`: pestañas tipo carpeta.
  - Nuevos "Lugares frecuentes" derivados en cliente de los viajes ya cargados (`COMPLETADOS`):
    agrupación de destinos a 60 m o menos, mínimo de 2 visitas, orden por frecuencia y a igualdad
    por última visita, y nombre/dirección del viaje más reciente del grupo.
  - `sinRepetirConFavoritos` quita de "Lugares frecuentes" los lugares que ya están guardados
    (dentro de 60 m), para que un mismo lugar no aparezca en los dos grupos.
  - "Agregar a favoritos" llama a `FavoritosApi.crear` (`POST /api/pasajero/direcciones`) y el
    lugar deja de listarse como frecuente porque ya figura entre los guardados.
  - Tocar cualquier lugar, guardado o deducido, lo pone como destino y regresa al mapa; si el
    pasajero ya tiene un viaje en curso avisa y no cambia nada.
  - Un favorito sin posición se muestra sin acción de destino (no se sabe a dónde ir).
  - Barra inferior del pasajero de 4 a 3 secciones: `Inicio | Historial | Más`.
- **Archivos afectados:**
  - `app-movil/lib/widgets/selector_pestanas.dart` (nuevo)
  - `app-movil/lib/modulos/pasajero/favoritos/lugares_frecuentes.dart` (nuevo)
  - `app-movil/lib/modulos/pasajero/favoritos/seccion_favoritos.dart` (reescrito: los dos grupos)
  - `app-movil/lib/comun/historial_viajes.dart` (pestañas y builder opcional)
  - `app-movil/lib/modulos/pasajero/inicio/pantalla_inicio.dart` (barra, cableado, promoción)
  - `app-movil/test/lugares_frecuentes_test.dart` (nuevo, 14 pruebas)
- **Verificación:** `flutter analyze` sin incidencias; `flutter test` 14/14;
  `dart format --line-length 120` sobre los archivos del cambio.
