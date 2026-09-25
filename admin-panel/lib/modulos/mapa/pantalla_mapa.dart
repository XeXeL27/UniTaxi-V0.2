import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/tema.dart';
import 'mapa_api.dart';
import 'modelos.dart';

/// Mapa de zonas de servicio: poligonos de /api/admin/zonas sobre OpenStreetMap.
class PantallaMapa extends StatefulWidget {
  const PantallaMapa({super.key});

  @override
  State<PantallaMapa> createState() => _PantallaMapaState();
}

class _PantallaMapaState extends State<PantallaMapa> {
  final MapController _controlador = MapController();
  late final MapaApi _api;

  List<Zona> _zonas = const [];
  bool _cargando = true;
  bool _mapaListo = false;
  bool _encuadrePendiente = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = MapaApi(context.read<ClienteApi>());
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final zonas = await _api.listarZonas();
      if (!mounted) return;
      setState(() {
        _zonas = zonas;
        _cargando = false;
      });
      _encuadrar();
    } on ApiExcepcion catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }

  void _encuadrar() {
    final puntos = _zonas.expand((z) => z.puntos).toList();
    if (puntos.isEmpty) return;
    if (!_mapaListo) {
      _encuadrePendiente = true;
      return;
    }
    _controlador.fitCamera(
      CameraFit.coordinates(coordinates: puntos, padding: const EdgeInsets.fromLTRB(48, 48, 48, 72), maxZoom: 16),
    );
  }

  void _alListarMapa() {
    setState(() => _mapaListo = true);
    if (_encuadrePendiente) {
      _encuadrePendiente = false;
      _encuadrar();
    }
  }

  @override
  Widget build(BuildContext context) {
    // El contenido del panel va dentro de un SingleChildScrollView (altura infinita), asi que el
    // mapa necesita una altura fija: se calcula con la de la pantalla menos barra y rellenos.
    final alto = (MediaQuery.sizeOf(context).height - 200).clamp(380.0, 860.0);
    return SizedBox(
      height: alto,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _mapa()),
          _barraZonas(),
        ],
      ),
    );
  }

  Widget _mapa() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: ColoresApp.rojo));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FaIcon(FontAwesomeIcons.triangleExclamation, color: ColoresApp.rojo, size: 28),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: ColoresApp.texto)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _cargar,
                icon: const FaIcon(FontAwesomeIcons.rotateRight, size: 16),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    final conPoligonos = _zonas.where((z) => z.tienePoligono).toList();
    return Stack(
      children: [
        FlutterMap(
          mapController: _controlador,
          options: MapOptions(
            initialCenter: const LatLng(-11.035287, -68.759348),
            initialZoom: 12,
            minZoom: 3,
            maxZoom: 18,
            backgroundColor: ColoresApp.azulNeblina,
            onMapReady: _alListarMapa,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'taxiuap.admin',
            ),
            PolygonLayer(
              polygons: [
                for (final zona in conPoligonos)
                  Polygon(
                    points: zona.puntos,
                    color: ColoresApp.rojo.withValues(alpha: 0.18),
                    borderColor: ColoresApp.rojo,
                    borderStrokeWidth: 2.5,
                  ),
              ],
            ),
            MarkerLayer(
              markers: [for (final zona in conPoligonos) _marcadorZona(zona)],
            ),
          ],
        ),
        if (_zonas.isEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(child: _pastilla('No hay zonas de servicio registradas')),
          ),
        const Positioned(right: 8, bottom: 6, child: _Credito()),
      ],
    );
  }

  Marker _marcadorZona(Zona zona) {
    return Marker(
      point: _centro(zona.puntos),
      width: 150,
      height: 44,
      alignment: Alignment.center,
      child: _pastilla(zona.nombre),
    );
  }

  LatLng _centro(List<LatLng> puntos) {
    final sumaLat = puntos.fold<double>(0, (total, p) => total + p.latitude);
    final sumaLon = puntos.fold<double>(0, (total, p) => total + p.longitude);
    return LatLng(sumaLat / puntos.length, sumaLon / puntos.length);
  }

  Widget _pastilla(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: ColoresApp.superficie,
        borderRadius: BorderRadius.circular(RadiosApp.campo),
        border: Border.all(color: ColoresApp.borde),
        boxShadow: [
          BoxShadow(color: ColoresApp.azul.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FaIcon(FontAwesomeIcons.locationDot, color: ColoresApp.rojo, size: 13),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColoresApp.azul),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraZonas() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: ColoresApp.superficie,
        border: Border(top: BorderSide(color: ColoresApp.borde)),
      ),
      child: Wrap(
        spacing: 22,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FaIcon(FontAwesomeIcons.mapLocationDot, color: ColoresApp.azul, size: 16),
              const SizedBox(width: 8),
              Text(
                'Zonas de servicio',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _cargando ? ColoresApp.textoSuave : ColoresApp.azul,
                ),
              ),
            ],
          ),
          for (final zona in _zonas)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: ColoresApp.rojo, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 7),
                Text(zona.nombre, style: const TextStyle(fontSize: 13, color: ColoresApp.texto)),
              ],
            ),
        ],
      ),
    );
  }
}

/// Credito obligatorio de OpenStreetMap.
class _Credito extends StatelessWidget {
  const _Credito();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: ColoresApp.superficie.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(5)),
      child: const Text(
        'OpenStreetMap',
        style: TextStyle(fontSize: 10, color: ColoresApp.textoSuave),
      ),
    );
  }
}
