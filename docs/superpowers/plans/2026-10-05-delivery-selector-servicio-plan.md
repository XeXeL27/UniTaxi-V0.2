# Selector de servicio del pasajero (opcion B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que el pasajero elija entre *Viaje* y *Entrega* en un segmentado siempre visible bajo "¿A donde vas?", y que precio, boton, confirmacion y conteo de conductores hablen del servicio que realmente se esta pidiendo.

**Architecture:** El modo deja de ser un `TipoEnvio?` suelto en `FlujoPasajero` y pasa a un objeto puro `ModoServicio`, que se puede probar sin levantar Flutter y no se puede olvidar limpiar. El widget `SelectorVehiculo` de la derecha del mapa (hoy un solo mosaico decorativo con `activa: true`) se borra; su lugar lo toma un segmentado horizontal en la cabecera, que no se oculta cuando el panel del pedido se pliega. `tipoEnvio` pasa a ser un getter que deriva del servidor cuando ya hay solicitud o viaje, lo que ademas arregla un bug latente de reinicio de app.

**Tech Stack:** Flutter 3 / Dart 3, `provider`, `font_awesome_flutter`, `flutter_test`. Sin dependencias nuevas. Backend sin cambios.

**Spec:** Este plan. No hay spec separado: la opcion B se eligio entre tres designs dibujados y validados con el usuario (A = selector en el strip derecho del mapa, B = segmentado en la cabecera, C = seccion propia de Entregas). La C queda anotada como trabajo futuro en "Fuera de alcance".

## Global Constraints

- Todo el codigo, nombres de clases, metodos, variables, comentarios y textos de interfaz en **espanol**. Sin emojis en codigo, logs, comentarios ni textos.
- Nada de flechas (`->`) ni simbolos sueltos en textos de interfaz: los iconos salen de paquetes.
- Los comentarios explican el **por que**, no el que. Ningun archivo nuevo lleva cabecera de autor ni de fecha.
- Sin dependencias nuevas en `pubspec.yaml`. No se toca `backend/` ni `admin-panel/` en este plan.
- Todo borrado es logico y solo afecta al estado en memoria de la app. Este plan no toca la base de datos.
- Verificacion obligatoria antes de dar por terminado: `flutter analyze` debe terminar con `No issues found!` y `flutter test` con `All tests passed!`.
- La bitacora es acumulativa e indefinida: la entrada nueva va **arriba** de `docs/CHANGELOG.md` (fila en la tabla + seccion `## 2026-10-05`). Nunca se editan entradas viejas.
- Nada de `git commit` salvo que el usuario lo pida explicitamente.
- Se respeta la convencion de nombre de archivo en espanol sin tildes: `modo_servicio.dart`, `selector_servicio.dart`.

---

## Por que esta opcion

Estado actual: el unico selector de delivery es `_SelectorEntrega` (`app-movil/lib/modulos/pasajero/viaje/paneles_pasajero.dart:162`), montado como **primera fila** de `PanelEligiendo` (`paneles_pasajero.dart:68`). Ese panel nace **plegado** porque `pantalla_inicio.dart:160` hace `_panelAbierto = _flujo.etapa != EtapaPasajero.eligiendo`. O sea, la puerta al delivery esta en una hoja que el usuario tiene que descubrir, abrir y leer.

Ademas, solo 3 lugares de la app saben de delivery (`paneles_pasajero.dart:17`, `:77` y la rama de compra). Todo lo demas dice "taxi", "viaje", "conductor" y "Moto": `paneles_pasajero.dart:152` (`'Solicitar taxi'`), `:218` y `:248` (`'Precio del viaje'`, `'Moto'` en el detalle de confirmacion), `:367` y `:372` (`'Buscando conductor...'`, `"...les llego a los taxistas"`), `:776` y `:791` (`DisponibilidadTaxis`), `dialogos.dart:85` (`'Confirmas tu viaje?'`), `pantalla_inicio.dart:566` (`'No hay taxistas libres'`).

Y hay un **bug de estado**: `_entrarEligiendo()` (`flujo_pasajero.dart:164`) limpia `solicitud`, `viaje`, `llegandoDestino`, `guardandoLugar` y el mapa, pero **no** `tipoEnvio` ni `datosEntregaForm`. Despues de un reparto, el pasajero vuelve a elegir destino en modo entrega con el pedido anterior cargado en silencio.

## Decisiones de diseno

| Decision | Por que |
|---|---|
| `ModoServicio` como objeto puro, no 3 campos sueltos | Hoy el modo esta en `tipoEnvio` / `datosEntregaForm` / `idCategoriaDelivery` y no se limpia. Un objeto con `limpiar()` hace imposible que se repita el bug, y se testea sin Flutter. |
| `tipoEnvio` pasa a getter que deriva del servidor | Si el pasajero cierra la app con un reparto en curso, `_recuperarUnaVez()` entra a `_entrarBuscando()` sin pasar nunca por `elegirTipoEnvio`. Hoy `tipoEnvio` queda `null` y toda la pantalla dice "taxistas" durante un pedido de reparto. Es un bug real, no hipotetico. |
| El sub-tipo se elige **inline** debajo del segmentado | Es el corazon del problema: el selector estaba dentro de una hoja cerrada. Decision del usuario: inline, no modal. |
| Se borra `SelectorVehiculo` | Quedaria sin uso en todo `app-movil` (verificado: `grep -rn "SelectorVehiculo\|OpcionVehiculo" app-movil/lib app-movil/test` solo devuelve la definicion y el call site de `pantalla_inicio.dart:854`). Ademas "Moto" al lado de "Viaje" se contradice. |
| `idCategoriaDelivery` **no** se limpia en `_entrarEligiendo` | Es un id de catalogo cacheado, no un estado del pedido. Conservarlo ahorra un `GET /api/publico/categorias-servicio` en cada pedido. |
| El modo tambien va en `_resumenRuta()` | Con el panel plegado esa barra es lo unico que se ve del pedido. Si el modo no aparece ahi, el pasajero no recuerda que esta mandando un paquete al confirmar. |

## Mapa de archivos

