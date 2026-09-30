import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/config.dart';
import '../../core/credenciales.dart';
import '../../core/huella.dart';
import '../../core/sesion.dart';
import '../../core/tema.dart';
import '../../widgets/boton_principal.dart';
import '../../widgets/marco_acceso.dart';
import '../registro/ingreso_google.dart';
import '../registro/pantalla_registro.dart';
import 'restablecer_contrasena.dart';

/// Inicio de sesion con usuario, correo o telefono y contrasena, o con Google. Desde aqui se abre
/// el registro de pasajero o conductor.
class PantallaLogin extends StatefulWidget {
  /// Mensaje con que se abre (por ejemplo, el ingreso con Google fallo o se cancelo).
  final String? errorInicial;

  const PantallaLogin({super.key, this.errorInicial});

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
  late String? _error = widget.errorInicial;

  /// La huella esta activada en este telefono (solo el APK de Android).
  bool _huellaActiva = false;

  @override
  void initState() {
    super.initState();
    _cargarRecordadas();
    _revisarHuella();
  }

  Future<void> _revisarHuella() async {
    final activa = await Huella.activada() && await Huella.disponible();
    if (mounted && activa) setState(() => _huellaActiva = true);
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

  /// Hoja inferior "¿Como quieres ingresar?" para quien tiene cuenta de pasajero y de conductor, o
  /// antes de ingresar con Google ([conGoogle]).
  Future<String?> _elegirModo(List<String> modos, {bool conGoogle = false}) {
    return showModalBottomSheet<String>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 520),
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
              Text(
                conGoogle
                    ? 'Luego eliges tu cuenta de Google. Si eres conductor nuevo te pediremos tu licencia, tu moto y tus documentos.'
                    : modos.contains(Config.rolAdmin)
                    ? 'Tu usuario tiene más de un tipo de cuenta. Elige con cuál entrar.'
                    : 'Tu cuenta es de pasajero y de conductor. Luego puedes cambiar desde Más.',
                style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13.5),
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
                  detalle: conGoogle ? 'Llevo pasajeros y recibo solicitudes de viaje' : 'Recibe solicitudes de viaje',
                  color: ColoresApp.azul,
                  onTap: () => Navigator.of(context).pop(Config.rolConductor),
                ),
              if (modos.contains(Config.rolAdmin)) ...[
                const SizedBox(height: 10),
                _OpcionModo(
                  icono: FontAwesomeIcons.userShield,
                  titulo: 'Administrador',
                  detalle: 'Abre el panel de administración',
                  color: ColoresApp.texto,
                  onTap: () => Navigator.of(context).pop(Config.rolAdmin),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Google: primero se elige si entra como pasajero o como conductor. Pasajero entra directo (si
  /// no tenia cuenta se registra); conductor nuevo llena su formulario antes de entrar.
  Future<void> _ingresarConGoogle() async {
    final modo = await _elegirModo(const [Config.rolPasajero, Config.rolConductor], conGoogle: true);
    if (modo == null || !mounted) return;
    await continuarConGoogle(context, modo, alCargar: (cargando) => setState(() => _cargando = cargando));
  }

  /// Ingreso con la huella: usa las credenciales que se guardaron al activarla.
  Future<void> _ingresarConHuella() async {
    final credenciales = await Huella.ingresar();
    if (credenciales == null || !mounted) return;
    _usuario.text = credenciales.usuario;
    _password.text = credenciales.contrasena;
    await _ingresar();
  }

  /// Codigo por correo y contrasena nueva; al terminar deja el correo escrito para ingresar.
  Future<void> _olvideContrasena() async {
    final correo = await abrirRestablecerContrasena(context, correoInicial: _usuario.text.trim());
    if (correo != null && mounted) {
      setState(() {
        _usuario.text = correo;
        _password.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) => MarcoAcceso(child: _formulario());

  Widget _formulario() {
    return AutofillGroup(
      child: Form(
        key: _claveFormulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Iniciar sesión',
              style: TextStyle(color: ColoresApp.azul, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.4),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ingresa con tu usuario, correo o teléfono',
              style: TextStyle(color: ColoresApp.textoSuave, fontSize: 14.5),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ColoresApp.rojoSuave,
                  borderRadius: BorderRadius.circular(12),
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
                      child: Text(_error!, style: const TextStyle(color: ColoresApp.rojoOscuro, height: 1.35)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _usuario,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
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
              autofillHints: const [AutofillHints.password],
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
            const SizedBox(height: 6),
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _cargando ? null : _olvideContrasena,
                child: const Text(
                  '¿Olvidaste tu contraseña?',
                  style: TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 4),
            BotonPrincipal(texto: 'Iniciar sesión', cargando: _cargando, onPressed: _ingresar),
            if (_huellaActiva) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _cargando ? null : _ingresarConHuella,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: ColoresApp.azul,
                  side: const BorderSide(color: ColoresApp.borde),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const FaIcon(FontAwesomeIcons.fingerprint, size: 18),
                label: const Text('Ingresar con huella', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
            if (googleDisponible) ...[
              const SizedBox(height: 18),
              const Row(
                children: [
                  Expanded(child: Divider(color: ColoresApp.borde, height: 1)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('o', style: TextStyle(color: ColoresApp.textoSuave)),
                  ),
                  Expanded(child: Divider(color: ColoresApp.borde, height: 1)),
                ],
              ),
              const SizedBox(height: 18),
              BotonGoogle(
                onPressed: _cargando ? null : _ingresarConGoogle,
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('¿No tienes cuenta?', style: TextStyle(color: ColoresApp.textoSuave, fontSize: 14)),
                TextButton(
                  onPressed: _cargando
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PantallaRegistro())),
                  child: const Text('Regístrate', style: TextStyle(color: ColoresApp.rojo, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
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
