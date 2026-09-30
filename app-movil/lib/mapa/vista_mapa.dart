import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../core/tema.dart';
import '../widgets/notificaciones.dart';
import 'controlador_mapa.dart';
import 'pin_mapa.dart';

/// Mapa a pantalla completa: tiles de OpenStreetMap, ruta azul entre A y B, tramo naranja de
/// acercamiento, punto azul del GPS y los pines A y B.
class MapaBase extends StatelessWidget {
  final ControladorMapa controlador;

  /// Toque sobre el mapa (el pasajero marca su destino).
  final void Function(LatLng punto)? onTap;

  /// Marcadores de la pantalla (por ejemplo los mototaxistas en linea), debajo de A, B y el GPS.
  final List<Marker> marcadoresExtra;

  /// Capa de marcadores que se repinta sola (los mototaxistas que se deslizan), debajo de A y B.
  final Widget? capaAnimada;

  /// Partida y destino como circulos sin letra (azul y rojo) en vez de pines con A y B.
  final bool puntosSinLetra;

  const MapaBase({
    super.key,
    required this.controlador,
    this.onTap,
    this.marcadoresExtra = const [],
    this.capaAnimada,
    this.puntosSinLetra = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controlador,
      builder: (context, _) {
        final c = controlador;
        final ruta = c.ruta;
        final acercamiento = c.mostrarAcercamiento ? c.acercamiento : null;
        final rutaConductor = c.mostrarRutaConductor ? c.rutaConductor : null;
        final a = c.a;
        final b = c.b;
        final gps = c.miUbicacion;
        final conductorPos = c.conductorUbicacion;
        final conductorRumbo = c.conductorRumbo;
        return FlutterMap(
          mapController: c.mapa,
          options: MapOptions(
            initialCenter: c.centroInicial,
            initialZoom: 15,
            minZoom: 5,
            maxZoom: 19,
            backgroundColor: const Color(0xFFE8E6E1),
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
              maxNativeZoom: c.capa == CapaMapa.satelite ? 18 : 19,
            ),
            PolylineLayer(
              polylines: [
                if (acercamiento != null)
                  Polyline(
                    points: acercamiento.puntos,
                    strokeWidth: 5,
                    color: ColoresApp.rutaSecundaria,
                    borderStrokeWidth: 1.5,
                    borderColor: ColoresApp.rutaSecundariaBorde,
                    pattern: StrokePattern.dashed(segments: const [10, 8]),
                  ),
                if (rutaConductor != null)
                  Polyline(
                    points: rutaConductor.puntos,
                    strokeWidth: 5,
                    color: ColoresApp.rutaSecundaria,
                    borderStrokeWidth: 1.5,
                    borderColor: ColoresApp.rutaSecundariaBorde,
                    pattern: StrokePattern.dashed(segments: const [10, 8]),
                  ),
                if (ruta != null) ...[
                  // La ruta arranca en la calle mas cercana: se une con cada pin por una linea punteada.
                  if (!ruta.aproximada && a != null) _tramoAPie(a.posicion, ruta.puntos.first),
                  if (!ruta.aproximada && b != null) _tramoAPie(ruta.puntos.last, b.posicion),
                  Polyline(
                    points: ruta.puntos,
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
            ?capaAnimada,
            // rotate: los pines y el GPS quedan derechos aunque se gire el mapa.
            MarkerLayer(
              rotate: true,
              markers: [
                ...marcadoresExtra,
                if (a != null) _punto(a.posicion, ColoresApp.azul, 'A'),
                if (b != null) _punto(b.posicion, ColoresApp.rojo, 'B'),
                // El GPS va encima de los pines: es lo que se mueve en vivo.
                if (gps != null) Marker(point: gps, width: 26, height: 26, child: const PuntoUbicacion()),
                // Marcador del conductor asignado al viaje del pasajero.
                if (conductorPos != null)
                  Marker(
                    point: conductorPos,
                    width: 32,
                    height: 32,
                    child: Transform.rotate(
                      angle: (conductorRumbo ?? 0) * 3.14159 / 180,
                      child: Image.asset(
                        'assets/mototaxi.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Marker _punto(LatLng posicion, Color color, String letra) => puntosSinLetra
      ? Marker(
          point: posicion,
          width: CirculoMapa.lado,
          height: CirculoMapa.lado,
          child: CirculoMapa(color: color),
        )
      : Marker(
          point: posicion,
          width: PinMapa.ancho,
          height: PinMapa.alto,
          alignment: Alignment.topCenter,
          child: PinMapa(color: color, letra: letra),
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
      shadowColor: const Color(0x55000000),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _ubicar(context),
        child: const SizedBox(
          width: 50,
          height: 50,
          child: Center(child: FaIcon(FontAwesomeIcons.locationCrosshairs, color: ColoresApp.azul, size: 20)),
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
            shadowColor: const Color(0x55000000),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: girado ? controlador.orientarAlNorte : null,
              child: SizedBox(
                width: 50,
                height: 50,
                child: Center(
                  child: Transform.rotate(
                    angle: grados * 3.141592653589793 / 180,
                    child: const _Aguja(),
                  ),
                ),
              ),
            ),
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
          Expanded(child: CustomPaint(size: Size(14, 15), painter: _Triangulo(ColoresApp.rojo, arriba: true))),
          Expanded(child: CustomPaint(size: Size(14, 15), painter: _Triangulo(ColoresApp.textoSuave, arriba: false))),
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
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Tipo de mapa', style: TextStyle(color: ColoresApp.azul, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final capa in CapaMapa.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
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
      shadowColor: const Color(0x55000000),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _elegir(context),
        child: const SizedBox(
          width: 50,
          height: 50,
          child: Center(child: FaIcon(FontAwesomeIcons.layerGroup, color: ColoresApp.azul, size: 19)),
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
      CapaMapa.calles => FontAwesomeIcons.road,
      CapaMapa.satelite => FontAwesomeIcons.earthAmericas,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: activa ? ColoresApp.azulSuave : ColoresApp.fondo,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: activa ? ColoresApp.azul : ColoresApp.borde, width: activa ? 2 : 1),
        ),
        child: Column(
          children: [
            FaIcon(icono, color: activa ? ColoresApp.azul : ColoresApp.textoSuave, size: 22),
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

/// Fila de botones redondos sobre el mapa: capas a la izquierda, brujula y ubicacion a la derecha.
///
/// Va anclada al borde inferior de la pantalla, en su propio Positioned y por encima del panel, para
/// que no se mueva cuando el panel de abajo cambia de alto; el panel deja libre [alto] con
/// PanelInferior.reservaInferior.
class FilaBotonesMapa extends StatelessWidget {
  final ControladorMapa controlador;

  /// Alto de la fila: boton de 50 + separacion de 12.
  static const double alto = 62;

  const FilaBotonesMapa({super.key, required this.controlador});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          BotonCapas(controlador: controlador),
          const Spacer(),
          BotonBrujula(controlador: controlador),
          const SizedBox(width: 10),
          BotonUbicacion(controlador: controlador),
        ],
      ),
    );
  }
}
