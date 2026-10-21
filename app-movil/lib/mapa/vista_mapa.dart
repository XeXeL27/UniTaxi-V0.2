import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../core/iconos.dart';
import '../core/tema.dart';
import '../widgets/notificaciones.dart';
import '../widgets/paneles.dart';
import 'controlador_mapa.dart';
import 'pin_mapa.dart';

/// Mapa a pantalla completa: tiles de OpenStreetMap, ruta azul entre A y B, tramo naranja de
/// acercamiento, punto azul del GPS y la partida y el destino como circulos sin letra (azul y rojo).
class MapaBase extends StatelessWidget {
  final ControladorMapa controlador;

  /// Toque sobre el mapa (el pasajero marca su destino).
  final void Function(LatLng punto)? onTap;

  /// Marcadores de la pantalla (por ejemplo los mototaxistas en linea), debajo de A, B y el GPS.
  final List<Marker> marcadoresExtra;

  /// Capas que se repintan solas (los mototaxistas que se deslizan, el radar de busqueda), debajo
  /// de A, B y el GPS.
  final List<Widget> capasAnimadas;

  const MapaBase({
    super.key,
    required this.controlador,
    this.onTap,
    this.marcadoresExtra = const [],
    this.capasAnimadas = const [],
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controlador,
      builder: (context, _) {
        final c = controlador;
        final ruta = c.ruta;
        // Durante el viaje en curso la ruta se va borrando con el avance (lo recorrido no se dibuja).
        final puntosRuta = c.puntosRuta;
        final acercamiento = c.puntosAcercamiento;
        final rutaConductor = c.puntosRutaConductor;
        final siguiendoAvance = c.fuenteAvance != FuenteAvance.ninguna;
        final a = c.a;
        final b = c.b;
        final gps = c.miUbicacion;
        final conductorPos = c.conductorUbicacion;
        final conductorRumbo = c.conductorRumbo;
        // El mapa queda fuera de la accesibilidad: como se puede tocar, Flutter lo publicaba como un
        // boton "A B" del tamano de la pantalla, encima de los botones del panel (con el lector de
        // pantalla o la accesibilidad del navegador, los toques le llegaban al mapa).
        return ExcludeSemantics(
          child: FlutterMap(
            mapController: c.mapa,
            options: MapOptions(
              initialCenter: c.centroInicial,
              initialZoom: 15,
              minZoom: 5,
              maxZoom: c.capa.zoomNativo.toDouble(),
              backgroundColor: c.capa.enGrises ? const Color(0xFFEDEDED) : const Color(0xFFE8E6E1),
              // Se gira con dos dedos; la brujula (BotonBrujula) vuelve a poner el norte arriba.
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              onMapReady: c.alListarMapa,
              onPositionChanged: (camara, _) => c.alMoverMapa(camara),
              onTap: onTap == null ? null : (_, punto) => onTap!(punto),
            ),
            children: [
              TileLayer(
                key: ValueKey(c.capa),
                urlTemplate: c.capa.url,
                userAgentPackageName: Config.agenteMapas,
                maxNativeZoom: c.capa.zoomNativo,
                tileBuilder: c.capa.enGrises
                    ? (context, tesela, _) => ColorFiltered(colorFilter: filtroMapaGris, child: tesela)
                    : null,
              ),
              PolylineLayer(
                polylines: [
                  if (acercamiento != null && acercamiento.length >= 2)
                    Polyline(
                      points: acercamiento,
                      strokeWidth: 5,
                      color: ColoresApp.rutaSecundaria,
                      borderStrokeWidth: 1.5,
                      borderColor: ColoresApp.rutaSecundariaBorde,
                      pattern: StrokePattern.dashed(segments: const [10, 8]),
                    ),
                  if (rutaConductor != null && rutaConductor.length >= 2)
                    Polyline(
                      points: rutaConductor,
                      strokeWidth: 5,
                      color: ColoresApp.rutaSecundaria,
                      borderStrokeWidth: 1.5,
                      borderColor: ColoresApp.rutaSecundariaBorde,
                      pattern: StrokePattern.dashed(segments: const [10, 8]),
                    ),
                  if (ruta != null && puntosRuta != null && puntosRuta.length >= 2) ...[
                    // La ruta arranca en la calle mas cercana: se une con cada pin por una linea punteada.
                    // Con el viaje en curso la ruta empieza donde va la moto: A ya no se une.
                    if (!ruta.aproximada && a != null && !siguiendoAvance) _tramoAPie(a.posicion, puntosRuta.first),
                    if (!ruta.aproximada && b != null) _tramoAPie(puntosRuta.last, b.posicion),
                    Polyline(
                      points: puntosRuta,
                      strokeWidth: 6,
                      color: ColoresApp.ruta,
                      borderStrokeWidth: 1.5,
                      borderColor: ColoresApp.rutaBorde,
                      pattern: ruta.aproximada
                          ? StrokePattern.dashed(segments: const [14, 10])
                          : const StrokePattern.solid(),
                    ),
                  ],
                ],
              ),
              ...capasAnimadas,
              // rotate: los pines y el GPS quedan derechos aunque se gire el mapa.
              MarkerLayer(
                rotate: true,
                markers: [
                  ...marcadoresExtra,
                  if (a != null) _punto(a.posicion, ColoresApp.azul),
                  if (b != null) _punto(b.posicion, ColoresApp.rojo),
                  // El GPS va encima de los pines: es lo que se mueve en vivo.
                  // El conductor en un viaje se ve como la moto, no como el punto azul.
                  if (gps != null && !c.ocultarMiUbicacion)
                    c.miUbicacionComoMoto
                        ? _moto(gps, c.miRumbo)
                        : Marker(point: gps, width: 26, height: 26, child: const PuntoUbicacion()),
                  // Marcador del conductor asignado al viaje del pasajero.
                  if (conductorPos != null) _moto(conductorPos, conductorRumbo),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Marker _punto(LatLng posicion, Color color) => Marker(
        point: posicion,
        width: CirculoMapa.lado,
        height: CirculoMapa.lado,
        child: CirculoMapa(color: color),
      );

  Marker _moto(LatLng posicion, double? rumbo) => Marker(
        point: posicion,
        width: 32,
        height: 32,
        child: Transform.rotate(
          angle: (rumbo ?? 0) * 3.14159 / 180,
          child: Image.asset(
            'assets/mototaxi.png',
            width: 32,
            height: 32,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      );

  Polyline _tramoAPie(LatLng desde, LatLng hasta) => Polyline(
    points: [desde, hasta],
    strokeWidth: 3,
    color: ColoresApp.textoSuave,
    pattern: const StrokePattern.dotted(),
  );
}

/// Boton redondo para centrar el mapa en la ubicacion del telefono.
class BotonUbicacion extends StatelessWidget {
  final ControladorMapa controlador;

  const BotonUbicacion({super.key, required this.controlador});

  Future<void> _ubicar(BuildContext context) async {
    final ok = await controlador.centrarEnMiUbicacion();
    if (!ok && context.mounted) {
      mostrarMensaje(
        context,
        'No se pudo obtener tu ubicación. Revisa que el GPS esté activo y que la app tenga permiso.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColoresApp.blanco,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: const Color(0x40000000),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _ubicar(context),
        child: const SizedBox(
          width: 50,
          height: 50,
          child: Center(child: Icon(Iconos.locationCrosshairs, color: ColoresApp.tinta, size: 19)),
        ),
      ),
    );
  }
}

/// Brujula: aparece solo con el mapa girado y, al tocarla, vuelve a poner el norte arriba. La
/// aguja roja apunta al norte real.
class BotonBrujula extends StatelessWidget {
  final ControladorMapa controlador;

  const BotonBrujula({super.key, required this.controlador});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: controlador.rotacion,
      builder: (context, grados, _) {
        final girado = grados > 0.5 && grados < 359.5;
        return AnimatedScale(
          scale: girado ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Material(
            color: ColoresApp.blanco,
            shape: const CircleBorder(),
            elevation: 4,
            shadowColor: const Color(0x40000000),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: girado ? controlador.orientarAlNorte : null,
              child: SizedBox(
                width: 50,
                height: 50,
                child: Center(
                  child: Transform.rotate(angle: grados * 3.141592653589793 / 180, child: const _Aguja()),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Brujula en la esquina superior del mapa: aparece solo con el mapa girado y, al tocarla, vuelve
/// a poner el norte arriba.
///
/// Va en el flujo de arriba de la pantalla (la columna de la cabecera y las tarjetas), no en un
/// Positioned: asi el contenido de arriba la empuja hacia abajo y nunca se monta sobre nada.
class BrujulaArriba extends StatelessWidget {
  final ControladorMapa controlador;

  const BrujulaArriba({super.key, required this.controlador});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: controlador.rotacion,
      builder: (context, grados, _) {
        final girado = grados > 0.5 && grados < 359.5;
        if (!girado) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, top: 8),
            child: BotonBrujula(controlador: controlador),
          ),
        );
      },
    );
  }
}

/// Aguja de brujula: mitad roja (norte) y mitad gris.
class _Aguja extends StatelessWidget {
  const _Aguja();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 14,
      height: 30,
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(size: Size(14, 15), painter: _Triangulo(ColoresApp.rojo, arriba: true)),
          ),
          Expanded(
            child: CustomPaint(size: Size(14, 15), painter: _Triangulo(ColoresApp.textoSuave, arriba: false)),
          ),
        ],
      ),
    );
  }
}

class _Triangulo extends CustomPainter {
  final Color color;
  final bool arriba;

  const _Triangulo(this.color, {required this.arriba});

  @override
  void paint(Canvas canvas, Size size) {
    final camino = ui.Path();
    if (arriba) {
      camino
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height);
    } else {
      camino
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height);
    }
    canvas.drawPath(camino..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Triangulo anterior) => anterior.color != color || anterior.arriba != arriba;
}

/// Boton redondo que abre la eleccion de capa del mapa (calles o satelite).
class BotonCapas extends StatelessWidget {
  final ControladorMapa controlador;

  const BotonCapas({super.key, required this.controlador});

  Future<void> _elegir(BuildContext context) async {
    final elegida = await showModalBottomSheet<CapaMapa>(
      context: context,
      backgroundColor: ColoresApp.blanco,
      constraints: const BoxConstraints(maxWidth: 520),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tipo de mapa',
                style: TextStyle(color: ColoresApp.azul, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final capa in CapaMapa.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _OpcionCapa(
                          capa: capa,
                          activa: capa == controlador.capa,
                          onTap: () => Navigator.of(context).pop(capa),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (elegida != null) controlador.cambiarCapa(elegida);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColoresApp.blanco,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: const Color(0x40000000),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _elegir(context),
        child: const SizedBox(
          width: 50,
          height: 50,
          child: Center(child: Icon(Iconos.layerGroup, color: ColoresApp.tinta, size: 18)),
        ),
      ),
    );
  }
}

class _OpcionCapa extends StatelessWidget {
  final CapaMapa capa;
  final bool activa;
  final VoidCallback onTap;

  const _OpcionCapa({required this.capa, required this.activa, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final icono = switch (capa) {
      CapaMapa.calles => Iconos.road,
      CapaMapa.satelite => Iconos.earthAmericas,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: activa ? ColoresApp.azulSuave : ColoresApp.fondo,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: activa ? ColoresApp.azul : ColoresApp.borde, width: activa ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icono, color: activa ? ColoresApp.azul : ColoresApp.textoSuave, size: 22),
            const SizedBox(height: 8),
            Text(
              capa.nombre,
              style: TextStyle(
                color: activa ? ColoresApp.azul : ColoresApp.texto,
                fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de botones redondos sobre el mapa (capas y ubicacion), alineada a la derecha.
///
/// Vive en la misma Column que el panel inferior (pantalla_inicio): queda justo encima de la
/// tarjeta, nunca montada sobre ella, y se mueve con el panel cuando cambia de alto. La brujula
/// no va aqui: esta en [BrujulaArriba], en la esquina superior del mapa.
class FilaBotonesMapa extends StatelessWidget {
  final ControladorMapa controlador;

  /// Botones propios de la pantalla, a la izquierda de Capas (el pasajero: ver taxistas libres).
  final List<Widget> extras;

  const FilaBotonesMapa({super.key, required this.controlador, this.extras = const []});

  @override
  Widget build(BuildContext context) {
    // Mismo ancho y margen que el panel, para que los botones queden sobre su borde derecho.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: PanelInferior.anchoMaximo),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              // El padding de abajo es la separacion con la tarjeta del panel.
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (final extra in extras) ...[extra, const SizedBox(width: 12)],
                  BotonCapas(controlador: controlador),
                  const SizedBox(width: 12),
                  BotonUbicacion(controlador: controlador),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un anillo del radar de busqueda: donde llega y con qué fuerza se ve.
class AnilloRadar {
  /// Distancia al punto de partida, en metros.
  final double radio;

  /// Fuerza con la que se ve, de 0 a 1.
  final double opacidad;

  const AnilloRadar(this.radio, this.opacidad);
}

/// Anillos del radar en una fase del ciclo, listos para pintar en el mapa.
///
/// [avance] es la fase: 0 es el arranque de la vuelta y 1 vuelve al mismo punto. Cada anillo va
/// desfasado un tercio del ciclo, asi que siempre hay uno saliendo, otro a media expansion y otro
/// desvanecerse. El radio va de [radioInicial] a [radioFinal] metros y la opacidad sube al
/// arrancar, baja mientras crece y llega a cero justo cuando el anillo desaparece, para que el
/// ciclo no se note.
List<AnilloRadar> anillosRadar(double avance) {
  const cantidad = 3;
  const radioInicial = 20.0;
  const radioFinal = 400.0;
  const opacidadMaxima = 0.45;
  const entrada = 0.1;
  final anillos = <AnilloRadar>[];
  for (var i = 0; i < cantidad; i++) {
    final fase = (avance + i / cantidad) % 1;
    final aparecer = fase < entrada ? fase / entrada : 1.0;
    anillos.add(AnilloRadar(radioInicial + (radioFinal - radioInicial) * fase, opacidadMaxima * aparecer * (1 - fase)));
  }
  return anillos;
}

/// Radar de busqueda: anillos que salen del punto de partida mientras la solicitud esta abierta y
/// no hay conductor aun. Se dibuja debajo de los pines, asi que no tapa nada.
///
/// El radio es ilustrativo: el backend no filtra por distancia, avisa a los conductores conectados,
/// asi que el radar dice "estamos buscando por aqui" y no un alcance real. La informacion de
/// cuantos mototaxistas hay cerca viene de los marcadores del mapa.
class RadarBusqueda extends StatefulWidget {
  /// Cuanto tarda en completarse una vuelta de los anillos.
  static const Duration duracionCiclo = Duration(milliseconds: 2400);

  final LatLng punto;

  const RadarBusqueda({super.key, required this.punto});

  @override
  State<RadarBusqueda> createState() => _RadarBusquedaState();
}

class _RadarBusquedaState extends State<RadarBusqueda> with SingleTickerProviderStateMixin {
  late final AnimationController _ciclo = AnimationController(vsync: this, duration: RadarBusqueda.duracionCiclo)
    ..repeat();

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ciclo,
      builder: (context, _) => CircleLayer(
        circles: [
          for (final anillo in anillosRadar(_ciclo.value))
            CircleMarker(
              point: widget.punto,
              radius: anillo.radio,
              useRadiusInMeter: true,
              color: ColoresApp.ruta.withValues(alpha: anillo.opacidad),
              borderColor: ColoresApp.rutaBorde.withValues(alpha: anillo.opacidad * 0.6),
              borderStrokeWidth: 1.5,
            ),
        ],
      ),
    );
  }
}
