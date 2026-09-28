import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/tema.dart';
import '../../../mapa/servicios_mapa.dart';
import '../favoritos/favoritos_api.dart';

/// Lugar elegido en el buscador.
typedef DestinoElegido = ({LatLng posicion, String nombre});

/// Abre el buscador "¿A donde quieres ir?": sin texto muestra los favoritos; al escribir busca
/// lugares cerca de [cerca]. Devuelve el lugar elegido o null (tambien si prefiere tocar el mapa).
Future<DestinoElegido?> buscarDestino(BuildContext context, {required List<Favorito> favoritos, LatLng? cerca}) {
  return showModalBottomSheet<DestinoElegido>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: ColoresApp.fondo,
    constraints: const BoxConstraints(maxWidth: 620),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _Buscador(favoritos: favoritos, cerca: cerca),
    ),
  );
}

class _Buscador extends StatefulWidget {
  final List<Favorito> favoritos;
  final LatLng? cerca;

  const _Buscador({required this.favoritos, this.cerca});

  @override
  State<_Buscador> createState() => _BuscadorState();
}

class _BuscadorState extends State<_Buscador> {
  final _texto = TextEditingController();
  Timer? _espera;
  List<LugarEncontrado> _resultados = const [];
  bool _buscando = false;
  int _consulta = 0;

  @override
  void dispose() {
    _espera?.cancel();
    _texto.dispose();
    super.dispose();
  }

  /// Se busca cuando el usuario deja de escribir (Nominatim no admite una consulta por tecla).
  void _alEscribir(String valor) {
    _espera?.cancel();
    setState(() {});
    if (valor.trim().length < 3) {
      setState(() {
        _resultados = const [];
        _buscando = false;
      });
      return;
    }
    _espera = Timer(const Duration(milliseconds: 650), () => _buscar(valor));
  }

  Future<void> _buscar(String valor) async {
    final consulta = ++_consulta;
    setState(() => _buscando = true);
    final lista = await ServiciosMapa.buscar(valor, cerca: widget.cerca);
    if (!mounted || consulta != _consulta) return;
    setState(() {
      _resultados = lista;
      _buscando = false;
    });
  }

  void _elegir(LatLng posicion, String nombre) => Navigator.of(context).pop((posicion: posicion, nombre: nombre));

  @override
  Widget build(BuildContext context) {
    final texto = _texto.text.trim();
    final favoritos = widget.favoritos
        .where((f) => f.posicion != null)
        .where((f) => texto.isEmpty || '${f.nombre} ${f.direccion}'.toLowerCase().contains(texto.toLowerCase()))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(color: ColoresApp.borde, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '¿A dónde quieres ir?',
                  style: TextStyle(color: ColoresApp.azul, fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const FaIcon(FontAwesomeIcons.xmark, size: 18, color: ColoresApp.textoSuave),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _texto,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _alEscribir,
            onSubmitted: (v) {
              _espera?.cancel();
              if (v.trim().length >= 3) _buscar(v);
            },
            decoration: InputDecoration(
              hintText: 'Calle, barrio o lugar de Cobija',
              prefixIcon: const SizedBox(
                width: 46,
                child: Center(child: FaIcon(FontAwesomeIcons.magnifyingGlass, size: 16, color: ColoresApp.textoSuave)),
              ),
              suffixIcon: texto.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Borrar',
                      onPressed: () {
                        _texto.clear();
                        _alEscribir('');
                      },
                      icon: const FaIcon(FontAwesomeIcons.circleXmark, size: 16, color: ColoresApp.textoSuave),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _Fila(
                icono: FontAwesomeIcons.handPointer,
                color: ColoresApp.azul,
                titulo: 'Elegir en el mapa',
                detalle: 'Cierra el buscador y toca el lugar en el mapa',
                onTap: () => Navigator.of(context).pop(),
              ),
              if (favoritos.isNotEmpty) ...[
                const _Titulo('Tus favoritos'),
                for (final f in favoritos)
                  _Fila(
                    icono: f.icono,
                    color: ColoresApp.rojo,
                    titulo: f.nombre,
                    detalle: f.direccion,
                    onTap: () => _elegir(f.posicion!, f.nombre),
                  ),
              ],
              if (texto.length >= 3) ...[
                const _Titulo('Lugares'),
                if (_buscando)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator(color: ColoresApp.azul)),
                  )
                else if (_resultados.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No encontramos ese lugar. Prueba con otro nombre o márcalo en el mapa.',
                      style: TextStyle(color: ColoresApp.textoSuave),
                    ),
                  )
                else
                  for (final lugar in _resultados)
                    _Fila(
                      icono: FontAwesomeIcons.locationDot,
                      color: ColoresApp.textoSuave,
                      titulo: lugar.nombre,
                      detalle: lugar.detalle,
                      onTap: () => _elegir(lugar.posicion, lugar.nombre),
                    ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;

  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        texto,
        style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  final FaIconData icono;
  final Color color;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;

  const _Fila({required this.icono, required this.color, required this.titulo, required this.detalle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Center(child: FaIcon(icono, color: color, size: 16)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: ColoresApp.azul, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      if (detalle.isNotEmpty)
                        Text(
                          detalle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
