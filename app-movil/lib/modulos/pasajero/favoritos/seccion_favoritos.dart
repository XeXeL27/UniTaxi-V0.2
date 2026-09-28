import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/tema.dart';
import '../../../widgets/pagina_seccion.dart';
import 'favoritos_api.dart';

/// Seccion Favoritos de la barra inferior: los lugares guardados del pasajero. Tocar uno lo pone
/// como destino en el mapa; "Añadir lugar" vuelve al mapa para marcar el lugar nuevo.
class SeccionFavoritos extends StatelessWidget {
  final List<Favorito> favoritos;
  final bool cargando;
  final String? error;
  final ValueChanged<Favorito> onElegir;
  final ValueChanged<Favorito> onEliminar;
  final VoidCallback onAnadir;
  final VoidCallback onReintentar;

  const SeccionFavoritos({
    super.key,
    required this.favoritos,
    required this.cargando,
    required this.error,
    required this.onElegir,
    required this.onEliminar,
    required this.onAnadir,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return PaginaSeccion(
      titulo: 'Favoritos',
      subtitulo: 'Tus lugares guardados',
      constructor: (context, relleno) => ListView(
        padding: relleno,
        children: [
          const Text(
            'Toca un lugar para pedir un taxi hasta ahí',
            style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          ..._lista(),
          const SizedBox(height: 4),
          _BotonAnadir(onTap: onAnadir),
        ],
      ),
    );
  }

  List<Widget> _lista() {
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
        Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Aún no tienes lugares guardados. Guarda tu casa, tu universidad o los lugares a los que vas seguido.',
            style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13.5),
          ),
        ),
      ];
    }
    return [
      for (final favorito in favoritos)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TarjetaFavorito(
            favorito: favorito,
            onTap: () => onElegir(favorito),
            onEliminar: () => onEliminar(favorito),
          ),
        ),
    ];
  }
}

class _TarjetaFavorito extends StatelessWidget {
  final Favorito favorito;
  final VoidCallback onTap;
  final VoidCallback onEliminar;

  const _TarjetaFavorito({required this.favorito, required this.onTap, required this.onEliminar});

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
                child: Center(child: FaIcon(favorito.icono, color: ColoresApp.rojo, size: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      favorito.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColoresApp.azul, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      favorito.direccion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEliminar,
                tooltip: 'Eliminar',
                icon: const FaIcon(FontAwesomeIcons.trashCan, color: ColoresApp.textoSuave, size: 16),
              ),
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
    final borde = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)));
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