| Archivo | Accion | Responsabilidad |
|---|---|---|
| `app-movil/lib/modulos/pasajero/viaje/modo_servicio.dart` | crear | `ServicioActivo`, `ModoServicio` y todo el copy por servicio. Dart puro, sin Flutter. |
| `app-movil/test/modo_servicio_test.dart` | crear | Tests del modo y del copy. |
| `app-movil/lib/modulos/pasajero/viaje/flujo_pasajero.dart` | modificar | Delega en `ModoServicio`, expone `servicio`, limpia el modo al volver a elegir. |
| `app-movil/lib/widgets/selector_servicio.dart` | crear | `SelectorServicio` (segmentado) y `SelectorTipoEntrega`, con sus constantes de alto. |
| `app-movil/test/selector_servicio_test.dart` | crear | Widget tests del segmentado. |
| `app-movil/lib/modulos/pasajero/inicio/pantalla_inicio.dart` | modificar | Monta el segmentado, ajusta el encuadre del mapa, repunta la guia, borra el selector de moto. |
| `app-movil/lib/modulos/pasajero/viaje/paneles_pasajero.dart` | modificar | Saca `_SelectorEntrega`; copy por servicio en todos los paneles. |
| `app-movil/lib/widgets/inicio_mapa.dart` | modificar | Borrar `OpcionVehiculo`, `SelectorVehiculo` y `_Vehiculo` (lineas 255-376). |
| `docs/CHANGELOG.md` | modificar | Bitacora. |

---

### Task 1: `ModoServicio` y el copy por servicio

**Files:**
- Create: `app-movil/lib/modulos/pasajero/viaje/modo_servicio.dart`
- Test: `app-movil/test/modo_servicio_test.dart`

**Interfaces:**
- Consumes: `TipoEnvio` de `app-movil/lib/comun/modelos_viaje.dart:8` (`encomienda`, `compraYEntrega`, campo `nombre`).
- Produces:
  - `enum ServicioActivo { viaje, entrega }`
  - `class ModoServicio` con `TipoEnvio? tipo`, `bool selectorVisible`, constructor `ModoServicio({TipoEnvio? tipo, bool selectorVisible = false})`, getters `bool esEntrega` y `ServicioActivo activo`, metodos `void tocarEntrega()`, `void volverAViaje()`, `void elegir(TipoEnvio valor)`, `void limpiar()`.
  - `ServicioActivo servicioDe(TipoEnvio? tipoEnvio)`
  - `String textoSolicitar(ServicioActivo)`, `textoConfirmacion(ServicioActivo)`, `textoBuscando(ServicioActivo)`, `textoSolicitudEnviada(ServicioActivo)`, `textoSinLibresTitulo(ServicioActivo)`, `textoSinLibresAviso(ServicioActivo)`, `textoLibres(int n, ServicioActivo)`, `textoLibresCorto(int? n, ServicioActivo)`.

- [ ] **Step 1: Write the failing test**

Crear `app-movil/test/modo_servicio_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/modo_servicio.dart';

void main() {
  group('ModoServicio', () {
    test('empieza en viaje y sin selector abierto', () {
      final modo = ModoServicio();
      expect(modo.tipo, isNull);
      expect(modo.selectorVisible, isFalse);
      expect(modo.esEntrega, isFalse);
      expect(modo.activo, ServicioActivo.viaje);
    });

    test('tocar Entrega abre el selector y ya muestra el modo entrega', () {
      final modo = ModoServicio();
      modo.tocarEntrega();
      expect(modo.selectorVisible, isTrue);
      expect(modo.activo, ServicioActivo.entrega);
    });

    test('tocar Entrega con tipo ya elegido no abre el selector', () {
      final modo = ModoServicio()..elegir(TipoEnvio.encomienda);
      modo.tocarEntrega();
      expect(modo.selectorVisible, isFalse);
      expect(modo.tipo, TipoEnvio.encomienda);
    });

    test('elegir tipo deja el modo entrega y cierra el selector', () {
      final modo = ModoServicio()..tocarEntrega();
      modo.elegir(TipoEnvio.compraYEntrega);
      expect(modo.tipo, TipoEnvio.compraYEntrega);
      expect(modo.selectorVisible, isFalse);
      expect(modo.activo, ServicioActivo.entrega);
    });

    test('volver a viaje borra el tipo y cierra el selector', () {
      final modo = ModoServicio()..elegir(TipoEnvio.encomienda);
      modo.volverAViaje();
      expect(modo.tipo, isNull);
      expect(modo.selectorVisible, isFalse);
      expect(modo.activo, ServicioActivo.viaje);
    });

    test('limpiar deja el modo como nuevo: el pedido anterior no se filtra', () {
      final modo = ModoServicio()..elegir(TipoEnvio.encomienda);
      modo.limpiar();
      expect(modo.activo, ServicioActivo.viaje);
      expect(modo.esEntrega, isFalse);
    });
  });

  group('servicioDe', () {
    test('sin tipo de envio el servicio es viaje; con tipo, entrega', () {
      expect(servicioDe(null), ServicioActivo.viaje);
      expect(servicioDe(TipoEnvio.encomienda), ServicioActivo.entrega);
      expect(servicioDe(TipoEnvio.compraYEntrega), ServicioActivo.entrega);
    });
  });

  group('copy por servicio', () {
    test('el boton y la confirmacion cambian con el servicio', () {
      expect(textoSolicitar(ServicioActivo.viaje), 'Solicitar taxi');
      expect(textoSolicitar(ServicioActivo.entrega), 'Solicitar entrega');
      expect(textoConfirmacion(ServicioActivo.viaje), '¿Confirmas tu viaje?');
      expect(textoConfirmacion(ServicioActivo.entrega), '¿Confirmas tu entrega?');
    });

    test('mientras busca cambia el nombre de quien busca', () {
      expect(textoBuscando(ServicioActivo.viaje), 'Buscando conductor...');
      expect(textoBuscando(ServicioActivo.entrega), 'Buscando repartidor...');
      expect(textoSolicitudEnviada(ServicioActivo.viaje), contains('taxistas'));
      expect(textoSolicitudEnviada(ServicioActivo.entrega), contains('repartidores'));
      expect(textoSinLibresTitulo(ServicioActivo.entrega), 'No hay repartidores libres');
      expect(textoSinLibresAviso(ServicioActivo.entrega), contains('repartidores'));
    });

    test('el conteo de libres concuerda en singular y plural', () {
      expect(textoLibres(1, ServicioActivo.viaje), '1 taxista libre cerca de ti');
      expect(textoLibres(4, ServicioActivo.viaje), '4 taxistas libres cerca de ti');
      expect(textoLibres(1, ServicioActivo.entrega), '1 repartidor libre cerca de ti');
      expect(textoLibres(4, ServicioActivo.entrega), '4 repartidores libres cerca de ti');
    });

    test('la version corta distingue cargando, cero, uno y varios', () {
      expect(textoLibresCorto(null, ServicioActivo.viaje), 'Buscando taxistas...');
      expect(textoLibresCorto(0, ServicioActivo.viaje), 'Sin taxistas libres');
      expect(textoLibresCorto(1, ServicioActivo.viaje), '1 taxista libre');
      expect(textoLibresCorto(7, ServicioActivo.viaje), '7 taxistas libres');
      expect(textoLibresCorto(null, ServicioActivo.entrega), 'Buscando repartidores...');
      expect(textoLibresCorto(0, ServicioActivo.entrega), 'Sin repartidores libres');
      expect(textoLibresCorto(1, ServicioActivo.entrega), '1 repartidor libre');
      expect(textoLibresCorto(7, ServicioActivo.entrega), '7 repartidores libres');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app-movil && flutter test test/modo_servicio_test.dart
```

