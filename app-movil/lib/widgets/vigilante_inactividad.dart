import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/sesion.dart';
import '../core/tema.dart';

/// Solo en el navegador (/app): cierra la sesion despues de [Sesion.limiteInactividad] sin usar la app.
/// Cuentan los toques, clics, el desplazamiento y el teclado de cualquier pestana (no las consultas
/// automaticas ni el GPS). Dos minutos antes avisa arriba con "Seguir conectado". En el APK no se usa.
class VigilanteInactividad extends StatefulWidget {
  final Sesion sesion;
  final Widget child;

  const VigilanteInactividad({super.key, required this.sesion, required this.child});

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
    // Cada 30 s (y durante el aviso) se mira si se uso la app en otra pestana.
    _segundos++;
    if (_segundos % 30 == 0 || _restante != null) {
      final otra = await widget.sesion.ultimaActividad();
      if (otra != null && otra.isAfter(_ultima)) _ultima = otra;
      if (!mounted) return;
    }
    final falta = Sesion.limiteInactividad - DateTime.now().difference(_ultima);
    if (falta <= Duration.zero) {
      setState(() => _restante = null);
      // main.dart quita las ventanas abiertas al cerrarse la sesion.
      await widget.sesion.cerrar(motivo: Sesion.mensajeInactividad);
    } else if (falta <= _aviso) {
      setState(() => _restante = falta);
    } else if (_restante != null) {
      setState(() => _restante = null);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              top: MediaQuery.paddingOf(context).top + 12,
              left: 16,
              right: 16,
              child: Center(
                child: _Aviso(restante: restante, alSeguir: _actividad),
              ),
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
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        decoration: BoxDecoration(
          color: ColoresApp.blanco,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF2C46D)),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule_rounded, color: Color(0xFFB7791F), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tu sesión se cerrará en $reloj por inactividad.',
                    style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w600, height: 1.35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: alSeguir,
                style: FilledButton.styleFrom(backgroundColor: ColoresApp.azul),
                child: const Text('Seguir conectado'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
