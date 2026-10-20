import 'package:flutter/material.dart';

import '../core/api_excepcion.dart';
import '../core/iconos.dart';
import '../core/relieve.dart';
import 'boton_relieve.dart';
import 'ventana.dart';
import 'dialogo_animado.dart';

/// Estructura comun de los formularios en modal: cabecera, campos con scroll, errores del
/// backend y botones Cancelar / Guardar. En celular ocupa toda la pantalla.
///
/// [alGuardar] se ejecuta solo si el formulario es valido; si termina sin error el modal se
/// cierra devolviendo su resultado (o true si no devuelve nada).
class ModalFormulario extends StatefulWidget {
  final String titulo;
  final IconData icono;
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
    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CabeceraVentana(
          icono: widget.icono,
          titulo: widget.titulo,
          alCerrar: _guardando ? null : () => Navigator.of(context).pop(false),
        ),
        Flexible(
          child: ColoredBox(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: widget.claveFormulario,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) _alertaError(),
                    for (final campo in widget.campos)
                      Padding(padding: const EdgeInsets.only(bottom: 14), child: campo),
                  ],
                ),
              ),
            ),
          ),
        ),
        PieVentana(
          children: [
            BotonRelieve(texto: 'Cancelar', alPresionar: _guardando ? null : () => Navigator.of(context).pop(false)),
            BotonRelieve(
              texto: widget.textoGuardar,
              icono: Iconos.floppyDisk,
              tono: TonoBoton.verde,
              cargando: _guardando,
              alPresionar: _guardar,
            ),
          ],
        ),
      ],
    );
    return MarcoVentana(child: contenido);
  }

  Widget _alertaError() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AlertaRelieve.error(
        titulo: _error!,
        texto: _erroresCampos.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
      ),
    );
  }
}

/// Abre un formulario en modal. Devuelve el resultado del guardado, o null si se cancelo.
Future<Object?> abrirModal(BuildContext context, Widget formulario) async {
  final resultado = await mostrarDialogo<Object?>(
    context: context,
    barrierDismissible: false,
    builder: (_) => formulario,
  );
  return resultado == false ? null : resultado;
}