Expected: error de compilacion `Target of URI doesn't exist: 'package:taxiuap_movil/modulos/pasajero/viaje/modo_servicio.dart'`.

- [ ] **Step 3: Write minimal implementation**

Crear `app-movil/lib/modulos/pasajero/viaje/modo_servicio.dart`:

```dart
import '../../../comun/modelos_viaje.dart';

/// Servicio que elige el pasajero en la pantalla de inicio: que lo lleven a el o que manden un
/// paquete por el. Vive fuera de FlujoPasajero para poder probarlo sin levantar Flutter.
enum ServicioActivo { viaje, entrega }

/// Modo del servicio: que se pide y, si todavia no se sabe que se manda, si el selector
/// "¿qué quieres enviar?" esta abierto. Tipo null significa viaje normal, y es el unico lugar
/// donde vive el modo.
class ModoServicio {
  /// Tipo de envio elegido; null mientras el servicio es un viaje.
  TipoEnvio? tipo;

  /// El pasajero abrio el selector de tipo y todavia no eligio ninguno.
  bool selectorVisible;

  ModoServicio({this.tipo, this.selectorVisible = false});

  /// El modo es entrega desde que se abre el selector, para que el pasajero vea que cambio de
  /// servicio antes de decidir que manda.
  bool get esEntrega => tipo != null || selectorVisible;

  ServicioActivo get activo => esEntrega ? ServicioActivo.entrega : ServicioActivo.viaje;

  /// Tocar "Entrega" en el segmentado: si ya hay tipo solo cambia de modo; si no, abre el selector.
  void tocarEntrega() {
    if (tipo != null) return;
    selectorVisible = !selectorVisible;
  }

  /// Tocar "Viaje" en el segmentado: vuelve al viaje normal y cierra el selector.
  void volverAViaje() {
    tipo = null;
    selectorVisible = false;
  }

  void elegir(TipoEnvio valor) {
    tipo = valor;
    selectorVisible = false;
  }

  /// Al volver a elegir destino el modo arranca de cero. Sin esto, el pasajero queda en modo
  /// entrega con los datos del pedido anterior cargados en silencio.
  void limpiar() => volverAViaje();
}

/// Servicio que corresponde a un tipo de envio, sea el del modo o el que trae el servidor.
ServicioActivo servicioDe(TipoEnvio? tipoEnvio) =>
    tipoEnvio == null ? ServicioActivo.viaje : ServicioActivo.entrega;

/// Textos que cambian segun el servicio. En un pedido de reparto se habla de repartidores y no de
/// taxistas: son otros vehiculos y otro trabajo.
String textoSolicitar(ServicioActivo servicio) =>
    servicio == ServicioActivo.entrega ? 'Solicitar entrega' : 'Solicitar taxi';

String textoConfirmacion(ServicioActivo servicio) =>
    servicio == ServicioActivo.entrega ? '¿Confirmas tu entrega?' : '¿Confirmas tu viaje?';

String textoBuscando(ServicioActivo servicio) =>
    servicio == ServicioActivo.entrega ? 'Buscando repartidor...' : 'Buscando conductor...';

String textoSolicitudEnviada(ServicioActivo servicio) => servicio == ServicioActivo.entrega
    ? 'Tu pedido ya les llegó a los repartidores.'
    : 'Tu solicitud ya les llegó a los taxistas.';

String textoSinLibresTitulo(ServicioActivo servicio) =>
    servicio == ServicioActivo.entrega ? 'No hay repartidores libres' : 'No hay taxistas libres';

String textoSinLibresAviso(ServicioActivo servicio) => servicio == ServicioActivo.entrega
    ? 'Tu pedido ya fue enviado. En este momento no hay repartidores libres, así que puede demorar un poco.'
    : 'Tu solicitud ya fue enviada. En este momento no hay taxistas libres, así que puede demorar un poco.';

/// "3 repartidores libres cerca de ti", con el singular y el plural correctos.
String textoLibres(int n, ServicioActivo servicio) {
  if (n == 1) {
    return servicio == ServicioActivo.entrega ? '1 repartidor libre cerca de ti' : '1 taxista libre cerca de ti';
  }
  return servicio == ServicioActivo.entrega ? '$n repartidores libres cerca de ti' : '$n taxistas libres cerca de ti';
}

/// La misma idea en una linea, para la barra compacta del panel plegado.
String textoLibresCorto(int? n, ServicioActivo servicio) {
  final entrega = servicio == ServicioActivo.entrega;
  return switch (n) {
    null => entrega ? 'Buscando repartidores...' : 'Buscando taxistas...',
    0 => entrega ? 'Sin repartidores libres' : 'Sin taxistas libres',
    1 => entrega ? '1 repartidor libre' : '1 taxista libre',
    _ => entrega ? '$n repartidores libres' : '$n taxistas libres',
  };
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd app-movil && flutter test test/modo_servicio_test.dart
```

Expected: `+11: All tests passed!` (11 tests).

---

### Task 2: `FlujoPasajero` delega en `ModoServicio`

**Files:**
- Modify: `app-movil/lib/modulos/pasajero/viaje/flujo_pasajero.dart:59-62` (campos), `:164` (`_entrarEligiendo`), `:265-279` (`puedeSolicitar`, `elegirTipoEnvio`, `guardarDatosEntrega`)

