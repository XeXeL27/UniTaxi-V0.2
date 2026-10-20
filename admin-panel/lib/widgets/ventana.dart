import 'package:flutter/material.dart';

import '../core/iconos.dart';
import '../core/relieve.dart';
import '../core/tema.dart';
import 'dialogo_animado.dart';

/// Ventana del estilo relieve (titlebar + cuerpo + pie): la usan los formularios en modal, el modal
/// de cada registro y los detalles. En celular ocupa toda la pantalla; en escritorio queda centrada
/// con [anchoMaximo] y como mucho [altoMaximo] de la pantalla.
Future<R?> mostrarVentana<R>(
  BuildContext context, {
  required WidgetBuilder builder,
  double anchoMaximo = 560,
  double altoMaximo = 0.9,
  bool cierraAlTocarFuera = true,
}) {
  return mostrarDialogo<R>(
    context: context,
    barrierDismissible: cierraAlTocarFuera,
    barrierColor: const Color(0x661F2733),
    builder: (context) => MarcoVentana(anchoMaximo: anchoMaximo, altoMaximo: altoMaximo, child: builder(context)),
  );
}

/// Borde, fondo y sombra de la ventana; en celular, pantalla completa.
class MarcoVentana extends StatelessWidget {
  final double anchoMaximo;
  final double altoMaximo;
  final Widget child;

  const MarcoVentana({super.key, this.anchoMaximo = 560, this.altoMaximo = 0.9, required this.child});

  @override
  Widget build(BuildContext context) {
    if (Pantalla.esMovil(context)) {
      return Dialog.fullscreen(
        backgroundColor: Relieve.superficie,
        child: SafeArea(child: child),
      );
    }
    final alto = MediaQuery.sizeOf(context).height * altoMaximo;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.none,
      child: Container(
        constraints: BoxConstraints(maxWidth: anchoMaximo, maxHeight: alto),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8F9FB), Relieve.superficie],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Relieve.linea),
          boxShadow: Relieve.sombraVentana,
        ),
        child: child,
      ),
    );
  }
}

/// Cabecera de la ventana: icono, titulo (y subtitulo), la X para cerrar y, debajo, los botones de
/// la ventana en una fila que baja a otra linea si no entran (nunca se desplaza de costado).
class CabeceraVentana extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final Widget? insignia;
  final List<Widget> botones;
  final VoidCallback? alCerrar;

  const CabeceraVentana({
    super.key,
    required this.icono,
    required this.titulo,
    this.subtitulo,
    this.insignia,
    this.botones = const [],
    this.alCerrar,
  });

  @override
  Widget build(BuildContext context) {
    final movil = Pantalla.esMovil(context);
    return Container(
      padding: EdgeInsets.fromLTRB(movil ? 16 : 20, 14, 10, botones.isEmpty ? 14 : 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDFDFE), Color(0xFFE6E9EE)],
        ),
        border: Border(bottom: BorderSide(color: Relieve.linea)),
        boxShadow: [BoxShadow(color: Relieve.sombraSuave, offset: Offset(0, 2), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: Relieve.levantado,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Relieve.linea),
                  boxShadow: Relieve.sombraLevantado,
                ),
                child: Icon(icono, color: ColoresApp.azul, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ColoresApp.azul),
                    ),
                    if (subtitulo != null && subtitulo!.isNotEmpty)
                      Text(
                        subtitulo!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Relieve.tenue, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
              ),
              if (insignia != null) ...[const SizedBox(width: 8), insignia!],
              if (alCerrar != null)
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: alCerrar,
                  icon: const Icon(Iconos.xmark, size: 18, color: Relieve.tenue),
                ),
            ],
          ),
          if (botones.isNotEmpty) ...[const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: botones)],
        ],
      ),
    );
  }
}

/// Pie de la ventana con los botones a la derecha.
class PieVentana extends StatelessWidget {
  final List<Widget> children;

  const PieVentana({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEDEFF2), Relieve.superficie],
        ),
        border: Border(top: BorderSide(color: Relieve.linea)),
      ),
      child: Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 8, children: children),
    );
  }
}

/// Aviso de color con borde izquierdo (alerta de la guia): error, advertencia o informacion.
class AlertaRelieve extends StatelessWidget {
  final String titulo;
  final String? texto;
  final Color color;
  final IconData icono;

  const AlertaRelieve({super.key, required this.titulo, this.texto, required this.color, required this.icono});

  const AlertaRelieve.error({super.key, required this.titulo, this.texto})
    : color = const Color(0xFFC8243F),
      icono = Iconos.circleExclamation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Relieve.aclarar(color, 0.94), Relieve.aclarar(color, 0.88)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: color, width: 4),
          top: BorderSide(color: Relieve.aclarar(color, 0.65)),
          right: BorderSide(color: Relieve.aclarar(color, 0.65)),
          bottom: BorderSide(color: Relieve.aclarar(color, 0.65)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(fontWeight: FontWeight.w700, color: Relieve.aclarar(color, -0.35)),
                ),
                if (texto != null && texto!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(texto!, style: TextStyle(color: Relieve.aclarar(color, -0.35), height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
