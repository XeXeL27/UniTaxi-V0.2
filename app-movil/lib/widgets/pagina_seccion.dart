import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

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

/// Tarjeta blanca de una opcion de la pantalla Perfil, estilo Ajustes de iOS: icono blanco en un
/// cuadro redondeado de color, titulo, detalle y a la derecha una flecha o un control (interruptor).
class TarjetaOpcion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final Color color;
  final VoidCallback? onTap;
  final Widget? derecha;

  /// Accion que saca de la cuenta (cerrar sesion): el titulo va en rojo, como en iOS.
  final bool destructiva;

  const TarjetaOpcion({
    super.key,
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.color = ColoresApp.azul,
    this.onTap,
    this.derecha,
    this.destructiva = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(22),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 14, offset: Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(11)),
                  child: Center(child: Icon(icono, color: ColoresApp.blanco, size: 22)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          color: destructiva ? ColoresApp.rojo : ColoresApp.tinta,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(detalle, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13.5, height: 1.3)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                derecha ?? const Icon(CupertinoIcons.chevron_forward, color: Color(0xFFC4C4C7), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
