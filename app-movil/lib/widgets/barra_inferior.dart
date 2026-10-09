import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/tema.dart';

/// Opcion de la barra inferior.
class ItemBarra {
  /// Icono de linea (opcion inactiva) y relleno (activa), como la barra de pestanas de iOS.
  final IconData icono;
  final IconData iconoActivo;
  final String texto;

  /// Numero en rojo sobre el icono (por ejemplo solicitudes nuevas); null o 0 no se muestra.
  final int? insignia;

  /// Clave del boton, para ubicarlo en pantalla (guia de inicio).
  final Key? clave;

  const ItemBarra(this.icono, this.iconoActivo, this.texto, {this.insignia, this.clave});
}

/// Barra inferior flotante estilo iOS 26: capsula blanca translucida con desenfoque del fondo y la
/// opcion activa en azul marino sobre una pastilla clara. Mide lo que necesitan sus opciones y va
/// centrada (desde el rediseno no hay boton central: pedir y conectarse van en el panel de Inicio).
class BarraInferior extends StatelessWidget {
  final List<ItemBarra> items;
  final int indice;
  final ValueChanged<int> onCambiar;

  /// Alto de la barra sin el margen inferior del telefono.
  static const double alto = 72;

  /// Espacio que ocupa la barra desde el borde inferior: lo que el contenido debe dejar libre.
  static double espacio(BuildContext context) => alto + 16 + MediaQuery.paddingOf(context).bottom;

  const BarraInferior({super.key, required this.items, required this.indice, required this.onCambiar});

  Widget _opcion(int i) => _Opcion(key: items[i].clave, item: items[i], activo: i == indice, onTap: () => onCambiar(i));

  @override
  Widget build(BuildContext context) {
    final abajo = MediaQuery.paddingOf(context).bottom;
    final radio = BorderRadius.circular(alto / 2);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + abajo),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          // Unos 104 px por opcion: con 3 opciones a lo ancho del telefono quedaban muy separadas.
          constraints: BoxConstraints(maxWidth: items.length * 104.0 + 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radio,
              boxShadow: const [BoxShadow(color: Color(0x24000000), blurRadius: 24, offset: Offset(0, 8))],
            ),
            child: ClipRRect(
              borderRadius: radio,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: alto,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: ColoresApp.blanco.withValues(alpha: 0.86),
                    borderRadius: radio,
                    border: Border.all(color: const Color(0x14000000), width: 0.6),
                  ),
                  child: Row(
                    children: [for (var i = 0; i < items.length; i++) Expanded(child: _opcion(i))],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gris de los iconos y textos de la barra que no estan activos.
const _inactivo = Color(0xFF8E8E93);

class _Opcion extends StatelessWidget {
  final ItemBarra item;
  final bool activo;
  final VoidCallback onTap;

  const _Opcion({super.key, required this.item, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final insignia = item.insignia ?? 0;
    final color = activo ? ColoresApp.azul : _inactivo;
    return Semantics(
      selected: activo,
      button: true,
      label: item.texto,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: activo ? ColoresApp.azul.withValues(alpha: 0.09) : const Color(0x00000000),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: 34,
                    height: 27,
                    child: Center(child: Icon(activo ? item.iconoActivo : item.icono, size: 25, color: color)),
                  ),
                  if (insignia > 0)
                    Positioned(
                      right: -6,
                      top: -5,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: ColoresApp.rojo,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: ColoresApp.blanco, width: 1.5),
                        ),
                        child: Text(
                          insignia > 9 ? '9+' : '$insignia',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: ColoresApp.blanco, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: -0.1,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
