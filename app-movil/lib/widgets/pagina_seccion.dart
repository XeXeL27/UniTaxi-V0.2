import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/tema.dart';
import 'barra_inferior.dart';

/// Pagina de una seccion de la barra inferior (Historial, Favoritos, Mas): cabecera azul con el
/// titulo centrado y el contenido en una hoja clara con esquinas redondeadas que sube sobre ella.
///
/// En pantallas anchas el contenido se centra con un ancho maximo para que las tarjetas no se
/// estiren de lado a lado.
class PaginaSeccion extends StatelessWidget {
  final String titulo;
  final String subtitulo;

  /// Contenido desplazable de la seccion. Recibe el relleno inferior que deja libre la barra.
  final Widget Function(BuildContext context, EdgeInsets relleno) constructor;

  /// Boton opcional a la derecha de la cabecera.
  final Widget? accion;

  const PaginaSeccion({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.constructor,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    final relleno = EdgeInsets.fromLTRB(16, 20, 16, BarraInferior.espacio(context) + 16);
    return ColoredBox(
      color: ColoresApp.fondo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, arriba + 22, 12, 44),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF16386B), ColoresApp.azul],
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        titulo,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: ColoresApp.blanco, fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitulo,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ColoresApp.blanco.withValues(alpha: 0.78), fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 40, child: accion),
              ],
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                decoration: const BoxDecoration(
                  color: ColoresApp.fondo,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: constructor(context, relleno),
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

/// Tarjeta blanca de una opcion de la pantalla Mas: icono en circulo de color, titulo, detalle y
/// a la derecha una flecha o un control (interruptor).
class TarjetaOpcion extends StatelessWidget {
  final FaIconData icono;
  final String titulo;
  final String detalle;
  final Color color;
  final VoidCallback? onTap;
  final Widget? derecha;

  const TarjetaOpcion({
    super.key,
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.color = ColoresApp.azul,
    this.onTap,
    this.derecha,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ColoresApp.borde),
              boxShadow: const [BoxShadow(color: Color(0x0D0A2342), blurRadius: 10, offset: Offset(0, 3))],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Center(child: FaIcon(icono, color: color, size: 20)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(detalle, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13.5, height: 1.3)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                derecha ?? const FaIcon(FontAwesomeIcons.chevronRight, color: ColoresApp.textoSuave, size: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
