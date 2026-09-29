import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../core/tema.dart';
import 'favoritos_api.dart';
import 'lugares_frecuentes.dart';

/// Pestaña Favoritos de la sección Viajes: los lugares que el pasajero guardó a mano y los que se
/// deducen de sus viajes. Ya no lleva cabecera propia (la de la sección la pone PaginaSeccion), así
/// que devuelve solo la lista con el relleno que le pasa la sección.
///
/// Tocar un lugar lo pone como destino en el mapa; "Añadir lugar" vuelve al mapa para marcar uno
/// nuevo; el botón de un lugar frecuente lo guarda como favorito de verdad.
class SeccionFavoritos extends StatelessWidget {
  final List<Favorito> favoritos;
  final List<LugarFrecuente> frecuentes;
  final bool cargando;
  final String? error;

  /// Poner un lugar como destino en el mapa. Lo usan los dos grupos: un favorito guardado y uno
  /// deducido de los viajes son el mismo destino, solo cambia de dónde salieron.
  final void Function(LatLng posicion, String nombre) onElegir;

  final ValueChanged<Favorito> onEliminar;
  final ValueChanged<LugarFrecuente> onPromover;

  /// Quita un lugar frecuente de la lista (no esta guardado: solo deja de mostrarse).
  final ValueChanged<LugarFrecuente> onQuitarFrecuente;
  final VoidCallback onAnadir;
  final VoidCallback onReintentar;

  /// Relleno que deja PaginaSeccion para el contenido de la pestaña.
  final EdgeInsets relleno;

  const SeccionFavoritos({
    super.key,
    required this.favoritos,
    required this.frecuentes,
    required this.cargando,
    required this.error,
    required this.onElegir,
    required this.onEliminar,
    required this.onPromover,
    required this.onQuitarFrecuente,
    required this.onAnadir,
    required this.onReintentar,
    required this.relleno,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: relleno,
      children: [
        _EncabezadoGrupo(
          titulo: 'Tus favoritos',
          detalle: favoritos.length == 1 ? '1 lugar guardado' : '${favoritos.length} lugares guardados',
        ),
        const SizedBox(height: 10),
        ..._bloqueFavoritos(),
        const SizedBox(height: 22),
        // Sin lugares frecuentes (pocos viajes, todos cancelados, o el historial no cargó) el
        // grupo no aparece: el de favoritos de arriba sigue siendo válido.
        if (frecuentes.isNotEmpty) ...[
          const _EncabezadoGrupo(titulo: 'Lugares frecuentes', detalle: 'A dónde vas una y otra vez'),
          const SizedBox(height: 10),
          for (final lugar in frecuentes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TarjetaFrecuente(
                lugar: lugar,
                onElegir: onElegir,
                onPromover: () => onPromover(lugar),
                onQuitar: () => onQuitarFrecuente(lugar),
              ),
            ),
        ],
        const SizedBox(height: 4),
        _BotonAnadir(onTap: onAnadir),
      ],
    );
  }

  List<Widget> _bloqueFavoritos() {
    if (cargando) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(color: ColoresApp.azul)),
        ),
      ];
    }
    if (error != null) {
      return [
        Text(error!, style: const TextStyle(color: ColoresApp.rojo)),
        TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
        const SizedBox(height: 8),
      ];
    }
    if (favoritos.isEmpty) {
      return const [
        Text(
          'Toca un lugar para pedir un taxi hasta ahí. Guarda tu casa, tu universidad o los sitios '
          'a los que vas seguido.',
          style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13.5, height: 1.4),
        ),
      ];
    }
    return [
      for (final favorito in favoritos)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TarjetaFavorito(favorito: favorito, onElegir: onElegir, onEliminar: () => onEliminar(favorito)),
        ),
    ];
  }
}

/// Titulo de cada grupo de la lista, con su detalle en gris debajo.
class _EncabezadoGrupo extends StatelessWidget {
  final String titulo;
  final String detalle;

  const _EncabezadoGrupo({required this.titulo, required this.detalle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(color: ColoresApp.azul, fontSize: 16.5, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(detalle, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13)),
      ],
    );
  }
}

class _TarjetaFavorito extends StatelessWidget {
  final Favorito favorito;
  final void Function(LatLng posicion, String nombre) onElegir;
  final VoidCallback onEliminar;

  const _TarjetaFavorito({required this.favorito, required this.onElegir, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    // Un favorito sin posicion no se puede poner como destino (no se sabe a dónde ir).
    final posicion = favorito.posicion;
    return _Tarjeta(
      icono: favorito.icono,
      titulo: favorito.nombre,
      detalle: favorito.direccion,
      onTap: posicion == null ? null : () => onElegir(posicion, favorito.nombre),
      accion: IconButton(
        onPressed: onEliminar,
        tooltip: 'Eliminar',
        icon: const FaIcon(FontAwesomeIcons.trashCan, color: ColoresApp.textoSuave, size: 16),
      ),
    );
  }
}

/// Lugar deducido de los viajes. A diferencia de un favorito, no está guardado en el backend, así
/// que el botón de la derecha lo guarda de verdad.
class _TarjetaFrecuente extends StatelessWidget {
  final LugarFrecuente lugar;
  final void Function(LatLng posicion, String nombre) onElegir;
  final VoidCallback onPromover;
  final VoidCallback onQuitar;

  const _TarjetaFrecuente({
    required this.lugar,
    required this.onElegir,
    required this.onPromover,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      icono: FontAwesomeIcons.clockRotateLeft,
      titulo: lugar.nombre,
      detalle: lugar.resumen,
      onTap: () => onElegir(lugar.posicion, lugar.nombre),
      accion: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onPromover,
            tooltip: 'Agregar a favoritos',
            icon: const FaIcon(FontAwesomeIcons.plus, color: ColoresApp.azul, size: 16),
          ),
          IconButton(
            onPressed: onQuitar,
            tooltip: 'Quitar de la lista',
            icon: const FaIcon(FontAwesomeIcons.trashCan, color: ColoresApp.textoSuave, size: 16),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta blanca de un lugar, con el icono en circulo, el nombre, el detalle y una accion a la
/// derecha. La comparten los dos grupos.
class _Tarjeta extends StatelessWidget {
  final FaIconData icono;
  final String titulo;
  final String detalle;

  /// Null cuando el lugar no se puede usar como destino (un favorito sin posicion).
  final VoidCallback? onTap;

  final Widget accion;

  const _Tarjeta({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onTap,
    required this.accion,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColoresApp.blanco,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: ColoresApp.borde),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: ColoresApp.rojoSuave, shape: BoxShape.circle),
                child: Center(child: FaIcon(icono, color: ColoresApp.rojo, size: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColoresApp.azul, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
                    ),
                  ],
                ),
              ),
              accion,
            ],
          ),
        ),
      ),
    );
  }
}

/// Boton "Añadir lugar" con borde punteado azul marino.
class _BotonAnadir extends StatelessWidget {
  final VoidCallback onTap;

  const _BotonAnadir({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BordePunteado(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              FaIcon(FontAwesomeIcons.plus, color: ColoresApp.azul, size: 20),
              SizedBox(height: 8),
              Text(
                'Añadir lugar',
                style: TextStyle(color: ColoresApp.azul, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BordePunteado extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pintura = Paint()
      ..color = ColoresApp.azul
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final borde = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)));
    const trazo = 6.0;
    const hueco = 4.0;
    for (final metrica in borde.computeMetrics()) {
      var distancia = 0.0;
      while (distancia < metrica.length) {
        canvas.drawPath(metrica.extractPath(distancia, distancia + trazo), pintura);
        distancia += trazo + hueco;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
