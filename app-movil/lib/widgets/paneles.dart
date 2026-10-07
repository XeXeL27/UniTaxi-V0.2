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

  /// Boton del siguiente paso, fijo debajo del contenido: nunca se va con el desplazamiento, asi se
  /// ve aunque el panel tenga muchos avisos (cobro por QR, espera del pasajero...).
  final Widget? pie;
  static const double anchoMaximo = 560;

  const PanelInferior({
    super.key,
    required this.child,
    this.altoMaximo = 0.62,
    this.flotante = false,
    this.pie,
  });

  @override
  Widget build(BuildContext context) {
    final medidas = MediaQuery.of(context);
    final abajo = flotante ? 0.0 : medidas.viewPadding.bottom;
    final pie = this.pie;
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 18, 20, pie == null ? 18 + abajo : 10),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: child,
                ),
              ),
            ),
            if (pie != null) Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + abajo), child: pie),
          ],
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

  /// Alto maximo del contenido abierto, como fraccion de la pantalla. Lo que sobra se desplaza dentro
  /// del panel y la barra se sigue viendo.
  static const double altoMaximo = 0.45;

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
      mainAxisSize: MainAxisSize.min,
      children: [
        barra,
        if (abierto) ...[
          const SizedBox(height: 8),
          // El panel va en un Stack pegado abajo, sin alto dado: sin este tope, un contenido largo
          // (el resumen del pedido del repartidor, los dos codigos de entrega del pasajero) se sale
          // por arriba de la pantalla y lo de arriba deja de verse sin poder desplazarse.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * altoMaximo),
            child: SingleChildScrollView(child: child),
          ),
        ],
        if (!abierto && accionPlegado != null) ...[const SizedBox(height: 8), accionPlegado!],
      ],
    );
  }
}

/// Seccion del panel que se ve siempre pero con sus campos escondidos hasta que se toca.
///
/// El panel del repartidor tiene acciones que casi nunca se usan (reportar que el paquete no
/// coincide, no poder entregar) y otras que son el dia a dia (confirmar el codigo). Con todo
/// desplegado el panel crecia, tapaba el mapa y el repartidor iba a parar en el prompt equivocado.
/// El titulo queda siempre a la vista, que es lo que hace falta para saber que la accion existe.
class SeccionDesplegable extends StatefulWidget {
  final String titulo;
  final String? ayuda;
  final FaIconData icono;
  final Color color;
  final Widget child;

  /// Boton aparte en la cabecera, que no despliega la seccion (por ejemplo "Cancelar pedido").
  final Widget? accion;

  final bool abiertoInicial;

  const SeccionDesplegable({
    super.key,
    required this.titulo,
    required this.icono,
    required this.child,
    this.ayuda,
    this.color = ColoresApp.texto,
    this.accion,
    this.abiertoInicial = false,
  });

  @override
  State<SeccionDesplegable> createState() => _SeccionDesplegableState();
}

class _SeccionDesplegableState extends State<SeccionDesplegable> {
  late bool _abierto = widget.abiertoInicial;

  void _alternar() => setState(() => _abierto = !_abierto);

  @override
  Widget build(BuildContext context) {
    final separador = BorderSide(color: ColoresApp.borde.withValues(alpha: 0.8));
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: separador),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // La accion va fuera del InkWell a proposito: dentro, su toque desplegaria la seccion.
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _alternar,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        FaIcon(widget.icono, color: widget.color, size: 15),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.titulo,
                            style: TextStyle(color: widget.color, fontSize: 14.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        AnimatedRotation(
                          turns: _abierto ? 0.5 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: FaIcon(FontAwesomeIcons.chevronDown, color: widget.color, size: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.accion != null) widget.accion!,
            ],
          ),
          if (_abierto) ...[
            if (widget.ayuda != null) ...[
              Text(widget.ayuda!, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5)),
              const SizedBox(height: 10),
            ],
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: widget.child,
            ),
          ],
        ],
      ),
    );
  }
}
