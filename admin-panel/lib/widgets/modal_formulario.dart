import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/api_excepcion.dart';
import '../core/tema.dart';

/// Estructura comun de los formularios en modal: cabecera, campos con scroll, errores del
/// backend y botones Cancelar / Guardar. En celular ocupa toda la pantalla.
///
/// [alGuardar] se ejecuta solo si el formulario es valido; si termina sin error el modal se
/// cierra devolviendo su resultado (o true si no devuelve nada).
class ModalFormulario extends StatefulWidget {
  final String titulo;
  final FaIconData icono;
  final GlobalKey<FormState> claveFormulario;
  final List<Widget> campos;
  final Future<Object?> Function() alGuardar;
  final String textoGuardar;

  const ModalFormulario({
    super.key,
    required this.titulo,
    required this.icono,
    required this.claveFormulario,
    required this.campos,
    required this.alGuardar,
    this.textoGuardar = 'Guardar',
  });

  @override
  State<ModalFormulario> createState() => _ModalFormularioState();
}

class _ModalFormularioState extends State<ModalFormulario> {
  bool _guardando = false;
  String? _error;
  Map<String, String> _erroresCampos = const {};

  Future<void> _guardar() async {
    if (!(widget.claveFormulario.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
      _erroresCampos = const {};
    });
    try {
      final resultado = await widget.alGuardar();
      if (mounted) Navigator.of(context).pop(resultado ?? true);
    } on ApiExcepcion catch (e) {
      setState(() {
        _error = e.mensaje;
        _erroresCampos = e.errores;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final movil = Pantalla.esMovil(context);
    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: ColoresApp.rojo, width: 3)),
          ),
          child: Row(
            children: [
              FaIcon(widget.icono, color: ColoresApp.azul, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.titulo,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ColoresApp.azul),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
                icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: widget.claveFormulario,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) _alertaError(),
                  for (final campo in widget.campos) Padding(padding: const EdgeInsets.only(bottom: 14), child: campo),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: ColoresApp.borde)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const FaIcon(FontAwesomeIcons.floppyDisk, size: 14),
                label: Text(widget.textoGuardar),
              ),
            ],
          ),
        ),
      ],
    );

    if (movil) {
      return Dialog.fullscreen(
        backgroundColor: Colors.white,
        child: SafeArea(child: contenido),
      );
    }
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: contenido),
    );
  }

  Widget _alertaError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8D7DA), borderRadius: BorderRadius.circular(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _error!,
            style: const TextStyle(color: Color(0xFF842029), fontWeight: FontWeight.w600),
          ),
          for (final e in _erroresCampos.entries)
            Text('${e.key}: ${e.value}', style: const TextStyle(color: Color(0xFF842029))),
        ],
      ),
    );
  }
}

/// Abre un formulario en modal. Devuelve el resultado del guardado, o null si se cancelo.
Future<Object?> abrirModal(BuildContext context, Widget formulario) async {
  final resultado = await showDialog<Object?>(context: context, barrierDismissible: false, builder: (_) => formulario);
  return resultado == false ? null : resultado;
}
