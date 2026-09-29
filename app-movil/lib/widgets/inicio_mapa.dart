import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/tema.dart';

/// Ancho maximo de la columna de controles sobre el mapa en pantallas anchas (PC): la cabecera y
/// el buscador no se estiran de lado a lado.
const double anchoControlesMapa = 560;

/// Foto de perfil en el cuadro rojo de la cabecera; sin foto, el icono del modo (moto para el
/// conductor, silueta para el pasajero).
class AvatarCabecera extends StatelessWidget {
  final Uint8List? foto;
  final FaIconData iconoSinFoto;
  final double tamano;

  const AvatarCabecera({super.key, this.foto, required this.iconoSinFoto, this.tamano = 58});

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(tamano * 0.3);
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ColoresApp.rojo, ColoresApp.rojoOscuro],
        ),
        borderRadius: radio,
        border: Border.all(color: ColoresApp.blanco.withValues(alpha: 0.25), width: 1.5),
      ),
      child: foto == null
          ? Center(child: FaIcon(iconoSinFoto, color: ColoresApp.blanco, size: tamano * 0.42))
          : ClipRRect(
              borderRadius: BorderRadius.circular(tamano * 0.3 - 1.5),
              child: Image.memory(foto!, fit: BoxFit.cover, gaplessPlayback: true),
            ),
    );
  }
}

/// Cabecera de la pantalla de inicio: fondo azul marino, tarjeta con la foto de perfil (o el icono
/// del modo), "Bienvenido", "Hola, NOMBRE", la ubicacion actual y un boton redondo a la derecha
/// (ayuda).
class CabeceraInicio extends StatelessWidget {
  final String saludo;
  final String nombre;
  final String ubicacion;
  final FaIconData iconoBoton;
  final String tooltipBoton;
  final VoidCallback onBoton;

  /// Espacio extra al pie del fondo azul, para que el buscador se monte encima.
  final double solape;

  /// Si no es null, en lugar de la foto va una flecha para volver (conductor viendo una ruta).
  final VoidCallback? onAtras;

  /// Foto de perfil; sin ella se muestra [iconoSinFoto].
  final Uint8List? foto;
  final FaIconData iconoSinFoto;

  const CabeceraInicio({
    super.key,
    this.saludo = 'Bienvenido',
    required this.nombre,
    required this.ubicacion,
    this.iconoBoton = FontAwesomeIcons.headset,
    this.tooltipBoton = 'Ayuda',
    required this.onBoton,
    this.solape = 0,
    this.onAtras,
    this.foto,
    this.iconoSinFoto = FontAwesomeIcons.solidUser,
  });

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(14, arriba + 12, 14, 14 + solape),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF16386B), ColoresApp.azul],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
        boxShadow: [BoxShadow(color: Color(0x330A2342), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: anchoControlesMapa),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ColoresApp.blanco.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: ColoresApp.blanco.withValues(alpha: 0.14)),
            ),
            child: Row(
              children: [
                if (onAtras != null)
                  _BotonRedondo(icono: FontAwesomeIcons.arrowLeft, tooltip: 'Volver', onTap: onAtras!)
                else
                  AvatarCabecera(foto: foto, iconoSinFoto: iconoSinFoto),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(saludo, style: TextStyle(color: ColoresApp.blanco.withValues(alpha: 0.72), fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: ColoresApp.blanco, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          FaIcon(FontAwesomeIcons.locationDot, size: 12, color: ColoresApp.blanco.withValues(alpha: 0.8)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              ubicacion,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: ColoresApp.blanco.withValues(alpha: 0.85), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _BotonRedondo(icono: iconoBoton, tooltip: tooltipBoton, onTap: onBoton),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonRedondo extends StatelessWidget {
  final FaIconData icono;
  final String tooltip;
  final VoidCallback onTap;

  const _BotonRedondo({required this.icono, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: ColoresApp.blanco.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ColoresApp.blanco.withValues(alpha: 0.2)),
            ),
            child: Center(child: FaIcon(icono, color: ColoresApp.blanco, size: 20)),
          ),
        ),
      ),
    );
  }
}

/// Barra "Destino / ¿A donde quieres ir?" que abre el buscador. Con destino elegido muestra su
/// nombre y una X para quitarlo.
class BarraDestino extends StatelessWidget {
  final String? destino;
  final VoidCallback onBuscar;
  final VoidCallback? onQuitar;

  const BarraDestino({super.key, this.destino, required this.onBuscar, this.onQuitar});

