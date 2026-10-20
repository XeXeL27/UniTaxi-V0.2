import 'package:flutter/material.dart';

import '../core/iconos.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/avisos_admin.dart';

import '../core/menu.dart';
import '../core/sesion.dart';
import '../core/relieve.dart';
import '../core/tema.dart';
import '../widgets/boton_relieve.dart';

/// Barra superior fija: boton para mostrar/esconder el menu, titulo de la pantalla, datos del
/// administrador y cierre de sesion.
class BarraSuperior extends StatelessWidget {
  final String rutaActual;
  final bool menuVisible;
  final VoidCallback alAlternarMenu;

  const BarraSuperior({super.key, required this.rutaActual, required this.menuVisible, required this.alAlternarMenu});

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<Sesion>();
    final usuario = sesion.usuario;
    final movil = Pantalla.esMovil(context);
    final titulo = Menu.porRuta(rutaActual)?.titulo ?? 'Panel principal';

    return Container(
      height: movil ? 60 : 70,
      padding: EdgeInsets.symmetric(horizontal: movil ? 8 : 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDFDFE), Color(0xFFE8EBEF)],
        ),
        border: Border(bottom: BorderSide(color: Relieve.linea)),
        boxShadow: [
          BoxShadow(color: Relieve.sombra, offset: Offset(0, 1), blurRadius: 2),
          BoxShadow(color: Relieve.sombra, offset: Offset(0, 4), blurRadius: 8, spreadRadius: -2),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: menuVisible ? 'Ocultar menú' : 'Mostrar menú',
            onPressed: alAlternarMenu,
            icon: const Icon(Iconos.bars, color: ColoresApp.azul, size: 20),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              titulo,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ColoresApp.azul),
            ),
          ),
          const _CampanaAvisos(),
          SizedBox(width: movil ? 0 : 8),
          if (!movil && usuario != null) ...[
            Text(
              usuario.nombreCompleto,
              style: const TextStyle(fontWeight: FontWeight.bold, color: ColoresApp.azul),
            ),
            const SizedBox(width: 12),
          ],
          Tooltip(
            message: usuario?.correo ?? usuario?.telefono ?? '',
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2A4C85), ColoresApp.azul],
                ),
                shape: BoxShape.circle,
                boxShadow: Relieve.sombraLevantado,
              ),
              child: Text(
                usuario?.iniciales ?? '',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 8),
          movil
              ? IconButton(
                  tooltip: 'Cerrar sesion',
                  onPressed: sesion.cerrar,
                  icon: const Icon(Iconos.powerOff, color: ColoresApp.rojo, size: 18),
                )
              : BotonRelieve(
                  texto: 'Cerrar sesión',
                  icono: Iconos.powerOff,
                  tono: TonoBoton.rojo,
                  tamano: TamanoBoton.pequeno,
                  alPresionar: sesion.cerrar,
                ),
        ],
      ),
    );
  }
}

/// Campana de la barra superior con los mensajes de "Problemas de ingreso" sin atender. Cuando llega uno
/// nuevo avisa abajo con "Ver"; tocarla abre la seccion.
class _CampanaAvisos extends StatefulWidget {
  const _CampanaAvisos();

  @override
  State<_CampanaAvisos> createState() => _CampanaAvisosState();
}

class _CampanaAvisosState extends State<_CampanaAvisos> {
  late final AvisosAdmin _avisos = context.read<AvisosAdmin>();
  late int _anterior = _avisos.pendientesIngreso;

  @override
  void initState() {
    super.initState();
    _avisos.addListener(_alCambiar);
  }

  @override
  void dispose() {
    _avisos.removeListener(_alCambiar);
    super.dispose();
  }

  void _alCambiar() {
    final actual = _avisos.pendientesIngreso;
    final nuevos = actual - _anterior;
    _anterior = actual;
    if (!mounted) return;
    setState(() {});
    if (nuevos <= 0) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        backgroundColor: ColoresApp.azul,
        duration: const Duration(seconds: 8),
        content: Text(
          nuevos == 1
              ? 'Nuevo mensaje de alguien que no puede ingresar a su cuenta.'
              : '$nuevos mensajes nuevos de personas que no pueden ingresar a su cuenta.',
        ),
        action: SnackBarAction(
          label: 'Ver',
          textColor: Colors.white,
          onPressed: () => context.go(Menu.problemasIngreso.ruta),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = _avisos.pendientesIngreso;
    return IconButton(
      tooltip: pendientes == 0 ? 'Sin mensajes de ingreso pendientes' : 'Problemas de ingreso: $pendientes sin atender',
      onPressed: () => context.go(Menu.problemasIngreso.ruta),
      icon: Badge(
        isLabelVisible: pendientes > 0,
        backgroundColor: ColoresApp.rojo,
        label: Text(pendientes > 99 ? '99+' : '$pendientes'),
        child: const Icon(Iconos.bell, color: ColoresApp.azul, size: 20),
      ),
    );
  }
}
