import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../core/api_excepcion.dart';
import '../core/sesion.dart';
import '../core/tema.dart';
import '../widgets/boton_principal.dart';

/// Quien entra a la app sin correo registrado (cuentas creadas por la administracion sin correo)
/// tiene que darlo antes de seguir: por ahi le llegan sus credenciales y el codigo para restablecer
/// la contrasena.
class PantallaCompletarCorreo extends StatefulWidget {
  const PantallaCompletarCorreo({super.key});

  @override
  State<PantallaCompletarCorreo> createState() => _PantallaCompletarCorreoState();
}

class _PantallaCompletarCorreoState extends State<PantallaCompletarCorreo> {
  final _clave = GlobalKey<FormState>();
  final _correo = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
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
      // Al guardarlo la sesion cambia y la app pasa sola a la vista del pasajero o del conductor.
      await context.read<Sesion>().guardarCorreo(_correo.text);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = context.select<Sesion, String>((s) => s.usuario?.primerNombre ?? '');
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _clave,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(color: ColoresApp.azulSuave, shape: BoxShape.circle),
                        child: const Center(child: FaIcon(FontAwesomeIcons.envelope, color: ColoresApp.azul, size: 36)),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      nombre.isEmpty ? 'Registra tu correo' : 'Hola, $nombre',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ColoresApp.azul, fontSize: 23, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tu cuenta no tiene un correo. Escríbelo para continuar: ahí te llegarán tus datos de '
                      'ingreso y el código si alguna vez olvidas tu contraseña.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ColoresApp.textoSuave, fontSize: 14.5, height: 1.45),
                    ),
                    const SizedBox(height: 24),
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
                    TextFormField(
                      controller: _correo,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _guardar(),
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: SizedBox(
                          width: 44,
                          child: Center(child: FaIcon(FontAwesomeIcons.at, size: 15, color: ColoresApp.textoSuave)),
                        ),
                      ),
                      validator: (v) => v != null && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())
                          ? null
                          : 'Escribe un correo válido',
                    ),
                    const SizedBox(height: 22),
                    BotonPrincipal(texto: 'Guardar y continuar', cargando: _enviando, onPressed: _guardar),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _enviando ? null : () => context.read<Sesion>().cerrar(),
                      child: const Text('Cerrar sesión', style: TextStyle(color: ColoresApp.textoSuave)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
