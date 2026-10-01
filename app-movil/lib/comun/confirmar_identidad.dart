import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/huella.dart';
import '../core/tema.dart';

/// Todo cambio de datos se confirma con la contrasena de la cuenta. Si el ingreso con huella esta
/// activado en este telefono se pide primero la huella (se usa la contrasena guardada con ella); si
/// no se reconoce o se cancela, se pide escribir la contrasena. Devuelve null si la persona cancela.
Future<String?> confirmarIdentidad(BuildContext context, {String accion = 'guardar los cambios'}) async {
  if (await Huella.activada() && await Huella.disponible()) {
    final guardadas = await Huella.ingresar(motivo: 'Confirma con tu huella para $accion');
    if (guardadas != null) return guardadas.contrasena;
  }
  if (!context.mounted) return null;
  return pedirContrasena(context, accion: accion);
}

/// Dialogo para escribir la contrasena de la cuenta.
Future<String?> pedirContrasena(BuildContext context, {String accion = 'guardar los cambios'}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _DialogoContrasena(accion: accion),
  );
}

class _DialogoContrasena extends StatefulWidget {
  final String accion;

  const _DialogoContrasena({required this.accion});

  @override
  State<_DialogoContrasena> createState() => _DialogoContrasenaState();
}

class _DialogoContrasenaState extends State<_DialogoContrasena> {
  final _contrasena = TextEditingController();
  bool _oculta = true;
  String? _error;

  @override
  void dispose() {
    _contrasena.dispose();
    super.dispose();
  }

  void _continuar() {
    if (_contrasena.text.isEmpty) {
      setState(() => _error = 'Escribe tu contraseña');
      return;
    }
    Navigator.of(context).pop(_contrasena.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Confirma con tu contraseña', style: TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Para ${widget.accion} escribe la contraseña con la que ingresas a UNITAXI.',
            style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _contrasena,
            obscureText: _oculta,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              errorText: _error,
              suffixIcon: IconButton(
                tooltip: _oculta ? 'Mostrar' : 'Ocultar',
                onPressed: () => setState(() => _oculta = !_oculta),
                icon: FaIcon(_oculta ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash, size: 15, color: ColoresApp.textoSuave),
              ),
            ),
            onSubmitted: (_) => _continuar(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _continuar,
          style: FilledButton.styleFrom(backgroundColor: ColoresApp.azul),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
