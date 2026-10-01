import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/sesion.dart';
import '../../core/tema.dart';

/// Ajuste de los iconos dentro de los campos del login: izquierda, arriba, abajo, derecha.
/// Un valor positivo acerca el icono hacia ese lado. El tamano se cambia en el size del icono.
const EdgeInsets _ajusteIconoLogin = EdgeInsets.only(left: 10, top: 10);

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
    final dividido = MediaQuery.sizeOf(context).width >= Pantalla.loginDividido;
    return Scaffold(
      backgroundColor: ColoresApp.azul,
      body: dividido
          ? Row(
              children: [
                const Expanded(flex: 5, child: _PanelMarca()),
                Expanded(flex: 6, child: _formulario()),
              ],
            )
          : Column(
              children: [
                const _PanelMarca(compacta: true),
                Expanded(child: _formulario()),
              ],
            ),
    );
  }

  Widget _formulario() {
    return Container(
      color: ColoresApp.superficie,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _claveFormulario,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Iniciar sesión',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: ColoresApp.azul,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Entra con tu cuenta de administrador',
                    style: TextStyle(fontSize: 15, color: ColoresApp.textoSuave),
                  ),
                  const SizedBox(height: 28),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECF0),
                        borderRadius: BorderRadius.circular(RadiosApp.control),
                        border: Border.all(color: ColoresApp.rojo.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: FaIcon(FontAwesomeIcons.circleExclamation, color: ColoresApp.rojo, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: ColoresApp.rojoOscuro, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  TextFormField(
                    controller: _usuario,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Usuario, correo o teléfono',
                      prefixIcon: Padding(
                        padding: _ajusteIconoLogin,
                        child: FaIcon(FontAwesomeIcons.user, size: 16),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese su usuario' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: _ocultarPassword,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _ingresar(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Padding(
                        padding: _ajusteIconoLogin,
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
                  const SizedBox(height: 26),
                  FilledButton.icon(
                    onPressed: _cargando ? null : _ingresar,
                    icon: _cargando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const FaIcon(FontAwesomeIcons.rightToBracket, size: 16),
                    label: const Text('Iniciar sesión'),
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: ColoresApp.borde, height: 1)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: FaIcon(FontAwesomeIcons.lock, color: ColoresApp.textoSuave, size: 12),
                      ),
                      Expanded(child: Divider(color: ColoresApp.borde, height: 1)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Acceso exclusivo para administradores del sistema',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: ColoresApp.textoSuave),
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

/// Lado izquierdo del login: marca, nombre del producto y un halo rojo difuso.
class _PanelMarca extends StatelessWidget {
  const _PanelMarca({this.compacta = false});

  final bool compacta;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ColoresApp.azulClaro, ColoresApp.azul],
        ),
      ),
      child: Stack(
        children: [
          if (!compacta)
            Positioned(
              left: -140,
              bottom: -180,
              child: Container(
                width: 440,
                height: 440,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [ColoresApp.rojo.withValues(alpha: 0.45), Colors.transparent],
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compacta ? 24 : 56, vertical: compacta ? 32 : 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: compacta ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: compacta ? Alignment.center : Alignment.centerLeft,
                  child: Container(
                    width: compacta ? 54 : 66,
                    height: compacta ? 54 : 66,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [ColoresApp.rojo, ColoresApp.rojoOscuro],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: ColoresApp.rojoOscuro.withValues(alpha: 0.45),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Center(child: FaIcon(FontAwesomeIcons.taxi, color: Colors.white, size: 28)),
                  ),
                ),
                SizedBox(height: compacta ? 14 : 26),
                Text(
                  'UNITAXI',
                  style: TextStyle(
                    fontSize: compacta ? 28 : 38,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Panel de administración',
                  style: TextStyle(
                    fontSize: compacta ? 14 : 16,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                if (!compacta) ...[
                  const SizedBox(height: 26),
                  Container(
                    width: 56,
                    height: 4,
                    decoration: BoxDecoration(color: ColoresApp.rojo, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Gestiona pasajeros, conductores, viajes y verificaciones desde un solo lugar.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
