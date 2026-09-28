import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/config.dart';
import '../../core/sesion.dart';
import '../../core/tema.dart';
import '../../widgets/boton_principal.dart';

/// Inicio de sesion con usuario, correo o telefono y contrasena.
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
    FocusScope.of(context).unfocus();
    if (!(_claveFormulario.currentState?.validate() ?? false)) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      // Al autenticarse, main muestra sola la pantalla de inicio.
      await context.read<Sesion>().iniciar(_usuario.text, _password.text);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: ColoresApp.azul,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24, arriba + 48, 24, 36),
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ColoresApp.rojo,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const FaIcon(FontAwesomeIcons.taxi, color: ColoresApp.blanco, size: 34),
                ),
                const SizedBox(height: 18),
                const Text(
                  'TaxiUAP',
                  style: TextStyle(color: ColoresApp.blanco, fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'App del ${Config.nombreRol.toLowerCase()}',
                  style: TextStyle(color: ColoresApp.blanco.withValues(alpha: 0.8), fontSize: 15),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: ColoresApp.fondo,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Form(
                  key: _claveFormulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Iniciar sesión',
                        style: TextStyle(color: ColoresApp.azul, fontSize: 22, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ingresa con tu usuario, correo o teléfono',
                        style: TextStyle(color: ColoresApp.textoSuave, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _usuario,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Usuario, correo o teléfono',
                          prefixIcon: _IconoCampo(FontAwesomeIcons.solidUser),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese su usuario' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _ocultarPassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _ingresar(),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const _IconoCampo(FontAwesomeIcons.lock),
                          suffixIcon: IconButton(
                            tooltip: _ocultarPassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                            onPressed: () => setState(() => _ocultarPassword = !_ocultarPassword),
                            icon: FaIcon(
                              _ocultarPassword ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash,
                              size: 16,
                              color: ColoresApp.textoSuave,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Ingrese su contraseña' : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ColoresApp.rojoSuave,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const FaIcon(FontAwesomeIcons.circleExclamation, color: ColoresApp.rojo, size: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(_error!, style: const TextStyle(color: ColoresApp.rojoOscuro)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      BotonPrincipal(texto: 'Ingresar', cargando: _cargando, onPressed: _ingresar),
                      const SizedBox(height: 20),
                      const Text(
                        'Las cuentas las habilita la administración de TaxiUAP.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconoCampo extends StatelessWidget {
  final FaIconData icono;

  const _IconoCampo(this.icono);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: Center(child: FaIcon(icono, size: 16, color: ColoresApp.textoSuave)),
    );
  }
}