**Interfaces:**
- Consumes: `ModoServicio`, `ServicioActivo`, `servicioDe` de Task 1.
- Produces:
  - `final ModoServicio modo` (campo publico, solo lectura de estado)
  - `DatosEntregaForm? datosEntregaForm` (campo)
  - `int? idCategoriaDelivery` (campo, se conserva cacheado)
  - `TipoEnvio? get tipoEnvio` (getter derivado)
  - `ServicioActivo get servicio` (getter derivado)
  - `void cambiarServicio(ServicioActivo servicio)`
  - `void elegirTipoEnvio(TipoEnvio? tipo)` (se mantiene nulable a proposito: ver la nota de Task 2)
  - `void guardarDatosEntrega(DatosEntregaForm datos)` (sin cambio de firma)

- [ ] **Step 1: Reemplazar los campos por el objeto y el getter derivado**

En `flujo_pasajero.dart`, agregar el import junto a los de `modelos_viaje`:

```dart
import 'modo_servicio.dart';
```

En las lineas 59-62, reemplazar:

```dart
  /// Si no es null, el siguiente pedido usa la categoria DELIVERY.
  TipoEnvio? tipoEnvio;
  DatosEntregaForm? datosEntregaForm;
  int? idCategoriaDelivery;
```

por:

```dart
  /// Servicio elegido en la cabecera: viaje normal o envio de un paquete.
  final ModoServicio modo = ModoServicio();

  DatosEntregaForm? datosEntregaForm;

  /// Id de la categoria DELIVERY del catalogo. Se cachea y no se limpia en _entrarEligiendo: es un
  /// id, no un estado del pedido, y conservarlo ahorra una consulta antes de cada pedido.
  int? idCategoriaDelivery;

  /// Tipo de envio de lo que se esta moviendo. Si ya hay solicitud o viaje manda el del servidor,
  /// porque al abrir la app con un pedido en curso el pasajero nunca paso por el selector; antes de
  /// pedir, el que eligio el pasajero.
  TipoEnvio? get tipoEnvio =>
      solicitud?.datosEntrega?.tipoEnvio ?? viaje?.datosEntrega?.tipoEnvio ?? modo.tipo;

  /// Servicio de lo que se esta pidiendo ahora, para hablar de repartidor o de taxista.
  ServicioActivo get servicio => servicioDe(tipoEnvio);
```

- [ ] **Step 2: Limpiar el modo al volver a elegir destino**

En `_entrarEligiendo()` (linea 164), despues de la linea `guardandoLugar = false;`, agregar:

```dart
    // El modo tambien arranca de cero: si no, tras un reparto el pasajero vuelve a elegir destino
    // en modo entrega con los datos del pedido anterior cargados en silencio.
    modo.limpiar();
    datosEntregaForm = null;
```

- [ ] **Step 3: Cambiar los mutadores**

Reemplazar `elegirTipoEnvio` y `guardarDatosEntrega` (lineas 269-279) por:

```dart
  /// Toca el segmentado de servicio de la cabecera.
  void cambiarServicio(ServicioActivo servicio) {
    if (servicio == ServicioActivo.entrega) {
      modo.tocarEntrega();
    } else {
      modo.volverAViaje();
      datosEntregaForm = null;
    }
    _avisar();
  }

  /// Elige que se manda. Un null vuelve al viaje normal. La firma sigue siendo nulable porque el
  /// selector viejo `_SelectorEntrega` la usa como `ValueChanged<TipoEnvio?>` y no se borra hasta
  /// el Task 5; `SelectorTipoEntrega` la recibe como `ValueChanged<TipoEnvio>`, que es compatible.
  void elegirTipoEnvio(TipoEnvio? tipo) {
    if (tipo == null) {
      modo.volverAViaje();
    } else {
      modo.elegir(tipo);
    }
    datosEntregaForm = null;
    _avisar();
  }

  void guardarDatosEntrega(DatosEntregaForm datos) {
    modo.elegir(datos.tipoEnvio);
    datosEntregaForm = datos;
    _avisar();
  }
```

`puedeSolicitar` (linea 265) queda igual: ya lee el getter `tipoEnvio`.

- [ ] **Step 4: Correr analisis y tests**

```bash
cd app-movil && flutter analyze && flutter test
```

Expected: `No issues found!` y `All tests passed!`. Nada se rompe todavia: el unico call site de `elegirTipoEnvio` es el selector viejo `_SelectorEntrega` de `paneles_pasajero.dart:69`, que se borra en el Task 5, y `tipoEnvio` sigue funcionando como getter para el resto de la app.

---

### Task 3: Widgets del segmentado

**Files:**
- Create: `app-movil/lib/widgets/selector_servicio.dart`
- Test: `app-movil/test/selector_servicio_test.dart`

**Interfaces:**
- Consumes: `ServicioActivo`, `TipoEnvio` de Task 1; `ColoresApp` de `app-movil/lib/core/tema.dart`.
- Produces:
  - `const double altoSelectorServicio = 42`
  - `const double margenSelectorServicio = 10`
  - `const double altoSelectorTipoEntrega = 84`
  - `class SelectorServicio extends StatelessWidget` con `final ServicioActivo activo` y `final ValueChanged<ServicioActivo> onCambiar`
  - `class SelectorTipoEntrega extends StatelessWidget` con `final TipoEnvio? tipo`, `final ValueChanged<TipoEnvio> onElegir`, `final bool datosCompletos`

- [ ] **Step 1: Write the failing tests**

