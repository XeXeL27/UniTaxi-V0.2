import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/config.dart';
import '../../core/credenciales.dart';
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
  bool _recordar = false;
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarRecordadas();
  }

  /// Si el usuario pidio que se recuerden, los campos aparecen llenos al abrir la app.
  Future<void> _cargarRecordadas() async {
    final credenciales = await Credenciales.leer();
    if (credenciales == null || !mounted) return;
    setState(() {
      _usuario.text = credenciales.usuario;
      _password.text = credenciales.contrasena;
      _recordar = true;
    });
  }

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
      // Se toman antes: al iniciar sesion esta pantalla se cierra.
      final usuario = _usuario.text.trim();
      final contrasena = _password.text;
      final recordar = _recordar;
      final sesion = context.read<Sesion>();
      final modos = await sesion.iniciar(usuario, contrasena);
      // Es pasajero y conductor: se le pregunta como quiere ingresar.
      if (modos != null) {
        if (!mounted) return;
        final elegido = await _elegirModo(modos);
        if (elegido == null) return;
        await sesion.iniciar(usuario, contrasena, rol: elegido);
      }
      if (recordar) {
        await Credenciales.guardar(usuario, contrasena);
      } else {
        await Credenciales.olvidar();
      }
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Hoja inferior "¿Como quieres ingresar?" para quien tiene cuenta de pasajero y de conductor.
  Future<String?> _elegirModo(List<String> modos) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: ColoresApp.blanco,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '¿Cómo quieres ingresar?',
                style: TextStyle(color: ColoresApp.azul, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tu cuenta es de pasajero y de conductor. Luego puedes cambiar desde el menú.',
                style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13.5),
              ),
              const SizedBox(height: 16),
              if (modos.contains(Config.rolPasajero))
                _OpcionModo(
                  icono: FontAwesomeIcons.personWalking,
                  titulo: 'Pasajero',
                  detalle: 'Pide un taxi',
                  color: ColoresApp.rojo,
                  onTap: () => Navigator.of(context).pop(Config.rolPasajero),
                ),
              const SizedBox(height: 10),
              if (modos.contains(Config.rolConductor))
                _OpcionModo(
                  icono: FontAwesomeIcons.motorcycle,
                  titulo: 'Conductor',
                  detalle: 'Recibe solicitudes de viaje',
                  color: ColoresApp.azul,
                  onTap: () => Navigator.of(context).pop(Config.rolConductor),
                ),
            ],
          ),
        ),
      ),
    );
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
                  'Pasajeros y conductores',
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
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _recordar,
                        onChanged: (v) => setState(() => _recordar = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: ColoresApp.azul,
                        title: const Text(
                          'Recordar usuario y contraseña',
                          style: TextStyle(color: ColoresApp.texto, fontSize: 14.5),
                        ),
                      ),
                      const SizedBox(height: 16),
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

class _OpcionModo extends StatelessWidget {
  final FaIconData icono;
  final String titulo;
  final String detalle;
  final Color color;
  final VoidCallback onTap;

  const _OpcionModo({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColoresApp.fondo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ColoresApp.borde),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: FaIcon(icono, color: ColoresApp.blanco, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: const TextStyle(color: ColoresApp.azul, fontSize: 17, fontWeight: FontWeight.w700)),
                    Text(detalle, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13)),
                  ],
                ),
              ),
              const FaIcon(FontAwesomeIcons.chevronRight, color: ColoresApp.textoSuave, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
