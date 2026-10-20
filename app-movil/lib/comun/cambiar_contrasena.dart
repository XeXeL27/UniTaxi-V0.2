import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_excepcion.dart';
import '../core/cliente_api.dart';
import '../core/credenciales.dart';
import '../core/huella.dart';
import '../core/iconos.dart';
import '../core/tema.dart';
import '../widgets/boton_principal.dart';
import '../widgets/boton_reenviar.dart';
import '../widgets/cuenta_regresiva.dart';
import '../widgets/dialogos.dart';
import 'cuenta_api.dart';

/// Ancho desde el que el formulario se abre como modal en lugar de pantalla completa.
const double _anchoModal = 600;

/// Abre el cambio de contrasena: en el celular ocupa toda la pantalla; en una pantalla ancha
/// (navegador de PC) es un modal centrado. Al terminar muestra el modal verde.
///
/// Pasos: elegir como verificar (la contrasena actual o un codigo al correo registrado), verificar y
/// recien entonces la nueva contrasena dos veces. Al guardar llega un aviso al correo (sin la contrasena).
Future<void> abrirCambiarContrasena(BuildContext context, {CuentaApi? api}) async {
  final cambiada = MediaQuery.sizeOf(context).width >= _anchoModal
      ? await showDialog<_Resultado>(
          context: context,
          barrierDismissible: false,
          builder: (_) => Dialog(
            insetPadding: const EdgeInsets.all(24),
            backgroundColor: ColoresApp.blanco,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
                child: FormularioCambiarContrasena(enModal: true, api: api),
              ),
            ),
          ),
        )
      : await Navigator.of(context).push<_Resultado>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => Scaffold(
              backgroundColor: ColoresApp.fondo,
              appBar: AppBar(
                backgroundColor: ColoresApp.azul,
                foregroundColor: ColoresApp.blanco,
                title: const Text('Cambiar contraseña', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: FormularioCambiarContrasena(enModal: false, api: api),
                ),
              ),
            ),
          ),
        );
  if (cambiada != null && context.mounted) {
    await mostrarExito(
      context,
      titulo: 'Contraseña actualizada',
      mensaje: cambiada.conAviso
          ? 'Desde ahora ingresa a UNITAXI con tu nueva contraseña. Te enviamos un aviso a tu correo.'
          : 'Desde ahora ingresa a UNITAXI con tu nueva contraseña.',
    );
  }
}

/// La contrasena se cambio; [conAviso]: la cuenta tiene correo y le llega el aviso.
class _Resultado {
  final bool conAviso;

  const _Resultado(this.conAviso);
}

enum _Paso { elegir, actual, codigo, nueva }

class FormularioCambiarContrasena extends StatefulWidget {
  final bool enModal;

  /// Para las pruebas; sin ella se usa la del ClienteApi de la app.
  final CuentaApi? api;

  const FormularioCambiarContrasena({super.key, required this.enModal, this.api});

  @override
  State<FormularioCambiarContrasena> createState() => _FormularioCambiarContrasenaState();
}

class _FormularioCambiarContrasenaState extends State<FormularioCambiarContrasena> {
  final _clave = GlobalKey<FormState>();
  final _actual = TextEditingController();
  final _codigo = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmacion = TextEditingController();
  final _ocultos = [true, true, true];

  _Paso _paso = _Paso.elegir;

  /// Como se verifico: con el codigo del correo (si no, con la contrasena actual).
  bool _conCodigo = false;
  bool _enviando = false;
  String? _error;
  String? _aviso;

  /// A que correo llega el codigo; null mientras se consulta.
  CodigoContrasena? _correo;
  bool _correoNoDisponible = false;

  /// El servidor no envia otro codigo antes de 90 segundos: hasta entonces "Reenviar codigo" muestra la
  /// cuenta regresiva.
  static const _esperaReenvio = Duration(seconds: 90);
  DateTime? _reenvioDesde;
  Timer? _reloj;

  late final CuentaApi _api = widget.api ?? CuentaApi(context.read<ClienteApi>());

