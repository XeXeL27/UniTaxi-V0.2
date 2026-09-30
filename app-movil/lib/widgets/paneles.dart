import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/tema.dart';

/// Panel blanco inferior con esquinas redondeadas y sombra, sobre el mapa.
///
/// [flotante]: tarjeta separada de los bordes, encima de la barra inferior (pantalla de inicio);
/// en pantallas anchas no pasa de [anchoMaximo].
class PanelInferior extends StatelessWidget {
  final Widget child;

  /// Alto maximo como fraccion de la pantalla; el contenido se desplaza si no entra.
  final double altoMaximo;
  final bool flotante;
  static const double anchoMaximo = 560;

  const PanelInferior({
    super.key,
    required this.child,
    this.altoMaximo = 0.62,
    this.flotante = false,
  });

  @override
  Widget build(BuildContext context) {
    final medidas = MediaQuery.of(context);
    final panel = ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: medidas.size.height * altoMaximo,
        maxWidth: flotante ? anchoMaximo : double.infinity,
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: ColoresApp.blanco,
          borderRadius: flotante ? BorderRadius.circular(22) : const BorderRadius.vertical(top: Radius.circular(20)),
          border: flotante
              ? Border.all(color: ColoresApp.borde)
              : const Border(top: BorderSide(color: ColoresApp.borde)),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, -4))],
        ),
        clipBehavior: flotante ? Clip.antiAlias : Clip.none,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            18 + (flotante ? 0 : medidas.padding.bottom),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      ),
    );
    if (!flotante) return panel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(heightFactor: 1, child: panel),
    );
  }
}

/// Fila de un lugar del viaje: punto de color, etiqueta pequena y la direccion.
class FilaLugar extends StatelessWidget {
  final Color color;
  final Color colorSuave;
  final String etiqueta;
  final String texto;
  final Widget? accion;

  const FilaLugar({
    super.key,
    required this.color,
    required this.colorSuave,
    required this.etiqueta,
    required this.texto,
    this.accion,
  });

  const FilaLugar.partida({super.key, required this.texto, this.etiqueta = 'Punto de partida (A)', this.accion})
    : color = ColoresApp.azul,
      colorSuave = ColoresApp.azulSuave;

  const FilaLugar.destino({super.key, required this.texto, this.etiqueta = 'Destino (B)', this.accion})
    : color = ColoresApp.rojo,
      colorSuave = ColoresApp.rojoSuave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: colorSuave, width: 4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: const TextStyle(fontSize: 12, color: ColoresApp.textoSuave, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  texto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, color: ColoresApp.texto),
                ),
              ],
            ),
          ),
          ?accion,
        ],
      ),
    );
  }
}

/// Recuadro con el precio del viaje, destacado.
class RecuadroPrecio extends StatelessWidget {
  final String etiqueta;
  final String monto;
  final String? detalle;

  const RecuadroPrecio({super.key, required this.etiqueta, required this.monto, this.detalle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ColoresApp.fondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: Row(
        children: [
          const FaIcon(FontAwesomeIcons.moneyBillWave, color: ColoresApp.exito, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5)),
                if (detalle != null) Text(detalle!, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12)),
              ],
            ),
          ),
          Text(
            monto,
            style: const TextStyle(color: ColoresApp.azul, fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Dato corto con icono (distancia, tiempo).
class DatoRuta extends StatelessWidget {
  final FaIconData icono;
  final String texto;

  const DatoRuta({super.key, required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FaIcon(icono, color: ColoresApp.ruta, size: 14),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(color: ColoresApp.texto, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Estrellas de calificacion (solo lectura), con medias estrellas.
class Estrellas extends StatelessWidget {
  final double valor;
  final double tamano;

  const Estrellas({super.key, required this.valor, this.tamano = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: FaIcon(
              valor >= i
                  ? FontAwesomeIcons.solidStar
                  : valor >= i - 0.5
                  ? FontAwesomeIcons.starHalfStroke
                  : FontAwesomeIcons.star,
              color: const Color(0xFFF5A623),
              size: tamano,
            ),
          ),
      ],
    );
  }
}

/// Circulo con las iniciales de una persona.
class AvatarIniciales extends StatelessWidget {
  final String nombre;
  final double radio;
  final Color color;

  const AvatarIniciales({super.key, required this.nombre, this.radio = 24, this.color = ColoresApp.azul});

  @override
  Widget build(BuildContext context) {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final iniciales = partes.take(2).map((p) => p[0].toUpperCase()).join();
    return CircleAvatar(
      radius: radio,
      backgroundColor: color,
      child: Text(
        iniciales,
        style: TextStyle(color: ColoresApp.blanco, fontSize: radio * 0.7, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Panel que se puede bajar para ver el mapa completo con la ruta (solicitud y viaje del pasajero,
/// detalle de solicitud y viaje del conductor). Cerrado queda solo una barra con el resumen;
/// tocarla, la flecha o deslizar hacia arriba lo vuelve a abrir con el detalle.
class PanelPlegable extends StatelessWidget {
  final bool abierto;
  final VoidCallback onAlternar;
  final FaIconData icono;
  final Color color;

  /// Lo que se ve con el panel cerrado (por ejemplo "Buscando conductor...").
  final String resumen;

  /// Texto de la barra con el panel abierto.
  final String tituloAbierto;
  final Widget child;

  /// Lo que sigue visible con el panel cerrado debajo del resumen (por ejemplo el boton del
  /// siguiente paso del conductor), para no tener que abrirlo.
  final Widget? accionPlegado;

  const PanelPlegable({
    super.key,
    required this.abierto,
    required this.onAlternar,
    required this.icono,
    required this.color,
    required this.resumen,
    required this.tituloAbierto,
    required this.child,
    this.accionPlegado,
  });

  @override
  Widget build(BuildContext context) {
    final barra = Semantics(
      button: true,
      label: abierto ? 'Esconder detalle y ver el mapa' : 'Ver detalle',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onAlternar,
        onVerticalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if ((abierto && v > 150) || (!abierto && v < -150)) onAlternar();
        },
        child: Row(
          children: [
            if (!abierto) ...[FaIcon(icono, color: color, size: 16), const SizedBox(width: 10)],
            Expanded(
              child: Text(
                abierto ? tituloAbierto : resumen,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: abierto
                    ? const TextStyle(color: ColoresApp.textoSuave, fontSize: 13, fontWeight: FontWeight.w600)
                    : TextStyle(color: color, fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: onAlternar,
              tooltip: abierto ? 'Ver el mapa completo' : 'Ver detalle',
              style: IconButton.styleFrom(backgroundColor: ColoresApp.azulSuave),
              icon: AnimatedRotation(
                turns: abierto ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const FaIcon(FontAwesomeIcons.chevronUp, color: ColoresApp.azul, size: 15),
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        barra,
        if (abierto) ...[const SizedBox(height: 8), child],
        if (!abierto && accionPlegado != null) ...[const SizedBox(height: 8), accionPlegado!],
      ],
    );
  }
}
