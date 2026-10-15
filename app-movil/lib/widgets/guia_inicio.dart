import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/cliente_api.dart';
import '../core/sesion.dart';
import '../core/tema.dart';

/// Guias de cada parte de la app (ademas de la de inicio). Cada una se muestra una vez por cuenta,
/// tambien a las cuentas que ya usaban la app; Perfil > "Volver a ver las guías" las repite.
abstract final class Guias {
  /// "Elige tu servicio": moto taxi para mi o para otra persona, encomienda, compra y pago.
  static const pasajeroServicios = 'PASAJERO_SERVICIOS';

  /// Primer viaje o pedido aceptado del pasajero.
  static const pasajeroViaje = 'PASAJERO_VIAJE';

  /// Primer viaje aceptado del conductor de taxi.
  static const conductorViaje = 'CONDUCTOR_VIAJE';

  /// Inicio del repartidor (reemplaza a la guia de inicio del conductor).
  static const repartidorInicio = 'REPARTIDOR_INICIO';

  /// Primer pedido aceptado del repartidor.
  static const repartidorPedido = 'REPARTIDOR_PEDIDO';
}

/// Un paso de la guia: lo que se ilumina y lo que se explica. Se ilumina el widget de [clave] o el
/// [MarcaGuia] con el id [marca]; sin ninguno de los dos (o si no esta en pantalla y tiene [icono])
/// el cuadro va al centro con el icono, para explicar opciones que no son un boton.
class PasoGuia {
  final GlobalKey? clave;
  final String? marca;
  final String titulo;
  final String texto;
  final IconData? icono;

  /// Ilumina un circulo en vez de un rectangulo redondeado (por ejemplo el boton central).
  final bool circulo;

  const PasoGuia({
    this.clave,
    this.marca,
    required this.titulo,
    required this.texto,
    this.icono,
    this.circulo = false,
  });
}

/// Marca un widget para que una guia lo ilumine por su [id] (sin pasar claves por varios widgets).
/// Si dos estan en pantalla con el mismo id vale el ultimo que se dibujo.
class MarcaGuia extends StatefulWidget {
  final String id;
  final Widget child;

  const MarcaGuia({super.key, required this.id, required this.child});

  static final Map<String, BuildContext> _marcas = {};

  @override
  State<MarcaGuia> createState() => _MarcaGuiaState();
}

class _MarcaGuiaState extends State<MarcaGuia> {
  @override
  Widget build(BuildContext context) {
    MarcaGuia._marcas[widget.id] = context;
    return widget.child;
  }

  @override
  void dispose() {
    if (MarcaGuia._marcas[widget.id] == context) MarcaGuia._marcas.remove(widget.id);
    super.dispose();
  }
}

/// Guias abiertas en este momento: un segundo pedido de la misma no la abre dos veces.
final Set<String> _guiasEnCurso = {};

/// Guia de la primera vez: oscurece la pantalla, ilumina un boton a la vez y al lado muestra un
/// cuadro pequeno con la explicacion, "1 de 5", Saltar y Siguiente. Los pasos cuyo widget no esta
/// en pantalla se omiten (o van al centro si tienen icono). Al terminarla o saltarla se marca como
/// vista en el servidor (POST /api/cuenta/guia-vista) y en la sesion, asi no se vuelve a mostrar.
/// Sin [guia] es la guia de inicio; con [guia] (uno de [Guias]) la de esa parte de la app, y con
/// [tambienInicio] marca ademas la de inicio (la del repartidor la reemplaza).
Future<void> mostrarGuiaInicio(
  BuildContext context,
  List<PasoGuia> pasos, {
  String? guia,
  bool tambienInicio = false,
}) async {
  final pantalla = Offset.zero & MediaQuery.sizeOf(context);
  final visibles = [
    for (final paso in pasos)
      if (_rectDe(paso, pantalla) != null || paso.icono != null || (paso.clave == null && paso.marca == null)) paso,
  ];
  final id = guia ?? '';
  if (visibles.isEmpty || !_guiasEnCurso.add(id)) return;
  final sesion = context.read<Sesion>();
  final api = context.read<ClienteApi>();
  try {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, animacion, _) => FadeTransition(opacity: animacion, child: _GuiaInicio(pasos: visibles)),
      ),
    );
  } finally {
    _guiasEnCurso.remove(id);
  }
  if (guia == null || tambienInicio) {
    await sesion.guiaVista();
    try {
      await api.post('/api/cuenta/guia-vista', {});
    } catch (_) {
      // Sin conexion queda marcada en el telefono; el servidor la ofreceria en el proximo ingreso.
    }
  }
  if (guia != null) {
    await sesion.marcarGuia(guia);
    try {
      await api.post('/api/cuenta/guia-vista', {'guia': guia});
    } catch (_) {
      // Igual que la de inicio: queda marcada en el telefono.
    }
  }
}

