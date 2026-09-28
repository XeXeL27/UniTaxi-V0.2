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

  /// Hoja inferior "¿Como quieres ingresar?" para quien tiene cuenta de pasajero y de conductor.
  Future<String?> _elegirModo(List<String> modos) {
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
                modos.contains(Config.rolAdmin)
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
                  detalle: 'Recibe solicitudes de viaje',
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

  /// Ingreso con la huella: usa las credenciales que se guardaron al activarla.
  Future<void> _ingresarConHuella() async {
    final credenciales = await Huella.ingresar();
    if (credenciales == null || !mounted) return;
    _usuario.text = credenciales.usuario;
    _password.text = credenciales.contrasena;
    await _ingresar();
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    // Desde 900 px (PC o tablet horizontal) la marca va a la izquierda y el formulario a la derecha,
    // igual que el login del panel admin; mas angosto, la marca pasa arriba y todo se desplaza.
    if (ancho >= 900) {
      return Scaffold(
        backgroundColor: ColoresApp.blanco,
        body: Row(
          children: [
            const Expanded(flex: 5, child: _PanelMarca()),
            Expanded(
              flex: 6,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: _formulario()),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _PanelMarca(compacta: true),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                      decoration: BoxDecoration(
                        color: ColoresApp.blanco,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [BoxShadow(color: Color(0x1F0A2342), blurRadius: 24, offset: Offset(0, 10))],
                      ),
                      child: _formulario(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            const SizedBox(height: 12),
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
            const SizedBox(height: 22),
            const Row(
              children: [
                Expanded(child: Divider(color: ColoresApp.borde, height: 1)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: FaIcon(FontAwesomeIcons.lock, color: ColoresApp.textoSuave, size: 11),
                ),
                Expanded(child: Divider(color: ColoresApp.borde, height: 1)),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Un solo acceso para pasajeros, conductores y administradores. '
              'Las cuentas las habilita la administración de TaxiUAP.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marca de TaxiUAP: a la izquierda en pantallas anchas y como cabecera en el celular.
class _PanelMarca extends StatelessWidget {
  final bool compacta;

  const _PanelMarca({this.compacta = false});

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16386B), ColoresApp.azul],
        ),
        borderRadius: compacta ? const BorderRadius.vertical(bottom: Radius.circular(28)) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: compacta ? null : -140,
            right: compacta ? -90 : null,
            bottom: compacta ? -120 : -180,
            child: Container(
              width: compacta ? 260 : 440,
              height: compacta ? 260 : 440,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [ColoresApp.rojo.withValues(alpha: 0.42), Colors.transparent]),
              ),
            ),
          ),
          Padding(
            padding: compacta
                ? EdgeInsets.fromLTRB(24, arriba + 40, 24, 64)
                : const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: compacta ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                Container(
                  width: compacta ? 62 : 70,
                  height: compacta ? 62 : 70,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [ColoresApp.rojo, ColoresApp.rojoOscuro],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: ColoresApp.rojoOscuro.withValues(alpha: 0.45), blurRadius: 22, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: const Center(child: FaIcon(FontAwesomeIcons.taxi, color: ColoresApp.blanco, size: 28)),
                ),
                SizedBox(height: compacta ? 16 : 26),
                Text(
                  'TaxiUAP',
                  style: TextStyle(
                    fontSize: compacta ? 30 : 40,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: ColoresApp.blanco,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Transporte seguro para estudiantes',
                  style: TextStyle(fontSize: compacta ? 14.5 : 16, color: ColoresApp.blanco.withValues(alpha: 0.78)),
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
                    'Pide tu mototaxi, conduce con nosotros o administra el servicio desde un solo lugar.',
                    style: TextStyle(fontSize: 15, height: 1.5, color: ColoresApp.blanco.withValues(alpha: 0.72)),
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