Crear `app-movil/test/selector_servicio_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/core/tema.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/modo_servicio.dart';
import 'package:taxiuap_movil/widgets/selector_servicio.dart';

Widget _envolver(Widget hijo) => MaterialApp(home: Scaffold(body: Center(child: hijo)));

void main() {
  testWidgets('el segmentado ofrece Viaje y Entrega', (tester) async {
    await tester.pumpWidget(
      _envolver(SelectorServicio(activo: ServicioActivo.viaje, onCambiar: (_) {})),
    );

    expect(find.text('Viaje'), findsOneWidget);
    expect(find.text('Entrega'), findsOneWidget);
  });

  testWidgets('el servicio activo va sobre azul y el otro queda transparente', (tester) async {
    await tester.pumpWidget(
      _envolver(SelectorServicio(activo: ServicioActivo.entrega, onCambiar: (_) {})),
    );

    final cajas = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .map((c) => (c.decoration as BoxDecoration).color)
        .toList();
    // La primera pastilla es Viaje (inactivo) y la segunda Entrega (activa).
    expect(cajas[0], Colors.transparent);
    expect(cajas[1], ColoresApp.azul);
  });

  testWidgets('tocar Entrega avisa el cambio de servicio', (tester) async {
    var elegido = ServicioActivo.viaje;
    await tester.pumpWidget(
      _envolver(SelectorServicio(activo: elegido, onCambiar: (v) => elegido = v)),
    );

    await tester.tap(find.text('Entrega'));
    expect(elegido, ServicioActivo.entrega);
  });

  testWidgets('tocar Viaje avisa el cambio a viaje', (tester) async {
    var elegido = ServicioActivo.entrega;
    await tester.pumpWidget(
      _envolver(SelectorServicio(activo: elegido, onCambiar: (v) => elegido = v)),
    );

    await tester.tap(find.text('Viaje'));
    expect(elegido, ServicioActivo.viaje);
  });

  testWidgets('el selector de tipo ofrece encomienda y compra y entrega', (tester) async {
    TipoEnvio? elegido;
    await tester.pumpWidget(
      _envolver(
        SelectorTipoEntrega(
          tipo: TipoEnvio.encomienda,
          datosCompletos: false,
          onElegir: (v) => elegido = v,
        ),
      ),
    );

    expect(find.text('¿Qué quieres enviar?'), findsOneWidget);
    expect(find.text('Encomienda'), findsOneWidget);
    expect(find.text('Compra y entrega'), findsOneWidget);

    await tester.tap(find.text('Compra y entrega'));
    expect(elegido, TipoEnvio.compraYEntrega);
  });

  testWidgets('el selector de tipo avisa cuando los datos ya estan completos', (tester) async {
    await tester.pumpWidget(
      _envolver(
        SelectorTipoEntrega(tipo: TipoEnvio.encomienda, datosCompletos: true, onElegir: (_) {}),
      ),
    );

    expect(find.text('Datos de la entrega completos'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app-movil && flutter test test/selector_servicio_test.dart
```

Expected: `Target of URI doesn't exist: 'package:taxiuap_movil/widgets/selector_servicio.dart'`.

- [ ] **Step 3: Write minimal implementation**

Crear `app-movil/lib/widgets/selector_servicio.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../comun/modelos_viaje.dart';
import '../core/tema.dart';
import '../modulos/pasajero/viaje/modo_servicio.dart';

/// Alto del segmentado de servicio, sin el margen que lo separa del buscador.
const double altoSelectorServicio = 42;

/// Margen entre el segmentado y el buscador, y entre el segmentado y el selector de tipo.
const double margenSelectorServicio = 10;

/// Alto del selector "¿qué quieres enviar?" con sus dos botones.
const double altoSelectorTipoEntrega = 84;

/// Segmentado "Viaje | Entrega" de la cabecera del pasajero. A diferencia del selector de la derecha
/// del mapa, este esta siempre visible mientras se elige destino, con el panel abierto o cerrado:
/// por eso el servicio se puede ver al confirmar el pedido.
class SelectorServicio extends StatelessWidget {
  final ServicioActivo activo;
  final ValueChanged<ServicioActivo> onCambiar;

  const SelectorServicio({super.key, required this.activo, required this.onCambiar});

  @override
  Widget build(BuildContext context) {
    Widget opcion(FaIconData icono, String texto, ServicioActivo valor) {
      final elegido = activo == valor;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(altoSelectorServicio / 2),
          onTap: () => onCambiar(valor),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: altoSelectorServicio - 6,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: elegido ? ColoresApp.azul : Colors.transparent,
              borderRadius: BorderRadius.circular(altoSelectorServicio / 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(icono, size: 13, color: elegido ? ColoresApp.blanco : ColoresApp.azul),
                const SizedBox(width: 7),
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: elegido ? ColoresApp.blanco : ColoresApp.azul,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: altoSelectorServicio,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(altoSelectorServicio / 2),
        boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          opcion(FontAwesomeIcons.motorcycle, 'Viaje', ServicioActivo.viaje),
          opcion(FontAwesomeIcons.boxOpen, 'Entrega', ServicioActivo.entrega),
        ],
      ),
    );
  }
}

/// Selector "¿qué quieres enviar?" con encomienda o compra y entrega. Va debajo del segmentado y no
/// dentro del panel del pedido, que es donde estaba y no se veia.
class SelectorTipoEntrega extends StatelessWidget {
  final TipoEnvio? tipo;
  final bool datosCompletos;
  final ValueChanged<TipoEnvio> onElegir;

  const SelectorTipoEntrega({
    super.key,
    required this.tipo,
    required this.onElegir,
    this.datosCompletos = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget opcion(TipoEnvio valor) {
      final elegido = tipo == valor;
      return Expanded(
        child: OutlinedButton(
          onPressed: () => onElegir(valor),
          style: OutlinedButton.styleFrom(
            foregroundColor: elegido ? ColoresApp.blanco : ColoresApp.azul,
            backgroundColor: elegido ? ColoresApp.azul : null,
            side: BorderSide(color: elegido ? ColoresApp.azul : ColoresApp.borde),
          ),
          child: Text(valor.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
    }

    return Container(
      height: altoSelectorTipoEntrega,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '¿Qué quieres enviar?',
            style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              opcion(TipoEnvio.encomienda),
              const SizedBox(width: 8),
              opcion(TipoEnvio.compraYEntrega),
            ],
          ),
          if (datosCompletos) ...[
            const SizedBox(height: 3),
            const Text(
              'Datos de la entrega completos',
              style: TextStyle(color: ColoresApp.exito, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd app-movil && flutter test test/selector_servicio_test.dart
```

Expected: `+6: All tests passed!`

---

### Task 4: Montarlo en la cabecera y ajustar el encuadre del mapa

**Files:**
- Modify: `app-movil/lib/modulos/pasajero/inicio/pantalla_inicio.dart` (imports `:29-36`, llaves `:111-112`, encuadre `:756-763`, columna de cabecera `:812-847`, bloque del selector `:849-874`, guia `:208-212`, `_resumenRuta()` `:940-948`)
- Modify: `app-movil/lib/widgets/inicio_mapa.dart:255-376` (borrar)

**Interfaces:**
- Consumes: `SelectorServicio`, `SelectorTipoEntrega`, `altoSelectorServicio`, `margenSelectorServicio`, `altoSelectorTipoEntrega` de Task 3; `FlujoPasajero.modo`, `.cambiarServicio`, `.datosEntregaForm`, `.elegirTipoEnvio`, `.servicio` de Task 2.
- Produces: nada que otras tareas consuman; es el cableado a la pantalla.

- [ ] **Step 1: Import y llave de la guia**