  @override
  Widget build(BuildContext context) {
    final conDestino = destino != null;
    return Material(
      color: ColoresApp.blanco,
      elevation: 6,
      shadowColor: const Color(0x440A2342),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onBuscar,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [ColoresApp.rojo, ColoresApp.rojoOscuro]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(child: FaIcon(FontAwesomeIcons.mapLocationDot, color: ColoresApp.blanco, size: 21)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Destino',
                      style: TextStyle(color: ColoresApp.rojo, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destino ?? '¿A dónde quieres ir?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: conDestino ? ColoresApp.texto : ColoresApp.textoSuave,
                        fontSize: 16,
                        fontWeight: conDestino ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (conDestino && onQuitar != null)
                _BotonCuadro(icono: FontAwesomeIcons.xmark, tooltip: 'Quitar destino', onTap: onQuitar!)
              else
                _BotonCuadro(icono: FontAwesomeIcons.magnifyingGlass, tooltip: 'Buscar destino', onTap: onBuscar),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonCuadro extends StatelessWidget {
  final FaIconData icono;
  final String tooltip;
  final VoidCallback onTap;

  const _BotonCuadro({required this.icono, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: ColoresApp.azulSuave,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Center(child: FaIcon(icono, color: ColoresApp.azul, size: 18)),
          ),
        ),
      ),
    );
  }
}

/// Opcion del selector de vehiculo de la derecha del mapa.
class OpcionVehiculo {
  final String nombre;
  final Widget icono;
  final bool activa;

  /// Deshabilitada se ve atenuada con "Pronto" debajo.
  final bool proximamente;
  final VoidCallback onTap;

  const OpcionVehiculo({
    required this.nombre,
    required this.icono,
    required this.onTap,
    this.activa = false,
    this.proximamente = false,
  });
}

/// Selector vertical Moto / Auto con un contador (conductores en linea o solicitudes).
class SelectorVehiculo extends StatelessWidget {
  final List<OpcionVehiculo> opciones;
  final int? contador;
  final String tooltipContador;

  const SelectorVehiculo({super.key, required this.opciones, this.contador, this.tooltipContador = ''});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 88,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: ColoresApp.blanco,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [BoxShadow(color: Color(0x330A2342), blurRadius: 14, offset: Offset(0, 5))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < opciones.length; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                _Vehiculo(opcion: opciones[i]),
              ],
            ],
          ),
        ),
        if (contador != null)
          Positioned(
            top: -10,
            right: -8,
            child: Tooltip(
              message: tooltipContador,
              child: Container(
                constraints: const BoxConstraints(minWidth: 30),
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: ColoresApp.azul,
                  shape: contador! > 9 ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: contador! > 9 ? BorderRadius.circular(15) : null,
                  border: Border.all(color: ColoresApp.blanco, width: 2.5),
                ),
                child: Center(
                  child: Text(
                    contador! > 99 ? '99+' : '$contador',
                    style: const TextStyle(color: ColoresApp.blanco, fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Vehiculo extends StatelessWidget {
  final OpcionVehiculo opcion;

  const _Vehiculo({required this.opcion});

  @override
  Widget build(BuildContext context) {
    final activa = opcion.activa;
    return Opacity(
      opacity: opcion.proximamente ? 0.55 : 1,
      child: Material(
        color: activa ? ColoresApp.azul : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: opcion.onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: double.infinity,
            height: 96,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 44, child: Center(child: opcion.icono)),
                const SizedBox(height: 6),
                Text(
                  opcion.nombre,
                  style: TextStyle(
                    color: activa ? ColoresApp.blanco : ColoresApp.azul,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (opcion.proximamente)
                  const Text('Pronto', style: TextStyle(color: ColoresApp.textoSuave, fontSize: 10.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja de ayuda del boton de la cabecera.
Future<void> mostrarAyuda(BuildContext context, {required bool esConductor}) {
  final pasos = esConductor
      ? const [
          (FontAwesomeIcons.powerOff, 'Conéctate con el botón del centro para recibir solicitudes.'),
          (FontAwesomeIcons.route, 'Toca una solicitud para ver la ruta y tu ganancia antes de aceptarla.'),
          (FontAwesomeIcons.flagCheckered, 'El viaje se finaliza al llegar a menos de 50 m del destino.'),
        ]
      : const [
          (FontAwesomeIcons.magnifyingGlass, 'Busca tu destino o tócalo en el mapa.'),
          (FontAwesomeIcons.paperPlane, 'Revisa el precio y pide tu mototaxi con el botón del centro.'),
          (FontAwesomeIcons.solidStar, 'Al llegar, califica a tu conductor.'),
        ];
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: ColoresApp.blanco,
    constraints: const BoxConstraints(maxWidth: 520),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('¿Cómo funciona?', style: TextStyle(color: ColoresApp.azul, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            for (final (icono, texto) in pasos)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(color: ColoresApp.azulSuave, shape: BoxShape.circle),
                      child: Center(child: FaIcon(icono, color: ColoresApp.azul, size: 16)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text(texto, style: const TextStyle(color: ColoresApp.texto, fontSize: 14.5))),
                  ],
                ),
              ),
            const Divider(color: ColoresApp.borde),
            const SizedBox(height: 6),
            const Row(
              children: [
                FaIcon(FontAwesomeIcons.triangleExclamation, color: ColoresApp.rojo, size: 16),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'En una emergencia llama a la Policía al 110.',
                    style: TextStyle(color: ColoresApp.rojoOscuro, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
