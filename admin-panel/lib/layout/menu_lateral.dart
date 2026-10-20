import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/avisos_admin.dart';
import '../core/iconos.dart';
import '../core/menu.dart';
import '../core/relieve.dart';
import '../core/tema.dart';

/// Menu lateral izquierdo con grupos desplegables por tipo. Los grupos se abren con animacion (la
/// flecha gira y sus opciones entran una tras otra deslizandose); la opcion activa es una pildora
/// blanca levantada y las demas se corren un poco a la derecha con el mouse encima.
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
    // Material y no Container con color: las opciones pintan sus efectos de tinta sobre el Material
    // mas cercano y un ColoredBox intermedio los tapaba.
    return Material(
      color: ColoresApp.azul,
      child: Container(
        width: enDrawer ? null : 260,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF15346A), ColoresApp.azul, Color(0xFF0A1F42)],
            stops: [0, 0.45, 1],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 70,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1F4280), Color(0xFF12305F)],
                ),
                border: Border(bottom: BorderSide(color: ColoresApp.rojo, width: 3)),
                boxShadow: [BoxShadow(color: Color(0x59000000), offset: Offset(0, 3), blurRadius: 8)],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconos.taxi, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'TAXIUAP ADMIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: 1,
                      shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 2)],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  _OpcionMenu(
                    item: Menu.inicio,
                    activa: rutaActual == Menu.inicio.ruta,
                    alPresionar: () => _ir(context, Menu.inicio.ruta),
                  ),
                  for (final grupo in Menu.grupos)
                    _GrupoMenu(
                      grupo: grupo,
                      rutaActual: rutaActual,
                      pendientes: grupo.items.fold<int>(0, (suma, i) => suma + _contador(i, avisos)),
                      opcion: (item) => _OpcionMenu(
                        item: item,
                        activa: item.ruta == rutaActual,
                        sangria: true,
                        contador: _contador(item, avisos),
                        alPresionar: () => _ir(context, item.ruta),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grupo desplegable del menu. Se abre solo al navegar a una de sus opciones.
class _GrupoMenu extends StatefulWidget {
  final GrupoMenu grupo;
  final String rutaActual;
  final int pendientes;
  final Widget Function(ItemMenu item) opcion;

  const _GrupoMenu({required this.grupo, required this.rutaActual, required this.pendientes, required this.opcion});

  @override
  State<_GrupoMenu> createState() => _GrupoMenuState();
}

class _GrupoMenuState extends State<_GrupoMenu> with SingleTickerProviderStateMixin {
  late final AnimationController _apertura = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 260 + 45 * widget.grupo.items.length),
    value: _contieneActiva ? 1 : 0,
  );
  bool _encima = false;

  bool get _contieneActiva => widget.grupo.items.any((i) => i.ruta == widget.rutaActual);
  bool get _abierto => _apertura.status == AnimationStatus.forward || _apertura.status == AnimationStatus.completed;

  @override
  void didUpdateWidget(_GrupoMenu anterior) {
    super.didUpdateWidget(anterior);
    final antes = anterior.grupo.items.any((i) => i.ruta == anterior.rutaActual);
    if (_contieneActiva && !antes) _apertura.forward();
  }

  @override
  void dispose() {
    _apertura.dispose();
    super.dispose();
  }

  void _alternar() => setState(() => _abierto ? _apertura.reverse() : _apertura.forward());

  @override
  Widget build(BuildContext context) {
    final items = widget.grupo.items;
    final tamano = CurvedAnimation(parent: _apertura, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return AnimatedBuilder(
      animation: _apertura,
      builder: (context, _) {
        final abierto = _apertura.value > 0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: abierto ? const Color(0x14FFFFFF) : (_encima ? const Color(0x0DFFFFFF) : Colors.transparent),
            border: Border.all(color: abierto ? const Color(0x1AFFFFFF) : Colors.transparent),
            boxShadow: abierto
                ? const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 4), blurRadius: 10, spreadRadius: -4)]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _encima = true),
                onExit: (_) => setState(() => _encima = false),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _alternar,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          child: Center(child: Icon(widget.grupo.icono, color: Colors.white, size: 16)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            widget.grupo.titulo,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5),
                          ),
                        ),
                        if (widget.pendientes > 0) ...[_Contador(widget.pendientes), const SizedBox(width: 8)],
                        RotationTransition(
                          turns: Tween(begin: 0.0, end: 0.5).animate(tamano),
                          child: Icon(Iconos.chevronDown, size: 15, color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ClipRect(
                child: SizeTransition(
                  sizeFactor: tamano,
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < items.length; i++)
                          _Escalonado(
                            animacion: _apertura,
                            indice: i,
                            total: items.length,
                            child: widget.opcion(items[i]),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Cada opcion de un grupo entra un poco despues de la anterior, desde la izquierda y apareciendo.
class _Escalonado extends StatelessWidget {
  final Animation<double> animacion;
  final int indice;
  final int total;
  final Widget child;

  const _Escalonado({required this.animacion, required this.indice, required this.total, required this.child});

  @override
  Widget build(BuildContext context) {
    final paso = total <= 1 ? 0.0 : 0.45 / (total - 1);
    final inicio = (indice * paso).clamp(0.0, 0.45);
    final fin = (inicio + 0.55).clamp(0.0, 1.0);
    const salida = Interval(0, 0.6, curve: Curves.easeIn);
    // La opacidad no puede pasar de 1: el rebote va solo en el deslizamiento.
    final aparece = CurvedAnimation(
      parent: animacion,
      curve: Interval(inicio, fin, curve: Curves.easeOut),
      reverseCurve: salida,
    );
    final desliza = CurvedAnimation(
      parent: animacion,
      curve: Interval(inicio, fin, curve: Curves.easeOutBack),
      reverseCurve: salida,
    );
    return FadeTransition(
      opacity: aparece,
      child: SlideTransition(
        position: desliza.drive(Tween(begin: const Offset(-0.18, 0), end: Offset.zero)),
        child: child,
      ),
    );
  }
}

class _OpcionMenu extends StatefulWidget {
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
  State<_OpcionMenu> createState() => _OpcionMenuState();
}

class _OpcionMenuState extends State<_OpcionMenu> {
  bool _encima = false;
  bool _presionada = false;

  @override
  Widget build(BuildContext context) {
    final activa = widget.activa;
    final color = activa ? ColoresApp.azul : Colors.white;
    // La opcion activa es una pildora blanca levantada, como el menu de la guia relieve; las demas se
    // corren a la derecha y se iluminan con el mouse encima.
    final desplazamiento = activa ? 0.0 : (_presionada ? 2.0 : (_encima ? 6.0 : 0.0));
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 2, widget.sangria ? 6 : 10, 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _encima = true),
        onExit: (_) => setState(() {
          _encima = false;
          _presionada = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _presionada = true),
          onTapCancel: () => setState(() => _presionada = false),
          onTapUp: (_) => setState(() => _presionada = false),
          onTap: widget.alPresionar,
          child: Semantics(
            button: true,
            selected: activa,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(desplazamiento, activa && _presionada ? 1 : 0, 0),
              padding: EdgeInsets.fromLTRB(widget.sangria ? 22 : 12, 11, 10, 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: activa
                    ? Relieve.levantado
                    : LinearGradient(
                        colors: _encima
                            ? const [Color(0x2EFFFFFF), Color(0x0DFFFFFF)]
                            : const [Color(0x00FFFFFF), Color(0x00FFFFFF)],
                      ),
                border: Border(
                  left: BorderSide(
                    color: activa ? ColoresApp.rojo : (_encima ? const Color(0x99FFFFFF) : Colors.transparent),
                    width: 3,
                  ),
                ),
                boxShadow: activa
                    ? const [
                        BoxShadow(color: Color(0x4D000000), offset: Offset(0, 2), blurRadius: 4),
                        BoxShadow(color: Color(0x40000000), offset: Offset(0, 8), blurRadius: 14, spreadRadius: -4),
                      ]
                    : const [],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Center(
                      child: AnimatedScale(
                        scale: _encima && !activa ? 1.18 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(widget.item.icono, color: activa ? ColoresApp.rojo : color, size: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.item.titulo,
                      style: TextStyle(color: color, fontWeight: activa ? FontWeight.w700 : FontWeight.w500),
                    ),
                  ),
                  if (widget.contador > 0) ...[const SizedBox(width: 8), _Contador(widget.contador)],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Numero rojo de pendientes junto a una opcion o un grupo del menu, con relieve.
class _Contador extends StatelessWidget {
  final int cantidad;

  const _Contador(this.cantidad);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Relieve.aclarar(ColoresApp.rojo, 0.15), ColoresApp.rojo],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4)],
      ),
      child: Text(
        cantidad > 99 ? '99+' : '$cantidad',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}
