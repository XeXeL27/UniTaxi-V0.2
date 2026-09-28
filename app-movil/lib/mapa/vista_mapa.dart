import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../core/tema.dart';
import '../widgets/notificaciones.dart';
import 'controlador_mapa.dart';
import 'pin_mapa.dart';

/// Mapa a pantalla completa: tiles de OpenStreetMap, ruta azul entre A y B, tramo gris de
/// acercamiento, punto azul del GPS y los pines A y B.
class MapaBase extends StatelessWidget {
  final ControladorMapa controlador;

  /// Toque sobre el mapa (el pasajero marca su destino).
  final void Function(LatLng punto)? onTap;

  /// Marcadores de la pantalla (por ejemplo los mototaxistas en linea), debajo de A, B y el GPS.
  final List<Marker> marcadoresExtra;

  const MapaBase({super.key, required this.controlador, this.onTap, this.marcadoresExtra = const []});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controlador,
      builder: (context, _) {
        final c = controlador;
        final ruta = c.ruta;
        final acercamiento = c.mostrarAcercamiento ? c.acercamiento : null;
        final a = c.a;
        final b = c.b;
        final gps = c.miUbicacion;
        return FlutterMap(
          mapController: c.mapa,
          options: MapOptions(
            initialCenter: c.centroInicial,
            initialZoom: 15,
            minZoom: 5,
            maxZoom: 19,
            backgroundColor: const Color(0xFFE8E6E1),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onMapReady: c.alListarMapa,
            onTap: onTap == null ? null : (_, punto) => onTap!(punto),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: Config.agenteMapas,
            ),
            PolylineLayer(
              polylines: [
                if (acercamiento != null)
                  Polyline(
                    points: acercamiento.puntos,
                    strokeWidth: 5,
                    color: ColoresApp.textoSuave,
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
            MarkerLayer(
              markers: [
                ...marcadoresExtra,
                if (a != null)
                  Marker(
                    point: a.posicion,
                    width: PinMapa.ancho,
                    height: PinMapa.alto,
                    alignment: Alignment.topCenter,
                    child: const PinMapa(color: ColoresApp.azul, letra: 'A'),
                  ),
                if (b != null)
                  Marker(
                    point: b.posicion,
                    width: PinMapa.ancho,
                    height: PinMapa.alto,
                    alignment: Alignment.topCenter,
                    child: const PinMapa(color: ColoresApp.rojo, letra: 'B'),
                  ),
                // El GPS va encima de los pines: es lo que se mueve en vivo.
                if (gps != null) Marker(point: gps, width: 26, height: 26, child: const PuntoUbicacion()),
              ],
            ),
          ],
        );
      },
    );
  }

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
