import 'package:flutter/material.dart';
import '../core/iconos.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/avisos_admin.dart';

import '../core/menu.dart';
import '../core/tema.dart';

/// Menu lateral izquierdo con grupos desplegables por tipo.
class MenuLateral extends StatelessWidget {
  final String rutaActual;

  /// Dentro del drawer (pantallas angostas) se cierra al elegir una opcion.
  final bool enDrawer;

  const MenuLateral({super.key, required this.rutaActual, this.enDrawer = false});

  void _ir(BuildContext context, String ruta) {
    if (enDrawer) Navigator.of(context).pop();
    context.go(ruta);
  }

  /// Pendientes de una opcion del menu (por ahora solo Problemas de ingreso).
  static int _contador(ItemMenu item, AvisosAdmin avisos) =>
      item == Menu.problemasIngreso ? avisos.pendientesIngreso : 0;

  @override
  Widget build(BuildContext context) {
    final avisos = context.watch<AvisosAdmin>();
    // Material y no Container con color: los ListTile de los grupos pintan sus efectos de tinta
    // sobre el Material mas cercano y un ColoredBox intermedio los tapaba.
    return Material(
      color: ColoresApp.azul,
      child: SizedBox(
        width: enDrawer ? null : 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 70,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: ColoresApp.rojo, width: 3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconos.taxi, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'TAXIUAP ADMIN',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: 1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _OpcionMenu(
                    item: Menu.inicio,
                    activa: rutaActual == Menu.inicio.ruta,
                    alPresionar: () => _ir(context, Menu.inicio.ruta),
                  ),
                  for (final grupo in Menu.grupos) _grupo(context, grupo, avisos),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grupo(BuildContext context, GrupoMenu grupo, AvisosAdmin avisos) {
    final pendientes = grupo.items.fold<int>(0, (suma, i) => suma + _contador(i, avisos));
    final contieneActiva = grupo.items.any((i) => i.ruta == rutaActual);
    return Theme(
      // Quita las lineas que ExpansionTile dibuja al abrirse.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        // La clave cambia al entrar o salir del grupo: asi se abre solo al navegar a una de sus
        // opciones (initiallyExpanded solo se aplica al crear el widget).
        key: ValueKey('grupo_${grupo.titulo}_$contieneActiva'),
        initiallyExpanded: contieneActiva,
        tilePadding: const EdgeInsets.only(left: 24, right: 16),
        leading: SizedBox(
          width: 22,
          child: Center(child: Icon(grupo.icono, color: Colors.white, size: 16)),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                grupo.titulo,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            if (pendientes > 0) ...[const SizedBox(width: 8), _Contador(pendientes)],
          ],
        ),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white70,
        backgroundColor: const Color(0x14FFFFFF),
        childrenPadding: const EdgeInsets.only(bottom: 6),
        children: [
          for (final item in grupo.items)
            _OpcionMenu(
              item: item,
              activa: item.ruta == rutaActual,
              sangria: true,
              contador: _contador(item, avisos),
              alPresionar: () => _ir(context, item.ruta),
            ),
        ],
      ),
    );
  }
}

class _OpcionMenu extends StatelessWidget {
  final ItemMenu item;
  final bool activa;
  final bool sangria;
  final int contador;
  final VoidCallback alPresionar;

  const _OpcionMenu({
    required this.item,
    required this.activa,
    required this.alPresionar,
    this.sangria = false,
    this.contador = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activa ? const Color(0x1AFFFFFF) : Colors.transparent,
      child: InkWell(
        onTap: alPresionar,
        hoverColor: const Color(0x1AFFFFFF),
        child: Container(
          padding: EdgeInsets.fromLTRB(sangria ? 44 : 20, 13, 16, 13),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: activa ? ColoresApp.rojo : Colors.transparent, width: 4)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Center(child: Icon(item.icono, color: Colors.white, size: 15)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.titulo,
                  style: TextStyle(color: Colors.white, fontWeight: activa ? FontWeight.w600 : FontWeight.normal),
                ),
              ),
              if (contador > 0) ...[const SizedBox(width: 8), _Contador(contador)],
            ],
          ),
        ),
      ),
    );
  }
}

/// Numero rojo de pendientes junto a una opcion o un grupo del menu.
class _Contador extends StatelessWidget {
  final int cantidad;

  const _Contador(this.cantidad);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: ColoresApp.rojo, borderRadius: BorderRadius.circular(10)),
      child: Text(
        cantidad > 99 ? '99+' : '$cantidad',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}