En `pantalla_inicio.dart`, agregar el import entre `requiere_gps.dart` y los de `modulos/pasajero`:

```dart
import '../../../widgets/selector_servicio.dart';
```

En las lineas 111-112, reemplazar `final _guiaMoto = GlobalKey();` por `final _guiaServicio = GlobalKey();`

- [ ] **Step 2: El encuadre del mapa**

`_mapa.margenesVista` (linea 763) se calcula **antes** de declarar `eligiendo` y `panel`. Hay que subir esas dos declaraciones por encima, porque el alto del segmentado depende de `eligiendo`.

Reemplazar el bloque:

```dart
        final etapa = _flujo.etapa;
        // Lo que tapan la cabecera con el buscador y el panel con la barra, para encuadrar la ruta.
        final compacto = etapa == EtapaPasajero.buscando || (_panelEsPlegable && !_panelAbierto);
        _mapa.margenesVista = EdgeInsets.fromLTRB(56, margen.top + 160, 110, abajo + (compacto ? 170 : alto * 0.36));
        final eligiendo = etapa == EtapaPasajero.eligiendo;
        final panel = _panel(etapa);
```

por:

```dart
        final etapa = _flujo.etapa;
        final eligiendo = etapa == EtapaPasajero.eligiendo;
        final panel = _panel(etapa);
        // Lo que tapan la cabecera con el buscador y el panel con la barra, para encuadrar la ruta.
        final compacto = etapa == EtapaPasajero.buscando || (_panelEsPlegable && !_panelAbierto);
        // El segmentado de servicio y el selector de tipo van sobre el mapa: su alto se descuenta
        // para que la ruta siga encuadrada entre la cabecera y el panel.
        final extraCabecera = eligiendo
            ? margenSelectorServicio +
                  altoSelectorServicio +
                  (_flujo.modo.selectorVisible ? margenSelectorServicio + altoSelectorTipoEntrega : 0)
            : 0;
        _mapa.margenesVista = EdgeInsets.fromLTRB(
          56,
          margen.top + 160 + extraCabecera,
          110,
          abajo + (compacto ? 170 : alto * 0.36),
        );
```

- [ ] **Step 3: Montar el segmentado en la cabecera**

En el `Positioned(top: 0, left: 0, right: 0, child: Column(...))`, justo despues del bloque `if (eligiendo) ... BarraDestino ...`, agregar:

```dart
                  // El servicio se elige aca y no en el panel del pedido: el panel nace plegado, asi
                  // que un selector dentro de el no se ve y el pasajero no sabe que puede mandar.
                  if (eligiendo)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: anchoControlesMapa),
                        child: Column(
                          children: [
                            const SizedBox(height: margenSelectorServicio),
                            SelectorServicio(
                              key: _guiaServicio,
                              activo: _flujo.modo.activo,
                              onCambiar: _flujo.cambiarServicio,
                            ),
                            if (_flujo.modo.selectorVisible) ...[
                              const SizedBox(height: margenSelectorServicio),
                              SelectorTipoEntrega(
                                tipo: _flujo.modo.tipo,
                                datosCompletos: _flujo.datosEntregaForm != null,
                                onElegir: _flujo.elegirTipoEnvio,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
```

- [ ] **Step 4: Borrar el selector de la derecha del mapa**

En `pantalla_inicio.dart`, borrar el bloque completo (lineas 848-874), con su comentario:

```dart
            // Con el panel abierto (ruta, busqueda) el selector se esconde para no montarse sobre
            // el panel ni sobre los botones del mapa.
            if (eligiendo && panel == null)
              Positioned(
                right: 14,
                top: margen.top + 170,
                child: SelectorVehiculo(
```

...hasta el cierre `),` que sigue al `onTap` de `OpcionVehiculo`.

Luego, en `app-movil/lib/widgets/inicio_mapa.dart`, borrar `class OpcionVehiculo`, `class SelectorVehiculo` y `class _Vehiculo` (lineas 255-376, desde el doc-comment `/// Opcion del selector de vehiculo de la derecha del mapa.` hasta justo antes de `/// Hoja de soporte: asistencia, ayuda rapida y canales de atencion.`).

Verificar que quedaron sin uso:

```bash
cd app-movil && grep -rn "SelectorVehiculo\|OpcionVehiculo" lib test
```

Expected: sin resultados.

- [ ] **Step 5: El paso de la guia de inicio**

En `mostrarGuiaInicio` (lineas 208-212), reemplazar el paso que apuntaba a `_guiaMoto`:

```dart
      PasoGuia(
        clave: _guiaServicio,
        titulo: 'Viaje o entrega',
        texto: 'Aquí eliges si quieres que te lleven a algún lado o que mandemos un paquete por ti.',
      ),
```

- [ ] **Step 6: Correr analisis y tests**

```bash
cd app-movil && flutter analyze && flutter test
```

Expected: `No issues found!` y `All tests passed!`.

---

### Task 5: Copy por servicio en los paneles y en la solicitud

**Files:**
- Modify: `app-movil/lib/modulos/pasajero/viaje/paneles_pasajero.dart` (`:68-72` quitar montaje, `:77` etiqueta de precio, `:149` call site de disponibilidad, `:151-155` boton, `:162-200` borrar clase, `:210-260` detalle de confirmacion, `:366-380` panel buscando, `:764-799` clase `DisponibilidadTaxis`, `:807-870` `OpcionesEligiendo`)
- Modify: `app-movil/lib/modulos/pasajero/inicio/pantalla_inicio.dart:940-948` (`_resumenRuta`), `:549-577` (`_solicitar`)

**Interfaces:**
- Consumes: las 8 funciones de copy de Task 1 y `FlujoPasajero.servicio` / `.tipoEnvio` de Task 2.
- Produces: nada que otras tareas consuman.

- [ ] **Step 1: Quitar `_SelectorEntrega` del panel del pedido**

En `PanelEligiendo.build`, borrar el bloque:

```dart
        _SelectorEntrega(
          tipo: flujo.tipoEnvio,
          onElegir: flujo.elegirTipoEnvio,
          completado: flujo.datosEntregaForm != null,
        ),
        const SizedBox(height: 12),
```

y borrar la clase `_SelectorEntrega` completa (lineas 162-200), desde `class _SelectorEntrega extends StatelessWidget {` hasta el cierre de la clase.

- [ ] **Step 2: La etiqueta del precio y el boton**

En el mismo `build`, la etiqueta del `RecuadroPrecio` (linea 77):