  @override
  void initState() {
    super.initState();
    _cargarCorreo();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _actual.dispose();
    _codigo.dispose();
    _nueva.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _cargarCorreo() async {
    try {
      final correo = await _api.correoParaCodigo();
      if (mounted) setState(() => _correo = correo);
    } catch (_) {
      // Sin conexion o servidor anterior: queda solo la contrasena actual.
      if (mounted) setState(() => _correoNoDisponible = true);
    }
  }

  void _ir(_Paso paso) {
    FocusScope.of(context).unfocus();
    setState(() {
      _paso = paso;
      _error = null;
      _aviso = null;
    });
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _enviando = true;
      _error = null;
      _aviso = null;
    });
    try {
      await accion();
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ---------------------------------------------------------------- verificar

  Future<void> _verificarActual() async {
    if (!(_clave.currentState?.validate() ?? false)) return;
    await _ejecutar(() async {
      await _api.verificarContrasena(_actual.text);
      if (!mounted) return;
      _conCodigo = false;
      _ir(_Paso.nueva);
    });
  }

  /// "No la recuerdo": si ya se envio un codigo hace poco se usa ese; si no, se envia uno.
  Future<void> _elegirCodigo() async {
    final correo = _correo;
    if (correo == null || !correo.puedeRecibirCodigo) return;
    if (correo.segundosParaReenviar > 0) {
      _iniciarCuenta(correo.segundosParaReenviar);
      _ir(_Paso.codigo);
      setState(() => _aviso = 'Ya te enviamos un código hace poco: usa el último que te llegó.');
      return;
    }
    await _ejecutar(() async {
      final enviado = await _api.enviarCodigoContrasena();
      if (!mounted) return;
      _correo = enviado;
      _codigo.clear();
      _iniciarCuenta(enviado.segundosParaReenviar);
      _ir(_Paso.codigo);
    });
  }

  Future<void> _reenviarCodigo() async {
    await _ejecutar(() async {
      final enviado = await _api.enviarCodigoContrasena();
      if (!mounted) return;
      _codigo.clear();
      _iniciarCuenta(enviado.segundosParaReenviar);
      setState(() => _aviso = 'Te enviamos un código nuevo. Usa el último que te llegó.');
    });
  }

  void _iniciarCuenta(int segundos) {
    _reenvioDesde = DateTime.now().add(Duration(seconds: segundos > 0 ? segundos : _esperaReenvio.inSeconds));
    _reloj?.cancel();
    _reloj = Timer.periodic(const Duration(seconds: 1), (reloj) {
      if (!mounted) return reloj.cancel();
      if (segundosHasta(_reenvioDesde) == 0) reloj.cancel();
      setState(() {});
    });
  }

  Future<void> _verificarCodigo() async {
    if (!(_clave.currentState?.validate() ?? false)) return;
    await _ejecutar(() async {
      await _api.verificarCodigoContrasena(_codigo.text);
      if (!mounted) return;
      _conCodigo = true;
      _ir(_Paso.nueva);
    });
  }

  // ---------------------------------------------------------------- guardar

  Future<void> _guardar() async {
    if (!(_clave.currentState?.validate() ?? false)) return;
    await _ejecutar(() async {
      if (_conCodigo) {
        await _api.cambiarContrasenaConCodigo(
          codigo: _codigo.text,
          nueva: _nueva.text,
          confirmacion: _confirmacion.text,
        );
      } else {
        await _api.cambiarContrasena(actual: _actual.text, nueva: _nueva.text, confirmacion: _confirmacion.text);
      }
      // Lo recordado en el telefono (login y huella) pasa a la contrasena nueva.
      try {
        final recordadas = await Credenciales.leer();
        if (recordadas != null) await Credenciales.guardar(recordadas.usuario, _nueva.text);
        await Huella.actualizarContrasena(_nueva.text);
      } catch (_) {
        // La contrasena ya cambio en el servidor; lo recordado se corrige al volver a ingresar.
      }
      if (mounted) Navigator.of(context).pop(_Resultado(_correo?.puedeRecibirCodigo ?? false));
    });
  }

  // ---------------------------------------------------------------- vista

  String get _explicacion => switch (_paso) {
    _Paso.elegir => '¿Cómo quieres verificar que eres tú?',
    _Paso.actual => 'Escribe la contraseña que usas para ingresar.',
    _Paso.codigo =>
      'Te enviamos un código de 6 dígitos a ${_correo?.correo ?? 'tu correo'}. Revisa también la carpeta de spam.',
    _Paso.nueva => 'Escribe tu nueva contraseña dos veces.',
  };

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
                child: Center(
                  child: Icon(
                    _paso == _Paso.codigo ? Iconos.envelopeOpenText : Iconos.lock,
                    color: const Color(0xFFE67E22),
                    size: 19,
                  ),
                ),
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
                      _explicacion,
                      style: TextStyle(color: ColoresApp.textoSuave, fontSize: widget.enModal ? 13.5 : 14.5),
                    ),
                  ],
                ),
              ),
              if (widget.enModal)
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: _enviando ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Iconos.xmark, size: 18, color: ColoresApp.textoSuave),
                ),
            ],
          ),
          const SizedBox(height: 22),
          if (_error != null) ...[
            _Mensaje(texto: _error!, error: true),
            const SizedBox(height: 16),
          ],
          if (_aviso != null) ...[
            _Mensaje(texto: _aviso!),
            const SizedBox(height: 16),
          ],
          ...switch (_paso) {
            _Paso.elegir => _elegir(),
            _Paso.actual => _pasoActual(),
            _Paso.codigo => _pasoCodigo(),
            _Paso.nueva => _pasoNueva(),
          },
          if (widget.enModal && _paso == _Paso.elegir) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: _enviando ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: ColoresApp.textoSuave)),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _elegir() {
    final correo = _correo;
    final String detalleCodigo;
    final bool codigoActivo;
    if (correo == null && !_correoNoDisponible) {
      detalleCodigo = 'Buscando tu correo...';
      codigoActivo = false;
    } else if (correo == null || _correoNoDisponible) {
      detalleCodigo = 'No disponible ahora. Revisa tu conexión e intenta de nuevo.';
      codigoActivo = false;
    } else if (!correo.puedeRecibirCodigo) {
      detalleCodigo = 'Tu cuenta no tiene un correo registrado.';
      codigoActivo = false;
    } else {
      detalleCodigo = 'Te enviamos un código a ${correo.correo}.';
      codigoActivo = true;
    }
    return [
      _Opcion(
        icono: Iconos.key,
        titulo: 'Con mi contraseña actual',
        detalle: 'Escribe la contraseña que usas para ingresar.',
        onTap: _enviando ? null : () => _ir(_Paso.actual),
      ),
      const SizedBox(height: 12),
      _Opcion(
        icono: Iconos.envelope,
        titulo: 'No la recuerdo',
        detalle: detalleCodigo,
        cargando: _enviando,
        onTap: codigoActivo && !_enviando ? _elegirCodigo : null,
      ),
    ];
  }

  List<Widget> _pasoActual() => [
    _campo(0, _actual, 'Contraseña actual', (v) => (v == null || v.isEmpty) ? 'Escribe tu contraseña actual' : null,
        alEnviar: _verificarActual, autofill: AutofillHints.password),
    const SizedBox(height: 22),
    BotonPrincipal(texto: 'Verificar', cargando: _enviando, onPressed: _verificarActual),
    const SizedBox(height: 10),
    _volver(),
  ];

  List<Widget> _pasoCodigo() => [
    TextFormField(
      controller: _codigo,
      keyboardType: TextInputType.number,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _verificarCodigo(),
      decoration: const InputDecoration(
        labelText: 'Código de 6 dígitos',
        prefixIcon: SizedBox(
          width: 44,
          child: Center(child: Icon(Iconos.hashtag, size: 15, color: ColoresApp.textoSuave)),
        ),
      ),
      validator: (v) => (v == null || v.length != 6) ? 'El código tiene 6 dígitos' : null,
    ),
    const SizedBox(height: 22),
    BotonPrincipal(texto: 'Verificar código', cargando: _enviando, onPressed: _verificarCodigo),
    const SizedBox(height: 12),
    BotonReenviar(
      faltan: segundosHasta(_reenvioDesde),
      total: _esperaReenvio.inSeconds,
      onPressed: _enviando ? null : _reenviarCodigo,
    ),
    _volver(),
  ];

  List<Widget> _pasoNueva() => [
    _Mensaje(
      texto: _conCodigo ? 'Código verificado.' : 'Contraseña verificada.',
    ),
    const SizedBox(height: 16),
    _campo(1, _nueva, 'Nueva contraseña', (v) {
      if (v == null || v.isEmpty) return 'Escribe la nueva contraseña';
      if (v.length < 8) return 'Debe tener al menos 8 caracteres';
      if (v.length > 72) return 'Debe tener como máximo 72 caracteres';
      if (!_conCodigo && v == _actual.text) return 'Debe ser distinta de la actual';
      return null;
    }, autofill: AutofillHints.newPassword),
    const SizedBox(height: 14),
    _campo(2, _confirmacion, 'Confirmar nueva contraseña', (v) {
      if (v == null || v.isEmpty) return 'Vuelve a escribir la nueva contraseña';
      if (v != _nueva.text) return 'No coincide con la nueva contraseña';
      return null;
    }, alEnviar: _guardar, autofill: AutofillHints.newPassword),
    const SizedBox(height: 10),
    const Row(
      children: [
        Icon(Iconos.circleInfo, size: 13, color: ColoresApp.textoSuave),
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
  ];

  Widget _volver() => TextButton(
    onPressed: _enviando ? null : () => _ir(_Paso.elegir),
    child: const Text('Volver', style: TextStyle(color: ColoresApp.textoSuave)),
  );

  Widget _campo(
    int indice,
    TextEditingController controlador,
    String etiqueta,
    String? Function(String?) validar, {
    VoidCallback? alEnviar,
    required String autofill,
  }) {
    return TextFormField(
      controller: controlador,
      obscureText: _ocultos[indice],
      textInputAction: alEnviar != null ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: alEnviar == null ? null : (_) => alEnviar(),
      autofillHints: [autofill],
      decoration: InputDecoration(
        labelText: etiqueta,
        prefixIcon: const SizedBox(
          width: 44,
          child: Center(child: Icon(Iconos.key, size: 15, color: ColoresApp.textoSuave)),
        ),
        suffixIcon: IconButton(
          tooltip: _ocultos[indice] ? 'Mostrar' : 'Ocultar',
          onPressed: () => setState(() => _ocultos[indice] = !_ocultos[indice]),
          icon: Icon(
            _ocultos[indice] ? Iconos.eye : Iconos.eyeSlash,
            size: 16,
            color: ColoresApp.textoSuave,
          ),
        ),
      ),
      validator: validar,
    );
  }
}

/// Una de las dos formas de verificar: tarjeta con icono, titulo, detalle y flecha.
class _Opcion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback? onTap;
  final bool cargando;

  const _Opcion({required this.icono, required this.titulo, required this.detalle, this.onTap, this.cargando = false});

  @override
  Widget build(BuildContext context) {
    final activa = onTap != null;
    return Material(
      color: ColoresApp.blanco,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ColoresApp.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: activa ? ColoresApp.azulSuave : ColoresApp.gris,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, size: 18, color: activa ? ColoresApp.azul : ColoresApp.textoSuave),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        color: activa ? ColoresApp.tinta : ColoresApp.textoSuave,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(detalle, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13)),
                  ],
                ),
              ),
              if (cargando)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(Iconos.chevronRight, size: 16, color: activa ? ColoresApp.textoSuave : ColoresApp.borde),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mensaje de error (rojo) o de aviso (verde) arriba del formulario.
class _Mensaje extends StatelessWidget {
  final String texto;
  final bool error;

  const _Mensaje({required this.texto, this.error = false});

  @override
  Widget build(BuildContext context) {
    final color = error ? ColoresApp.rojo : ColoresApp.exito;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? ColoresApp.rojoSuave : ColoresApp.exito.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(error ? Iconos.circleExclamation : Iconos.circleCheck, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: TextStyle(color: error ? ColoresApp.rojoOscuro : ColoresApp.exito))),
        ],
      ),
    );
  }
}