/// El [MarcaGuia] con ese id esta dibujado.
bool marcaEnPantalla(String id) => MarcaGuia._marcas[id]?.mounted ?? false;

/// La guia [guia] falta y no esta abierta: la pantalla puede mostrarla.
bool guiaPendiente(BuildContext context, String guia) =>
    !_guiasEnCurso.contains(guia) && context.read<Sesion>().guiaPendiente(guia);

/// Rectangulo del widget del paso en la pantalla, o null si no esta dibujado (o queda fuera de ella).
Rect? _rectDe(PasoGuia paso, Rect pantalla) {
  final contexto = paso.clave?.currentContext ?? (paso.marca == null ? null : MarcaGuia._marcas[paso.marca]);
  if (contexto == null || !contexto.mounted) return null;
  final caja = contexto.findRenderObject();
  if (caja is! RenderBox || !caja.attached || !caja.hasSize) return null;
  final rect = caja.localToGlobal(Offset.zero) & caja.size;
  // Fuera de la pantalla (por ejemplo abajo en un panel que se desplaza) no se puede iluminar.
  if (rect.isEmpty || !pantalla.inflate(4).contains(rect.topLeft) || !pantalla.inflate(4).contains(rect.bottomRight)) {
    return null;
  }
  return rect;
}

class _GuiaInicio extends StatefulWidget {
  final List<PasoGuia> pasos;

  const _GuiaInicio({required this.pasos});

  @override
  State<_GuiaInicio> createState() => _GuiaInicioState();
}

class _GuiaInicioState extends State<_GuiaInicio> {
  static const _anchoCuadro = 310.0;
  static const _separacion = 16.0;
  int _indice = 0;

  bool get _ultimo => _indice == widget.pasos.length - 1;

  void _siguiente() {
    if (_ultimo) {
      Navigator.of(context).pop();
    } else {
      setState(() => _indice++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pantalla = MediaQuery.sizeOf(context);
    final paso = widget.pasos[_indice];
    final rect = _rectDe(paso, Offset.zero & pantalla);
    final objetivo = rect?.inflate(6) ?? Rect.fromCenter(center: pantalla.center(Offset.zero), width: 0, height: 0);

    final ancho = math.min(_anchoCuadro, pantalla.width - 32);
    final cuadro = _Cuadro(
      key: ValueKey(_indice),
      paso: paso,
      numero: _indice + 1,
      total: widget.pasos.length,
      ultimo: _ultimo,
      conFlecha: rect != null,
      flechaArriba: objetivo.center.dy <= pantalla.height / 2,
      flechaX: (objetivo.center.dx - (objetivo.center.dx - ancho / 2).clamp(16.0, pantalla.width - 16 - ancho))
          .clamp(22.0, ancho - 22),
      onSiguiente: _siguiente,
      onSaltar: () => Navigator.of(context).pop(),
    );
    final izquierda = (objetivo.center.dx - ancho / 2).clamp(16.0, pantalla.width - 16 - ancho);
    // El cuadro va del lado con mas espacio: arriba del objetivo si esta en la mitad de abajo.
    final arriba = objetivo.center.dy > pantalla.height / 2;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Tocar el boton iluminado tambien avanza.
              onTapUp: (d) {
                if (objetivo.contains(d.globalPosition)) _siguiente();
              },
              child: TweenAnimationBuilder<Rect?>(
                tween: RectTween(end: objetivo),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOut,
                builder: (_, rect, _) => CustomPaint(
                  painter: _Sombra(hueco: rect ?? objetivo, circulo: paso.circulo),
                ),
              ),
            ),
          ),
          if (rect == null)
            // Paso explicativo: el cuadro al centro, sin nada iluminado.
            Positioned.fill(
              child: Center(
                child: SizedBox(
                  width: ancho,
                  child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: cuadro),
                ),
              ),
            )
          else
            Positioned(
              left: izquierda,
              width: ancho,
              top: arriba ? null : objetivo.bottom + _separacion,
              bottom: arriba ? pantalla.height - objetivo.top + _separacion : null,
              child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: cuadro),
            ),
        ],
      ),
    );
  }
}