```dart
            etiqueta: flujo.servicio == ServicioActivo.entrega ? 'Precio del servicio' : 'Precio del viaje',
```

y el `BotonPrincipal` (lineas 151-155):

```dart
          BotonPrincipal(
            texto: textoSolicitar(flujo.servicio),
            cargando: enviando,
            onPressed: flujo.puedeSolicitar ? onSolicitar : null,
          ),
```

- [ ] **Step 3: `DisponibilidadTaxis`**

Cambiar la clase (lineas 764-799) por:

```dart
class DisponibilidadTaxis extends StatelessWidget {
  final int? libres;
  final ServicioActivo servicio;

  const DisponibilidadTaxis({super.key, required this.libres, required this.servicio});
```

y su `build`:

```dart
  @override
  Widget build(BuildContext context) {
    final n = libres;
    if (n == null) return const SizedBox.shrink();
    if (n == 0) {
      return _Aviso(icono: FontAwesomeIcons.triangleExclamation, texto: textoSinLibresAviso(servicio));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ColoresApp.exito.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          FaIcon(
            servicio == ServicioActivo.entrega
                ? FontAwesomeIcons.boxOpen
                : FontAwesomeIcons.motorcycle,
            color: ColoresApp.exito,
            size: 15,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              textoLibres(n, servicio),
              style: const TextStyle(color: ColoresApp.exito, fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
```

Actualizar el call site en `PanelEligiendo`: `DisponibilidadTaxis(libres: libres, servicio: flujo.servicio),`

- [ ] **Step 4: `OpcionesEligiendo` (barra del panel plegado)**

Reemplazar el `switch` que produce texto y color (lineas 810-817) por:

```dart
    final n = libres;
    final color = switch (n) {
      null => ColoresApp.textoSuave,
      0 => const Color(0xFFE67E22),
      _ => ColoresApp.exito,
    };
    final texto = textoLibresCorto(n, flujo.servicio);
```

El resto del widget (el punto de color, el `Text`, los botones de pago) queda igual: ya usa `color` y `texto`.

- [ ] **Step 5: `PanelBuscando`**

Cambiar el titulo y el subtitulo (lineas 366-380):

```dart
                  Text(
                    textoBuscando(widget.flujo.servicio),
                    style: const TextStyle(color: ColoresApp.azul, fontSize: 16.5, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    sinLibres ? textoSinLibresAviso(widget.flujo.servicio) : textoSolicitudEnviada(widget.flujo.servicio),
                    maxLines: 2,
                    style: TextStyle(
                      color: sinLibres ? const Color(0xFFE67E22) : ColoresApp.textoSuave,
                      fontSize: 12.5,
                      fontWeight: sinLibres ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
```

- [ ] **Step 6: El detalle de la confirmacion**

En `DetalleSolicitudViaje.build`, la etiqueta del precio (linea 218):

```dart
          etiqueta: flujo.servicio == ServicioActivo.entrega ? 'Precio del servicio' : 'Precio del viaje',
```

y la fila "Servicio" (lineas 240-253), que hoy muestra siempre la moto:

```dart
        _FilaDato(
          etiqueta: 'Servicio',
          valor: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (flujo.servicio == ServicioActivo.entrega) ...[
                const FaIcon(FontAwesomeIcons.boxOpen, color: ColoresApp.ruta, size: 14),
                const SizedBox(width: 6),
                Text(
                  flujo.tipoEnvio?.nombre ?? 'Entrega',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ColoresApp.texto),
                ),
              ] else ...[
                Image.asset('assets/mototaxi.png', height: 24, fit: BoxFit.contain),
                const SizedBox(width: 8),
                const Text(
                  'Moto',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ColoresApp.texto),
                ),
              ],
            ],
          ),
        ),
```

- [ ] **Step 7: El modo visible con el panel plegado**

En `pantalla_inicio.dart`, reemplazar `_resumenRuta()` (lineas 940-948) por:

```dart
  /// "Entrega - Tarifa: 8 Bs - 679 m - 2 min". Con el panel plegado esta barra es lo unico que se
  /// ve del pedido, asi que el servicio tiene que aparecer aca: si no, el pasajero no recuerda que
  /// esta mandando un paquete cuando confirma.
  String _resumenRuta() {
    final precio = _flujo.precio?.precio;
    final ruta = _mapa.ruta;
    return [
      if (_flujo.servicio == ServicioActivo.entrega) 'Entrega',
      'Tarifa: ${precio != null ? formatoBs(precio) : 'a calcular'}',
      if (ruta != null) ...[ruta.distanciaTexto, ruta.duracionTexto] else 'trazando la ruta...',
    ].join(' - ');
  }
```

- [ ] **Step 8: El pedido y su aviso**

En `_solicitar()` de `pantalla_inicio.dart` (lineas 549-577), reemplazar por:

```dart
  Future<void> _solicitar() async {
    // En un pedido de reparto faltan los datos antes de poder pedirlo.
    if (_flujo.servicio == ServicioActivo.entrega && _flujo.datosEntregaForm == null) {
      final tipo = _flujo.modo.tipo;
      if (tipo == null) return;
      final datos = await abrirFormularioEntrega(context, tipo);
      if (datos == null || !mounted) return;
      _flujo.guardarDatosEntrega(datos);
    }
    final confirmado = await confirmarViaje(
      context,
      titulo: textoConfirmacion(_flujo.servicio),
      contenido: DetalleSolicitudViaje(flujo: _flujo),
    );
    if (!confirmado || !mounted) return;
    setState(() => _enviando = true);
    try {
      await _flujo.solicitar();
      if (mounted && _libres == 0) {
        await mostrarAviso(
          context,
          titulo: textoSinLibresTitulo(_flujo.servicio),
          mensaje: textoSinLibresAviso(_flujo.servicio),
        );
      }
    } on ApiExcepcion catch (e) {
      // La misma pantalla de antes: el mensaje que trae el servidor.
      if (mounted) mostrarMensaje(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
```

- [ ] **Step 9: Correr analisis y tests**

```bash
cd app-movil && flutter analyze && flutter test
```

Expected: `No issues found!` y `All tests passed!`.

---

### Task 6: Verificacion completa y bitacora

**Files:**
- Modify: `docs/CHANGELOG.md`

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: entrada de bitacora.

- [ ] **Step 1: Analisis estatico**

```bash
cd app-movil && flutter analyze
```

Expected: `Analyzing app-movil...` y `No issues found!`

- [ ] **Step 2: Suite completa**

```bash
cd app-movil && flutter test
```

