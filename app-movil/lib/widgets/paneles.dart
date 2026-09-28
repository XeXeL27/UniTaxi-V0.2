import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/tema.dart';

/// Cabecera azul marino con el saludo, el boton del menu lateral (o la flecha para volver) y el
/// boton de cerrar sesion a la derecha.
class Cabecera extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final VoidCallback onMenu;

  /// Si no es null, en lugar del menu se muestra una flecha para volver atras.
  final VoidCallback? onAtras;
  final VoidCallback? onCerrarSesion;

  const Cabecera({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.onMenu,
    this.onAtras,
    this.onCerrarSesion,
  });

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(8, arriba + 14, 8, 20),
      decoration: const BoxDecoration(
        color: ColoresApp.azul,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          onAtras != null
              ? IconButton(
                  onPressed: onAtras,
                  tooltip: 'Volver',
                  icon: const FaIcon(FontAwesomeIcons.arrowLeft, color: ColoresApp.blanco, size: 20),
                )
              : IconButton(
                  onPressed: onMenu,
                  tooltip: 'Menú',
                  icon: const FaIcon(FontAwesomeIcons.bars, color: ColoresApp.blanco, size: 20),
                ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ColoresApp.blanco, fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: ColoresApp.blanco.withValues(alpha: 0.8), fontSize: 14),
                ),
              ],
            ),
          ),
          if (onCerrarSesion != null)
            IconButton(
              onPressed: onCerrarSesion,
              tooltip: 'Cerrar sesión',
              icon: const FaIcon(FontAwesomeIcons.rightFromBracket, color: ColoresApp.blanco, size: 19),
            ),
        ],
      ),
    );
  }
}

/// Panel blanco inferior con esquinas redondeadas y sombra, sobre el mapa.
class PanelInferior extends StatelessWidget {
  final Widget child;

  /// Alto maximo como fraccion de la pantalla; el contenido se desplaza si no entra.
  final double altoMaximo;

  const PanelInferior({super.key, required this.child, this.altoMaximo = 0.62});

  @override
  Widget build(BuildContext context) {
    final medidas = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: medidas.size.height * altoMaximo),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: ColoresApp.blanco,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: ColoresApp.borde)),
          boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, -4))],
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + medidas.padding.bottom),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      ),
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
                if (detalle != null)
                  Text(detalle!, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12)),
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
        Text(texto, style: const TextStyle(color: ColoresApp.texto, fontSize: 14, fontWeight: FontWeight.w600)),
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
