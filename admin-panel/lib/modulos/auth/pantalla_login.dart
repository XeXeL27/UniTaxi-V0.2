import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/sesion.dart';
import '../../core/tema.dart';

/// Inicio de sesion del administrador (correo o telefono y contrasena).
class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _claveFormulario = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _password = TextEditingController();
  bool _ocultarPassword = true;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (!(_claveFormulario.currentState?.validate() ?? false)) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      // Al autenticarse, el router redirige solo a /inicio.
      await context.read<Sesion>().iniciar(_usuario.text, _password.text);
    } on ApiExcepcion catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final movil = Pantalla.esMovil(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ColoresApp.azul, ColoresApp.azul, ColoresApp.rojo, ColoresApp.rojo],
            stops: [0, 0.5, 0.5, 1],
          ),
        ),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: EdgeInsets.symmetric(horizontal: movil ? 20 : 32, vertical: movil ? 32 : 48),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 25, offset: Offset(0, 10))],
            ),
            child: Form(
              key: _claveFormulario,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: FaIcon(FontAwesomeIcons.taxi, color: ColoresApp.rojo, size: 34)),
                  const SizedBox(height: 12),
                  const Text(
                    'Acceso al Sistema',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: ColoresApp.azul),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'TaxiUAP - Panel de administración',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 28),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF8D7DA), borderRadius: BorderRadius.circular(6)),
                      child: Text(_error!, style: const TextStyle(color: Color(0xFF842029))),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Usuario',
                    style: TextStyle(fontWeight: FontWeight.bold, color: ColoresApp.azul),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _usuario,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    decoration: const InputDecoration(
                      hintText: 'Usuario, correo o teléfono',
                      prefixIcon: Padding(padding: EdgeInsets.all(12), child: FaIcon(FontAwesomeIcons.user, size: 16)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese su usuario' : null,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Contraseña',
                    style: TextStyle(fontWeight: FontWeight.bold, color: ColoresApp.azul),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _password,
                    obscureText: _ocultarPassword,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _ingresar(),
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(12),
                        child: FaIcon(FontAwesomeIcons.lock, size: 16),
                      ),
                      suffixIcon: IconButton(
                        tooltip: _ocultarPassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                        onPressed: () => setState(() => _ocultarPassword = !_ocultarPassword),
                        icon: FaIcon(_ocultarPassword ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash, size: 16),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Ingrese su contraseña' : null,
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _cargando ? null : _ingresar,
                    icon: _cargando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const FaIcon(FontAwesomeIcons.rightToBracket, size: 16),
                    label: const Text('Iniciar Sesión', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
