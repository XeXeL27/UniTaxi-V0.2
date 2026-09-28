import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/api_excepcion.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../widgets/boton_principal.dart';
import '../../widgets/dialogos.dart';
import '../../widgets/paneles.dart';
import 'flujo_pasajero.dart';
import 'viaje_api.dart';

/// Pantalla completa al terminar el viaje (estilo Uber): estrellas, etiquetas segun la nota y un
/// comentario opcional para el conductor.
class VistaCalificacion extends StatefulWidget {
  final FlujoPasajero flujo;

  const VistaCalificacion({super.key, required this.flujo});

  @override
  State<VistaCalificacion> createState() => _VistaCalificacionState();
}

class _VistaCalificacionState extends State<VistaCalificacion> {
  static const _textosNota = ['', 'Muy malo', 'Malo', 'Regular', 'Bueno', 'Excelente'];

  final _comentario = TextEditingController();
  final Set<int> _elegidas = {};
  List<Etiqueta> _etiquetas = const [];
  int _nota = 0;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cargarEtiquetas();
  }

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _cargarEtiquetas() async {
    try {
      final lista = await widget.flujo.api.etiquetasConductor();
      if (mounted) setState(() => _etiquetas = lista);
    } catch (_) {
      // Sin etiquetas se puede calificar igual con estrellas y comentario.
    }
  }

  /// Con 4 o 5 estrellas se ofrecen las etiquetas positivas; con menos, las de mejora.
  List<Etiqueta> get _etiquetasVisibles =>
      _etiquetas.where((e) => _nota >= 4 ? e.positiva : !e.positiva).toList();

  void _elegirNota(int nota) {
    setState(() {
      final cambioDeGrupo = (_nota >= 4) != (nota >= 4);
      _nota = nota;
      if (cambioDeGrupo) _elegidas.clear();
    });
  }

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    try {
      await widget.flujo.calificar(
        puntuacion: _nota,
        comentario: _comentario.text.trim().isEmpty ? null : _comentario.text.trim(),
        etiquetas: _elegidas.toList(),
      );
      if (!mounted) return;
      await mostrarExito(context, titulo: '¡Gracias!', mensaje: 'Tu calificación ayuda a mejorar el servicio.');
      widget.flujo.terminarCalificacion();
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viaje = widget.flujo.viaje;
    final arriba = MediaQuery.paddingOf(context).top;
    final abajo = MediaQuery.paddingOf(context).bottom;
    if (viaje == null) return const SizedBox.shrink();
    return Material(
      color: ColoresApp.fondo,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, arriba + 28, 24, 28),
            decoration: const BoxDecoration(
              color: ColoresApp.azul,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const FaIcon(FontAwesomeIcons.flagCheckered, color: ColoresApp.blanco, size: 26),
                const SizedBox(height: 10),
                const Text(
                  'Llegaste a tu destino',
                  style: TextStyle(color: ColoresApp.blanco, fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pagas ${formatoBs(viaje.precioFinal)} en efectivo',
                  style: TextStyle(color: ColoresApp.blanco.withValues(alpha: 0.85), fontSize: 15),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + abajo),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: AvatarIniciales(nombre: viaje.nombreConductor, radio: 36)),
                  const SizedBox(height: 12),
                  Text(
                    '¿Cómo fue tu viaje con ${viaje.primerNombreConductor}?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: ColoresApp.azul, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  if (viaje.vehiculo.isNotEmpty || viaje.placa != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      [viaje.vehiculo, if (viaje.placa != null) viaje.placa!].where((t) => t.isNotEmpty).join(', '),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13.5),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 1; i <= 5; i++)
                        IconButton(
                          onPressed: _enviando ? null : () => _elegirNota(i),
                          tooltip: '$i ${i == 1 ? 'estrella' : 'estrellas'}',
                          iconSize: 38,
                          icon: FaIcon(
                            i <= _nota ? FontAwesomeIcons.solidStar : FontAwesomeIcons.star,
                            color: i <= _nota ? const Color(0xFFF5A623) : ColoresApp.borde,
                            size: 38,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(
                    height: 24,
                    child: Text(
                      _textosNota[_nota],
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ColoresApp.texto, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_nota > 0 && _etiquetasVisibles.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      _nota >= 4 ? '¿Qué te gustó?' : '¿Qué se puede mejorar?',
                      style: const TextStyle(color: ColoresApp.azul, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final etiqueta in _etiquetasVisibles)
                          FilterChip(
                            label: Text(etiqueta.nombre),
                            selected: _elegidas.contains(etiqueta.id),
                            showCheckmark: false,
                            selectedColor: _nota >= 4 ? ColoresApp.azulSuave : ColoresApp.rojoSuave,
                            side: BorderSide(
                              color: _elegidas.contains(etiqueta.id)
                                  ? (_nota >= 4 ? ColoresApp.azul : ColoresApp.rojo)
                                  : ColoresApp.borde,
                            ),
                            backgroundColor: ColoresApp.blanco,
                            onSelected: (valor) => setState(() {
                              if (valor) {
                                _elegidas.add(etiqueta.id);
                              } else {
                                _elegidas.remove(etiqueta.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  TextField(
                    controller: _comentario,
                    maxLines: 3,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Deja un comentario para el conductor (opcional)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  BotonPrincipal(
                    texto: 'Enviar calificación',
                    cargando: _enviando,
                    onPressed: _nota == 0 ? null : _enviar,
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _enviando ? null : widget.flujo.terminarCalificacion,
                    style: TextButton.styleFrom(foregroundColor: ColoresApp.textoSuave),
                    child: const Text('Omitir'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
