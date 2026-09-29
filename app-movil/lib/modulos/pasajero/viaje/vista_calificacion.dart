import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/api_excepcion.dart';
import '../../../core/formato.dart';
import '../../../core/tema.dart';
import '../../../widgets/boton_principal.dart';
import '../../../widgets/dialogos.dart';
import '../../../widgets/paneles.dart';
import '../../../comun/modelos_viaje.dart';
import 'flujo_pasajero.dart';

/// Cuadro pequeno al terminar el viaje: estrellas y un comentario corto para el conductor. Es la
/// unica oportunidad de calificar ese viaje: una vez enviada (u omitida) no se puede cambiar.
Future<void> mostrarCalificacion(BuildContext context, FlujoPasajero flujo) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CuadroCalificacion(flujo: flujo),
  );
}

class _CuadroCalificacion extends StatefulWidget {
  final FlujoPasajero flujo;

  const _CuadroCalificacion({required this.flujo});

  @override
  State<_CuadroCalificacion> createState() => _CuadroCalificacionState();
}

class _CuadroCalificacionState extends State<_CuadroCalificacion> {
  static const _textosNota = ['', 'Muy malo', 'Malo', 'Regular', 'Bueno', 'Excelente'];

  final _comentario = TextEditingController();
  int _nota = 0;
  bool _enviando = false;

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    try {
      await widget.flujo.calificar(
        puntuacion: _nota,
        comentario: _comentario.text.trim().isEmpty ? null : _comentario.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.flujo.terminarCalificacion();
      await mostrarExito(context, titulo: '¡Gracias!', mensaje: 'Tu calificación ayuda a mejorar el servicio.');
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _omitir() {
    Navigator.of(context).pop();
    widget.flujo.omitirCalificacion();
  }

  @override
  Widget build(BuildContext context) {
    final viaje = widget.flujo.viaje;
    if (viaje == null) return const SizedBox.shrink();
    return Dialog(
      backgroundColor: ColoresApp.blanco,
      surfaceTintColor: ColoresApp.blanco,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AvatarIniciales(nombre: viaje.nombreConductor, radio: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¿Cómo fue tu viaje con ${viaje.primerNombreConductor}?',
                          style: const TextStyle(color: ColoresApp.azul, fontSize: 16.5, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Llegaste a tu destino. ${MetodoPago.frase('Pagas ${formatoBs(viaje.precioFinal)}', viaje.metodoPago)}.',
                          style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: _enviando ? null : () => setState(() => _nota = i),
                      tooltip: '$i ${i == 1 ? 'estrella' : 'estrellas'}',
                      visualDensity: VisualDensity.compact,
                      icon: FaIcon(
                        i <= _nota ? FontAwesomeIcons.solidStar : FontAwesomeIcons.star,
                        color: i <= _nota ? const Color(0xFFF5A623) : ColoresApp.borde,
                        size: 30,
                      ),
                    ),
                ],
              ),
              SizedBox(
                height: 20,
                child: Text(
                  _textosNota[_nota],
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ColoresApp.texto, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _comentario,
                maxLines: 2,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Deja un comentario (opcional)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 4),
              BotonPrincipal(texto: 'Enviar', cargando: _enviando, onPressed: _nota == 0 ? null : _enviar),
              TextButton(
                onPressed: _enviando ? null : _omitir,
                style: TextButton.styleFrom(foregroundColor: ColoresApp.textoSuave),
                child: const Text('Omitir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