Expected: `All tests passed!`, con los 17 tests nuevos (11 de `modo_servicio_test.dart` + 6 de `selector_servicio_test.dart`) sumados a los existentes.

- [ ] **Step 3: Grep de control del copy**

```bash
cd app-movil && grep -rn "Solicitar taxi\|Buscando conductor\|Confirmas tu viaje\|Qué quieres enviar\|taxistas libres\|Conductor aceptado" lib/modulos/pasajero lib/widgets/dialogos.dart
```

Expected: los unicos resultados admitidos son las dos variantes dentro de las funciones de copy de `modo_servicio.dart`. No debe quedar ningun `BotonPrincipal(texto: 'Solicitar taxi'` ni `Text('Buscando conductor...')` fijo en los paneles.

- [ ] **Step 4: Confirmar que no quedo copy de moto junto al segmentado**

```bash
cd app-movil && grep -rn "nombre: 'Moto'\|assets/mototaxi.png" lib/modulos/pasajero/inicio lib/widgets/selector_servicio.dart
```

Expected: la unica coincidencia es el asset de moto del detalle de confirmacion, que ahi si corresponde (un viaje normal). En `inicio_mapa.dart` no debe quedar ninguno.

- [ ] **Step 5: Bitacora**

Agregar **arriba** de `docs/CHANGELOG.md`:

1. Una fila en la tabla de resumen:
   `| 2026-10-05 | ✨ | El pasajero elige entre viaje y entrega en un segmentado de la cabecera, con el texto del pedido acorde al servicio |`

2. Una seccion nueva arriba del todo del cuerpo:

```markdown
## 2026-10-05

### ✨ Nuevo · El pasajero elige entre viaje y entrega en la cabecera

- **Módulo / área:** app móvil del pasajero (`app-movil`), pantalla de inicio
- **Descripción:** el selector de entrega estaba como primera fila del panel del pedido, que nace
  plegado, así que el pasajero no veía que podía mandar un paquete. Ahora elige *Viaje* o *Entrega*
  en un segmentado bajo "¿A dónde vas?", siempre visible con el panel abierto o cerrado, y todo el
  texto (precio, botón, confirmación, conductores libres) habla del servicio que se está pidiendo.
- **Cambios clave:**
  - `ModoServicio` (nuevo, Dart puro): única fuente de verdad del modo, con `limpiar()` para que el
    pedido anterior no se filtre al volver a elegir destino
  - `tipoEnvio` pasa a derivar del servidor cuando ya hay solicitud o viaje; arregla el caso de abrir
    la app con un reparto en curso, donde toda la pantalla decía "taxistas"
  - `_entrarEligiendo()` limpia el modo y los datos de entrega
  - `SelectorServicio` y `SelectorTipoEntrega` (nuevos) en la cabecera; el encuadre del mapa descuenta
    su alto
  - Se borra `SelectorVehiculo` / `OpcionVehiculo` / `_Vehiculo`, que quedaban sin uso
  - Copy por servicio en los paneles: "repartidor" en vez de "taxista", "Solicitar entrega",
    "¿Confirmas tu entrega?", "Buscando repartidor..."
  - El modo aparece también en la barra del panel plegado
- **Archivos afectados:**
  - `app-movil/lib/modulos/pasajero/viaje/modo_servicio.dart` (nuevo)
  - `app-movil/lib/widgets/selector_servicio.dart` (nuevo)
  - `app-movil/lib/modulos/pasajero/viaje/flujo_pasajero.dart`
  - `app-movil/lib/modulos/pasajero/viaje/paneles_pasajero.dart`
  - `app-movil/lib/modulos/pasajero/inicio/pantalla_inicio.dart`
  - `app-movil/lib/widgets/inicio_mapa.dart`
  - `app-movil/test/modo_servicio_test.dart` (nuevo)
  - `app-movil/test/selector_servicio_test.dart` (nuevo)
- **Verificación (salida real):** `flutter analyze` → No issues found!; `flutter test` →
  All tests passed! (conteo real copiado de la salida)
```

No tocar ninguna entrada previa.

---

## Fuera de alcance (anotado, no implementado)

1. **Conteo de repartidores.** `backend/.../controller/pasajero/ConductoresEnLineaController.java:24`
   (`listar()`) no acepta ningun parametro, asi que el "3 repartidores libres" sigue contando
   mototaxis de viaje. Plan aparte: `@RequestParam(required = false) Integer idCategoriaServicio` +
   `UbicacionService.conductoresLibres(idCategoria)`, filtrando por la `categoriaServicio` del
   conductor (que ya se carga en `ConductorEnLineaResponse`). Es backend: va en su propio plan
   ("trabajar un dominio a la vez").
2. **Seccion "Mis entregas"** (opcion C). Los codigos de recogida/entrega y el estado
   `NO ENTREGADO` siguen sin casa propia en la app; hoy se ven dentro del panel del viaje.
3. **Formulario de entrega mas corto.** Hoy pide 5 campos para encomienda (descripcion, remitente,
   telefono, receptor, telefono). Podria pedir solo descripcion y el nombre del receptor, y dejar el
   resto para cuando el repartidor lo confirme.
4. **Las tres pruebas manuales de la opcion B en Chrome** las hace el usuario al final, no el
   ejecutor: no hay emulador ni dispositivo en este entorno.

## Riesgos

| Riesgo | Mitigacion |
|---|---|
| La cabecera crece 42 px (+84 con el selector de tipo) y en pantallas de 5" empuja el panel | El encuadre del mapa ya descuenta el extra en el Task 4. Si en la prueba manual queda apretado, el selector de tipo puede ir en un `showModalBottomSheet`: mismo estado, mismo `ModoServicio`, sin tocar la logica. |
| El mapa tapa el segmentado en landscape | `anchoControlesMapa` (560) ya acota la columna de la cabecera y el segmentado es de ancho completo dentro de ella |
| Romper la guia de inicio | El paso 2 pasa a `_guiaServicio`. Si la `GlobalKey` quedara sin montar, `mostrarGuiaInicio` no encuentra el paso y el guide se cierra solo: ese es el sintoma a vigilar en la prueba manual |
| Que `tipoEnvio` derivado rompa `solicitar()` | `solicitar()` (linea 299) lee `tipoEnvio` solo para pedir el id de categoria cuando `tipoEnvio != null`; antes de pedir no hay solicitud ni viaje, asi que el getter cae en `modo.tipo`, que es exactamente el valor anterior |