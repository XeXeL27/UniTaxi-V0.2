import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/boton_relieve.dart';
import 'iconos.dart';
import 'relieve.dart';
import 'sesion.dart';
import 'tema.dart';

/// Cierra la sesion del panel despues de [Sesion.limiteInactividad] sin usarlo. Cuentan los clics,
/// toques, el desplazamiento y el teclado (no las consultas automaticas como la campana ni mover el
/// mouse sin hacer clic), de cualquier pestana abierta. Dos minutos antes avisa arriba con
/// "Seguir conectado". Dentro del APK no hace nada: ahi la sesion no se cierra por inactividad.
class VigilanteInactividad extends StatefulWidget {
  final Sesion sesion;

  /// Navegador del panel: al cerrar la sesion se quitan las ventanas abiertas.
  final GlobalKey<NavigatorState> navegador;
  final Widget child;

  const VigilanteInactividad({super.key, required this.sesion, required this.navegador, required this.child});

  @override
  State<VigilanteInactividad> createState() => _VigilanteInactividadState();
}

class _VigilanteInactividadState extends State<VigilanteInactividad> {
  static const _aviso = Duration(minutes: 2);
  static const _cadaCuantoAnotar = Duration(seconds: 30);

  DateTime _ultima = DateTime.now();
  DateTime? _anotada;
  Timer? _reloj;
  int _segundos = 0;

  /// Tiempo que falta para cerrar mientras se muestra el aviso.
  Duration? _restante;

  @override
  void initState() {
    super.initState();
    if (Sesion.dentroDeApk) return;
    HardwareKeyboard.instance.addHandler(_alTeclear);
    widget.sesion.addListener(_alCambiarSesion);
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) => _revisar());
  }

  @override
  void dispose() {
    _reloj?.cancel();
    HardwareKeyboard.instance.removeHandler(_alTeclear);
    widget.sesion.removeListener(_alCambiarSesion);
    super.dispose();
  }

  bool _alTeclear(KeyEvent evento) {
    _actividad();
    return false;
  }

  /// Al iniciar sesion se empieza a contar de nuevo.
  void _alCambiarSesion() {
    if (widget.sesion.autenticado) _ultima = DateTime.now();
  }

  void _actividad() {
    final ahora = DateTime.now();
    _ultima = ahora;
    if (_restante != null) setState(() => _restante = null);
    final anotada = _anotada;
    if (widget.sesion.autenticado && (anotada == null || ahora.difference(anotada) >= _cadaCuantoAnotar)) {
      _anotada = ahora;
      widget.sesion.registrarActividad();
    }
  }

  Future<void> _revisar() async {
    if (!widget.sesion.autenticado) {
      if (_restante != null) setState(() => _restante = null);
      return;
    }
    // Cada 30 s (y durante el aviso) se mira si se uso el panel en otra pestana.
    _segundos++;
    if (_segundos % 30 == 0 || _restante != null) {
      final otra = await widget.sesion.ultimaActividad();
      if (otra != null && otra.isAfter(_ultima)) _ultima = otra;
      if (!mounted) return;
    }
    final falta = Sesion.limiteInactividad - DateTime.now().difference(_ultima);
    if (falta <= Duration.zero) {
      await _cerrar();
    } else if (falta <= _aviso) {
      setState(() => _restante = falta);
    } else if (_restante != null) {
      setState(() => _restante = null);
    }
  }

  Future<void> _cerrar() async {
    setState(() => _restante = null);
    // Las ventanas abiertas (fichas, formularios) se quitan; las paginas las cambia el router.
    widget.navegador.currentState?.popUntil((ruta) => ruta.settings is Page);
    await widget.sesion.cerrar(motivo: Sesion.mensajeInactividad);
  }

  @override
  Widget build(BuildContext context) {
    if (Sesion.dentroDeApk) return widget.child;
    final restante = _restante;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _actividad(),
      onPointerMove: (_) => _actividad(),
      onPointerSignal: (_) => _actividad(),
      onPointerPanZoomUpdate: (_) => _actividad(),
      child: Stack(
        children: [
          widget.child,
          if (restante != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Center(child: _Aviso(restante: restante, alSeguir: _actividad)),
            ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final Duration restante;
  final VoidCallback alSeguir;

  const _Aviso({required this.restante, required this.alSeguir});

  @override
  Widget build(BuildContext context) {
    final segundos = restante.inSeconds + 1;
    final reloj = '${segundos ~/ 60}:${(segundos % 60).toString().padLeft(2, '0')}';
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF2C46D)),
          boxShadow: Relieve.sombraVentana,
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 10,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Iconos.clock, color: Color(0xFFB7791F), size: 20),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Tu sesión se cerrará en $reloj por inactividad.',
                    style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w600, height: 1.35),
                  ),
                ),
              ],
            ),
            BotonRelieve(
              texto: 'Seguir conectado',
              icono: Iconos.check,
              tono: TonoBoton.verde,
              alPresionar: alSeguir,
            ),
          ],
        ),
      ),
    );
  }
}
