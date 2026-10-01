import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../core/api_excepcion.dart';
import '../core/cliente_api.dart';
import '../core/credenciales.dart';
import '../core/huella.dart';
import '../core/tema.dart';
import '../widgets/boton_principal.dart';
import '../widgets/dialogos.dart';
import 'cuenta_api.dart';

/// Ancho desde el que el formulario se abre como modal en lugar de pantalla completa.
const double _anchoModal = 600;

/// Abre el cambio de contrasena: en el celular ocupa toda la pantalla; en una pantalla ancha
/// (navegador de PC) es un modal centrado. Al terminar muestra el modal verde.
Future<void> abrirCambiarContrasena(BuildContext context) async {
  final cambiada = MediaQuery.sizeOf(context).width >= _anchoModal
      ? await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => Dialog(
            insetPadding: const EdgeInsets.all(24),
            backgroundColor: ColoresApp.blanco,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: const SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(26, 22, 26, 24),
                child: _FormularioContrasena(enModal: true),
              ),
            ),
          ),
        )
      : await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => Scaffold(
              backgroundColor: ColoresApp.fondo,
              appBar: AppBar(
                backgroundColor: ColoresApp.azul,
                foregroundColor: ColoresApp.blanco,
                title: const Text('Cambiar contraseña', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              body: const SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: _FormularioContrasena(enModal: false),
                ),
              ),
            ),
          ),
        );
  if (cambiada == true && context.mounted) {
    await mostrarExito(
      context,
      titulo: 'Contraseña actualizada',
      mensaje: 'Desde ahora ingresa a UNITAXI con tu nueva contraseña.',
    );
  }
}

class _FormularioContrasena extends StatefulWidget {
  final bool enModal;

  const _FormularioContrasena({required this.enModal});

  @override
  State<_FormularioContrasena> createState() => _FormularioContrasenaState();
}

class _FormularioContrasenaState extends State<_FormularioContrasena> {
  final _clave = GlobalKey<FormState>();
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmacion = TextEditingController();
  final _ocultos = [true, true, true];
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!(_clave.currentState?.validate() ?? false)) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await CuentaApi(context.read<ClienteApi>()).cambiarContrasena(
        actual: _actual.text,
        nueva: _nueva.text,
        confirmacion: _confirmacion.text,
      );
      // Lo recordado en el telefono (login y huella) pasa a la contrasena nueva.
      final recordadas = await Credenciales.leer();
      if (recordadas != null) await Credenciales.guardar(recordadas.usuario, _nueva.text);
      await Huella.actualizarContrasena(_nueva.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _clave,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: const Color(0xFFF39C12).withValues(alpha: 0.14), shape: BoxShape.circle),
                child: const Center(child: FaIcon(FontAwesomeIcons.lock, color: Color(0xFFE67E22), size: 19)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.enModal)
                      const Text(
                        'Cambiar contraseña',
                        style: TextStyle(color: ColoresApp.azul, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    Text(
                      'Escribe tu contraseña actual y luego la nueva dos veces.',
                      style: TextStyle(color: ColoresApp.textoSuave, fontSize: widget.enModal ? 13.5 : 14.5),
                    ),
                  ],
                ),
              ),
              if (widget.enModal)
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
                  icon: const FaIcon(FontAwesomeIcons.xmark, size: 18, color: ColoresApp.textoSuave),
                ),
            ],
          ),
          const SizedBox(height: 22),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: ColoresApp.rojoSuave, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const FaIcon(FontAwesomeIcons.circleExclamation, color: ColoresApp.rojo, size: 16),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!, style: const TextStyle(color: ColoresApp.rojoOscuro))),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _campo(0, _actual, 'Contraseña actual', (v) => (v == null || v.isEmpty) ? 'Escribe tu contraseña actual' : null),
          const SizedBox(height: 14),
          _campo(1, _nueva, 'Nueva contraseña', (v) {
            if (v == null || v.isEmpty) return 'Escribe la nueva contraseña';
            if (v.length < 8) return 'Debe tener al menos 8 caracteres';
            if (v.length > 72) return 'Debe tener como máximo 72 caracteres';
            if (v == _actual.text) return 'Debe ser distinta de la actual';
            return null;
          }),
          const SizedBox(height: 14),
          _campo(2, _confirmacion, 'Confirmar nueva contraseña', (v) {
            if (v == null || v.isEmpty) return 'Vuelve a escribir la nueva contraseña';
            if (v != _nueva.text) return 'No coincide con la nueva contraseña';
            return null;
          }, ultimo: true),
          const SizedBox(height: 10),
          const Row(
            children: [
              FaIcon(FontAwesomeIcons.circleInfo, size: 13, color: ColoresApp.textoSuave),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mínimo 8 caracteres. Si tienes cuenta de pasajero y de conductor, cambia en las dos.',
                  style: TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          BotonPrincipal(texto: 'Guardar contraseña', cargando: _enviando, onPressed: _guardar),
          if (widget.enModal) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancelar', style: TextStyle(color: ColoresApp.textoSuave)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _campo(
    int indice,
    TextEditingController controlador,
    String etiqueta,
    String? Function(String?) validar, {
    bool ultimo = false,
  }) {
    return TextFormField(
      controller: controlador,
      obscureText: _ocultos[indice],
      textInputAction: ultimo ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: ultimo ? (_) => _guardar() : null,
      autofillHints: [indice == 0 ? AutofillHints.password : AutofillHints.newPassword],
      decoration: InputDecoration(
        labelText: etiqueta,
        prefixIcon: const SizedBox(
          width: 44,
          child: Center(child: FaIcon(FontAwesomeIcons.key, size: 15, color: ColoresApp.textoSuave)),
        ),
        suffixIcon: IconButton(
          tooltip: _ocultos[indice] ? 'Mostrar' : 'Ocultar',
          onPressed: () => setState(() => _ocultos[indice] = !_ocultos[indice]),
          icon: FaIcon(
            _ocultos[indice] ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash,
            size: 16,
            color: ColoresApp.textoSuave,
          ),
        ),
      ),
      validator: validar,
    );
  }
}
