import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/api_excepcion.dart';
import '../../core/tema.dart';
import '../../mapa/controlador_mapa.dart';
import '../../widgets/boton_principal.dart';
import 'favoritos_api.dart';

/// Hoja inferior para ponerle nombre al lugar elegido en el mapa y guardarlo como favorito.
/// Devuelve el favorito creado, o null si se cancelo.
Future<Favorito?> abrirFormularioLugar(BuildContext context, FavoritosApi api, PuntoRuta lugar) {
  return showModalBottomSheet<Favorito>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ColoresApp.blanco,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _FormularioLugar(api: api, lugar: lugar),
  );
}

class _FormularioLugar extends StatefulWidget {
  final FavoritosApi api;
  final PuntoRuta lugar;

  const _FormularioLugar({required this.api, required this.lugar});

  @override
  State<_FormularioLugar> createState() => _FormularioLugarState();
}

class _FormularioLugarState extends State<_FormularioLugar> {
  static const _sugerencias = ['Casa', 'Trabajo', 'Universidad', 'Terminal'];

  final _claveFormulario = GlobalKey<FormState>();
  late final TextEditingController _nombre = TextEditingController();
  late final TextEditingController _direccion = TextEditingController(text: widget.lugar.texto);
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _direccion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_claveFormulario.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final favorito = await widget.api.crear(
        nombre: _nombre.text,
        direccion: _direccion.text,
        posicion: widget.lugar.posicion,
      );
      if (mounted) Navigator.of(context).pop(favorito);
    } on ApiExcepcion catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + teclado),
      child: Form(
        key: _claveFormulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: ColoresApp.borde, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                FaIcon(FontAwesomeIcons.solidStar, color: ColoresApp.rojo, size: 18),
                SizedBox(width: 10),
                Text(
                  'Guardar lugar favorito',
                  style: TextStyle(color: ColoresApp.azul, fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sugerencia in _sugerencias)
                  ChoiceChip(
                    label: Text(sugerencia),
                    selected: _nombre.text == sugerencia,
                    selectedColor: ColoresApp.azulSuave,
                    side: const BorderSide(color: ColoresApp.borde),
                    onSelected: (_) => setState(() => _nombre.text = sugerencia),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Casa, Trabajo'),
              onChanged: (_) => setState(() {}),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese un nombre' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _direccion,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Dirección o referencia'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese la dirección' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: ColoresApp.rojo)),
            ],
            const SizedBox(height: 18),
            BotonPrincipal(texto: 'Guardar lugar', cargando: _guardando, onPressed: _guardar),
          ],
        ),
      ),
    );
  }
}
