import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../core/iconos.dart';
import '../core/tema.dart';
import '../widgets/notificaciones.dart';

/// Pantalla para enderezar la foto del carnet o de la licencia antes de leerla. Con el telefono sobre
/// la mesa la camara suele guardar la foto de costado: la persona la gira de a un cuarto de vuelta
/// hasta que las letras se lean derechas, y puede acercarla con dos dedos para ver si se lee.
/// Devuelve la foto ya girada o null si cancela.
///
/// [guia] y [requisitos] cambian lo que se pide de la foto (por defecto, lo del documento); la foto de
/// una entrega DELIVERY pide otra cosa.
Future<Uint8List?> enderezarFoto(BuildContext context, Uint8List foto,
        {required String titulo, String? guia, List<String>? requisitos}) =>
    Navigator.of(context).push<Uint8List>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _EditorFoto(
        foto: foto,
        titulo: titulo,
        guia: guia ?? 'Gira la foto hasta que las letras se lean derechas. La foto debe estar:',
        requisitos: requisitos ??
            const [
              'Derecha, con las letras de izquierda a derecha',
              'Nítida y con buena luz, sin reflejos ni sombras',
              'Con todo el documento a la vista, sin cortar los bordes',
            ],
      ),
    ));

/// Gira la foto [cuartos] cuartos de vuelta a la derecha, despues de aplicar el giro que la camara
/// anoto en el EXIF (el servidor no lo lee: sin esto el admin la veria de costado). Si no hay nada
/// que girar devuelve la misma foto.
Uint8List _girarFoto((Uint8List, int) datos) {
  final (foto, cuartos) = datos;
  int orientacion;
  try {
    orientacion = img.decodeJpgExif(foto)?.imageIfd.orientation ?? 1;
  } catch (_) {
    orientacion = 1;
  }
  if (cuartos == 0 && orientacion == 1) return foto;
  final original = img.decodeImage(foto);
  if (original == null) throw const FormatException('No es una imagen');
  var derecha = img.bakeOrientation(original);
  if (cuartos != 0) derecha = img.copyRotate(derecha, angle: 90 * cuartos);
  return img.encodeJpg(derecha, quality: 92);
}

/// Barra de estado y de navegacion sobre el fondo negro del editor.
const _barrasOscuras = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: ColoresApp.tinta,
  systemNavigationBarIconBrightness: Brightness.light,
);

class _EditorFoto extends StatefulWidget {
  final Uint8List foto;
  final String titulo;
  final String guia;
  final List<String> requisitos;

  const _EditorFoto({required this.foto, required this.titulo, required this.guia, required this.requisitos});

  @override
  State<_EditorFoto> createState() => _EditorFotoState();
}

class _EditorFotoState extends State<_EditorFoto> {
  /// Cuartos de vuelta a la derecha (0 a 3). RotatedBox y copyRotate giran en el mismo sentido.
  int _cuartos = 0;
  bool _girando = false;
  final _zoom = TransformationController();

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _girar(int sentido) {
    _zoom.value = Matrix4.identity();
    setState(() => _cuartos = (_cuartos + sentido) % 4);
  }

  Future<void> _usar() async {
    setState(() => _girando = true);
    try {
      final derecha = await compute(_girarFoto, (widget.foto, _cuartos));
      if (mounted) Navigator.of(context).pop(derecha);
    } catch (_) {
      if (!mounted) return;
      setState(() => _girando = false);
      mostrarMensaje(context, 'No se pudo girar la foto en este teléfono. Intenta con otra foto.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_girando,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _barrasOscuras,
        child: Scaffold(
          backgroundColor: ColoresApp.tinta,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Cancelar',
                        onPressed: _girando ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(Iconos.xmark, color: ColoresApp.blanco, size: 20),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.titulo,
                          style: const TextStyle(color: ColoresApp.blanco, fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.guia,
                        style: const TextStyle(color: ColoresApp.blanco, fontSize: 17, height: 1.35, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      for (final requisito in widget.requisitos) _Requisito(requisito),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: InteractiveViewer(
                      transformationController: _zoom,
                      maxScale: 5,
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: _cuartos,
                          child: Image.memory(widget.foto, fit: BoxFit.contain, gaplessPlayback: true),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _botonGiro(Iconos.rotateLeft, 'Girar a la izquierda', () => _girar(-1)),
                          const SizedBox(width: 32),
                          _botonGiro(Iconos.rotateRight, 'Girar a la derecha', () => _girar(1)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 54,
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _girando ? null : _usar,
                          style: FilledButton.styleFrom(
                            backgroundColor: ColoresApp.blanco,
                            foregroundColor: ColoresApp.tinta,
                            disabledBackgroundColor: ColoresApp.blanco.withValues(alpha: 0.6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          child: _girando
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: ColoresApp.tinta),
                                )
                              : const Text('Usar esta foto'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _botonGiro(IconData icono, String texto, VoidCallback alTocar) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: const Color(0xFF2B2B2B),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _girando ? null : alTocar,
            child: SizedBox(
              width: 58,
              height: 58,
              child: Center(child: Icon(icono, color: ColoresApp.blanco, size: 21)),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(texto, style: const TextStyle(color: ColoresApp.blanco, fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Una condicion que debe cumplir la foto, con su check.
class _Requisito extends StatelessWidget {
  final String texto;

  const _Requisito(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Iconos.circleCheck, color: Color(0xFF66BB6A), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto, style: const TextStyle(color: Color(0xFFE6E6E6), fontSize: 16, height: 1.3)),
          ),
        ],
      ),
    );
  }
}