/// Fondo oscuro con el hueco del boton explicado y un borde blanco alrededor.
class _Sombra extends CustomPainter {
  final Rect hueco;
  final bool circulo;

  _Sombra({required this.hueco, required this.circulo});

  RRect get _forma {
    final radio = circulo ? hueco.shortestSide / 2 : 16.0;
    final rect = circulo ? Rect.fromCircle(center: hueco.center, radius: hueco.shortestSide / 2) : hueco;
    return RRect.fromRectAndRadius(rect, Radius.circular(radio));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fondo = Path()..addRect(Offset.zero & size);
    final agujero = Path()..addRRect(_forma);
    canvas.drawPath(
      Path.combine(PathOperation.difference, fondo, agujero),
      Paint()..color = const Color(0xB3061425),
    );
    // Paso explicativo (sin nada iluminado): sin borde.
    if (hueco.shortestSide < 2) return;
    canvas.drawRRect(
      _forma,
      Paint()
        ..color = ColoresApp.blanco.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_Sombra anterior) => anterior.hueco != hueco || anterior.circulo != circulo;
}

/// Cuadro blanco con la explicacion y la flecha que apunta al boton.
class _Cuadro extends StatelessWidget {
  final PasoGuia paso;
  final int numero;
  final int total;
  final bool ultimo;

  /// false en un paso explicativo (al centro): sin flecha y con el icono arriba.
  final bool conFlecha;
  final bool flechaArriba;
  final double flechaX;
  final VoidCallback onSiguiente;
  final VoidCallback onSaltar;

  const _Cuadro({
    super.key,
    required this.paso,
    required this.numero,
    required this.total,
    required this.ultimo,
    this.conFlecha = true,
    required this.flechaArriba,
    required this.flechaX,
    required this.onSiguiente,
    required this.onSaltar,
  });

  @override
  Widget build(BuildContext context) {
    final flecha = Padding(
      padding: EdgeInsets.only(left: flechaX - 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: CustomPaint(size: const Size(16, 9), painter: _Flecha(haciaArriba: flechaArriba)),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (conFlecha && flechaArriba) flecha,
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
          decoration: BoxDecoration(
            color: ColoresApp.blanco,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 6))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!conFlecha && paso.icono != null) ...[
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: ColoresApp.azulSuave, shape: BoxShape.circle),
                  child: Icon(paso.icono, color: ColoresApp.azul, size: 20),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                paso.titulo,
                style: const TextStyle(color: ColoresApp.tinta, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
              ),
              const SizedBox(height: 6),
              Text(paso.texto, style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 14, height: 1.35)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('$numero de $total', style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5)),
                  const Spacer(),
                  if (!ultimo)
                    TextButton(
                      onPressed: onSaltar,
                      style: TextButton.styleFrom(foregroundColor: ColoresApp.textoSuave),
                      child: const Text('Saltar'),
                    ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: onSiguiente,
                    style: FilledButton.styleFrom(
                      backgroundColor: ColoresApp.tinta,
                      foregroundColor: ColoresApp.blanco,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(ultimo ? 'Entendido' : 'Siguiente', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (conFlecha && !flechaArriba) flecha,
      ],
    );
  }
}

class _Flecha extends CustomPainter {
  final bool haciaArriba;

  _Flecha({required this.haciaArriba});

  @override
  void paint(Canvas canvas, Size size) {
    final path = haciaArriba
        ? (Path()
            ..moveTo(0, size.height)
            ..lineTo(size.width / 2, 0)
            ..lineTo(size.width, size.height))
        : (Path()
            ..moveTo(0, 0)
            ..lineTo(size.width / 2, size.height)
            ..lineTo(size.width, 0));
    canvas.drawPath(path..close(), Paint()..color = ColoresApp.blanco);
  }

  @override
  bool shouldRepaint(_Flecha anterior) => anterior.haciaArriba != haciaArriba;
}
