import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../core/iconos.dart';
import 'package:latlong2/latlong.dart';

import '../../core/tema.dart';
import '../../widgets/modal_formulario.dart';
import 'mapa_api.dart';
import 'modelos.dart';

/// Alta y edicion de una zona. El poligono se dibuja sobre el mapa: cada clic agrega un vertice
/// y al guardar se envia como WKT.
class FormularioZona extends StatefulWidget {
  final MapaApi api;
  final Zona? zona;

  const FormularioZona({super.key, required this.api, this.zona});

  @override
  State<FormularioZona> createState() => _FormularioZonaState();
}

class _FormularioZonaState extends State<FormularioZona> {
  static const LatLng _cobija = LatLng(-11.035287, -68.759348);

  final _claveFormulario = GlobalKey<FormState>();
  final _clavePoligono = GlobalKey<FormFieldState<List<LatLng>>>();
  final _nombre = TextEditingController();
  late List<LatLng> _puntos = [...?widget.zona?.puntos];

  @override
  void initState() {
    super.initState();
    if (widget.zona != null) _nombre.text = widget.zona!.nombre;
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<Zona> _guardar() async {
    final nombre = _nombre.text.trim();
    final wkt = Zona.wktDesdePuntos(_puntos);
    final editando = widget.zona != null;
    return editando
        ? widget.api.actualizarZona(widget.zona!.idZona, nombre, wkt)
        : widget.api.crearZona(nombre, wkt);
  }

  void _alCambiarPoligono(List<LatLng> puntos) {
    setState(() => _puntos = puntos);
    _clavePoligono.currentState?.didChange(puntos);
  }

  @override
  Widget build(BuildContext context) {
    return ModalFormulario(
      titulo: widget.zona == null ? 'Nueva zona' : 'Editar zona',
      icono: Iconos.drawPolygon,
      claveFormulario: _claveFormulario,
      campos: [
        TextFormField(
          controller: _nombre,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Nombre de la zona', hintText: 'Zona Centro'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el nombre de la zona' : null,
        ),
        FormField<List<LatLng>>(
          key: _clavePoligono,
          initialValue: _puntos,
          validator: (_) => _puntos.length < 3 ? 'Dibuje el poligono en el mapa: minimo 3 vertices' : null,
          builder: (state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EditorPoligono(
                  puntos: _puntos,
                  centroInicial: _puntos.isEmpty ? _cobija : null,
                  alCambiar: _alCambiarPoligono,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.hasError ? state.errorText! : '${_puntos.length} vertices. Toca el mapa para agregar.',
                        style: TextStyle(
                          fontSize: 12,
                          color: state.hasError ? ColoresApp.rojo : ColoresApp.textoSuave,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _puntos.isEmpty ? null : () => _alCambiarPoligono(_puntos.sublist(0, _puntos.length - 1)),
                      icon: const Icon(Iconos.rotateLeft, size: 12),
                      label: const Text('Deshacer'),
                    ),
                    TextButton.icon(
                      onPressed: _puntos.isEmpty ? null : () => _alCambiarPoligono(const []),
                      icon: const Icon(Iconos.eraser, size: 12),
                      label: const Text('Limpiar'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
      alGuardar: _guardar,
    );
  }
}

/// Mapa donde se dibuja el poligono de la zona.
class _EditorPoligono extends StatefulWidget {
  final List<LatLng> puntos;
  final LatLng? centroInicial;
  final ValueChanged<List<LatLng>> alCambiar;

  const _EditorPoligono({required this.puntos, required this.centroInicial, required this.alCambiar});

  @override
  State<_EditorPoligono> createState() => _EditorPoligonoState();
}

class _EditorPoligonoState extends State<_EditorPoligono> {
  final MapController _controlador = MapController();
  bool _ajusteHecho = false;

  void _agregar(LatLng punto) {
    widget.alCambiar([...widget.puntos, punto]);
    if (_controlador.camera.zoom > 0) _controlador.move(punto, _controlador.camera.zoom);
  }

  void _alListarMapa() {
    if (_ajusteHecho || widget.puntos.isEmpty) return;
    _ajusteHecho = true;
    _controlador.fitCamera(
      CameraFit.coordinates(
        coordinates: widget.puntos,
        padding: const EdgeInsets.all(40),
        maxZoom: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final puntos = [...widget.puntos, if (widget.puntos.length >= 3) widget.puntos.first];
    return ClipRRect(
      borderRadius: BorderRadius.circular(RadiosApp.campo),
      child: SizedBox(
        // El modal de formulario se desplaza en vertical, asi que el mapa necesita alto fijo.
        height: 300,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controlador,
              options: MapOptions(
                initialCenter: widget.centroInicial ?? widget.puntos.first,
                initialZoom: widget.puntos.isEmpty ? 12 : 15,
                minZoom: 3,
                maxZoom: 18,
                onMapReady: _alListarMapa,
                onTap: (_, punto) => _agregar(punto),
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'taxiuap.admin',
                ),
                if (widget.puntos.length >= 2)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: puntos,
                        color: ColoresApp.rojo.withValues(alpha: 0.18),
                        borderColor: ColoresApp.rojo,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (final punto in widget.puntos)
                      Marker(
                        point: punto,
                        width: 18,
                        height: 18,
                        child: Container(
                          decoration: BoxDecoration(
                            color: ColoresApp.superficie,
                            shape: BoxShape.circle,
                            border: Border.all(color: ColoresApp.rojo, width: 3),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 8,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: ColoresApp.superficie.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text('OpenStreetMap', style: TextStyle(fontSize: 10, color: ColoresApp.textoSuave)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
