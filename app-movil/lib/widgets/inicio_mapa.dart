import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/tema.dart';
import 'notificaciones.dart';

/// Ancho maximo de la columna de controles sobre el mapa en pantallas anchas (PC): la cabecera y
/// el buscador no se estiran de lado a lado.
const double anchoControlesMapa = 560;

/// Alto de la pildora "¿A donde vas?".
const double altoBarraDestino = 56;

/// Foto de perfil redonda de la cabecera; sin foto, el icono del modo (moto para el conductor,
/// silueta para el pasajero) en negro sobre gris.
class AvatarCabecera extends StatelessWidget {
  final Uint8List? foto;
  final FaIconData iconoSinFoto;
  final double tamano;

  const AvatarCabecera({super.key, this.foto, required this.iconoSinFoto, this.tamano = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: const BoxDecoration(color: ColoresApp.gris, shape: BoxShape.circle),
      child: foto == null
          ? Center(child: FaIcon(iconoSinFoto, color: ColoresApp.tinta, size: tamano * 0.4))
          : ClipOval(child: Image.memory(foto!, fit: BoxFit.cover, gaplessPlayback: true)),
    );
  }
}

/// Cabecera de la pantalla de inicio (estilo Uber): fondo blanco, foto redonda, "Bienvenido",
/// "Hola, Nombre" en negrita negra, la ubicacion actual en gris y un boton redondo gris a la
/// derecha (ayuda).
class CabeceraInicio extends StatelessWidget {
  final String saludo;
  final String nombre;
  final String ubicacion;
  final FaIconData iconoBoton;
  final String tooltipBoton;
  final VoidCallback onBoton;

  /// Espacio extra al pie de la cabecera, para que el buscador quede dentro de ella.
  final double solape;

  /// Si no es null, en lugar de la foto va una flecha para volver (conductor viendo una ruta).
  final VoidCallback? onAtras;

  /// Foto de perfil; sin ella se muestra [iconoSinFoto].
  final Uint8List? foto;
  final FaIconData iconoSinFoto;

  /// Tocar la foto o el saludo (por ejemplo, ir a Mas).
  final VoidCallback? onPerfil;

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
    this.onPerfil,
  });

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    // Fondo blanco arriba: la hora y la bateria del telefono en negro.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: BarraSistema.sobreClaro,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, arriba + 10, 16, 14 + solape),
        decoration: const BoxDecoration(
          color: ColoresApp.blanco,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
          boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, 4))],
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: anchoControlesMapa),
            child: Row(
              children: [
                if (onAtras != null) ...[
                  BotonGris(icono: FontAwesomeIcons.arrowLeft, tooltip: 'Volver', onTap: onAtras!),
                  const SizedBox(width: 12),
                ],
                // La foto y el saludo juntos: tocarlos lleva a Mas.
                Expanded(
                  child: InkWell(
                    onTap: onPerfil,
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      children: [
                        if (onAtras == null) ...[
                          AvatarCabecera(foto: foto, iconoSinFoto: iconoSinFoto),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        saludo,
                        style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ColoresApp.tinta,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const FaIcon(FontAwesomeIcons.locationDot, size: 11, color: ColoresApp.grisTexto),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              ubicacion,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                BotonGris(icono: iconoBoton, tooltip: tooltipBoton, onTap: onBoton),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Boton redondo gris claro con el icono en negro (ayuda, volver).
class BotonGris extends StatelessWidget {
  final FaIconData icono;
  final String tooltip;
  final VoidCallback onTap;
  final double tamano;

  const BotonGris({super.key, required this.icono, required this.tooltip, required this.onTap, this.tamano = 44});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: ColoresApp.gris,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: tamano,
            height: tamano,
            child: Center(child: FaIcon(icono, color: ColoresApp.tinta, size: 17)),
          ),
        ),
      ),
    );
  }
}

/// Pildora "¿A donde vas?" que abre el buscador (estilo Uber), justo debajo de la cabecera. Con
/// destino elegido muestra su nombre en negrita y una X para quitarlo.
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
      elevation: 5,
      shadowColor: const Color(0x55000000),
      borderRadius: BorderRadius.circular(altoBarraDestino / 2),
      child: InkWell(
        onTap: onBuscar,
        borderRadius: BorderRadius.circular(altoBarraDestino / 2),
        child: SizedBox(
          height: altoBarraDestino,
          child: Row(
            children: [
              const SizedBox(width: 20),
              FaIcon(
                conDestino ? FontAwesomeIcons.solidSquare : FontAwesomeIcons.magnifyingGlass,
                color: ColoresApp.tinta,
                size: conDestino ? 12 : 18,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  destino ?? '¿A dónde vas?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ColoresApp.tinta,
                    fontSize: conDestino ? 16 : 18,
                    fontWeight: conDestino ? FontWeight.w600 : FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (conDestino && onQuitar != null)
                IconButton(
                  tooltip: 'Quitar destino',
                  onPressed: onQuitar,
                  icon: const FaIcon(FontAwesomeIcons.xmark, color: ColoresApp.tinta, size: 18),
                )
              else
                const SizedBox(width: 16),
              const SizedBox(width: 4),
            ],
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
          width: 84,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: ColoresApp.blanco,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 14, offset: Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < opciones.length; i++) ...[
                if (i > 0) const SizedBox(height: 5),
                _Vehiculo(opcion: opciones[i]),
              ],
            ],
          ),
        ),
        if (contador != null)
          Positioned(
            top: -9,
            right: -7,
            child: Tooltip(
              message: tooltipContador,
              child: Container(
                constraints: const BoxConstraints(minWidth: 28),
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: ColoresApp.tinta,
                  shape: contador! > 9 ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: contador! > 9 ? BorderRadius.circular(14) : null,
                  border: Border.all(color: ColoresApp.blanco, width: 2.5),
                ),
                child: Center(
                  child: Text(
                    contador! > 99 ? '99+' : '$contador',
                    style: const TextStyle(color: ColoresApp.blanco, fontSize: 12.5, fontWeight: FontWeight.w700),
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
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: activa ? ColoresApp.tinta : Colors.transparent, width: 2),
    );
    return Opacity(
      opacity: opcion.proximamente ? 0.5 : 1,
      child: Material(
        color: activa ? ColoresApp.gris : Colors.transparent,
        shape: forma,
        child: InkWell(
          onTap: opcion.onTap,
          customBorder: forma,
          child: SizedBox(
            width: double.infinity,
            height: 90,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 44, child: Center(child: opcion.icono)),
                const SizedBox(height: 4),
                Text(
                  opcion.nombre,
                  style: const TextStyle(color: ColoresApp.tinta, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                if (opcion.proximamente)
                  const Text('Pronto', style: TextStyle(color: ColoresApp.grisTexto, fontSize: 10.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja de soporte: asistencia, ayuda rapida y canales de atencion.
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

  final pregunta = esConductor ? '¿Necesitas ayuda con la app?' : '¿Necesitas asistencia?';
  const afirmacion = 'Estamos disponibles para ayudarte en lo que necesites.';

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: ColoresApp.blanco,
    constraints: const BoxConstraints(maxWidth: 520),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    isScrollControlled: true,
    builder: (context) {
      final altoMax = MediaQuery.sizeOf(context).height * 0.85;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: altoMax),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero: pregunta y afirmacion
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(color: ColoresApp.azulSuave, shape: BoxShape.circle),
                    child: const Center(child: FaIcon(FontAwesomeIcons.headset, color: ColoresApp.azul, size: 22)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  pregunta,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ColoresApp.azul, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  afirmacion,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ColoresApp.textoSuave, fontSize: 14),
                ),
                const SizedBox(height: 22),

                // Seccion AYUDA RAPIDA
                const Text(
                  'AYUDA RÁPIDA',
                  style: TextStyle(color: ColoresApp.azul, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                const SizedBox(height: 10),
                _TipAyudaRapida(
                  icono: FontAwesomeIcons.locationCrosshairs,
                  texto: 'Activa tu ubicación para que el conductor te encuentre.',
                ),
                const SizedBox(height: 8),
                _TipAyudaRapida(
                  icono: FontAwesomeIcons.bell,
                  texto: 'Mantén activadas las notificaciones de la app.',
                ),
                const SizedBox(height: 16),

                // Pasos del rol
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
                const SizedBox(height: 14),
                const Divider(color: ColoresApp.borde),
                const SizedBox(height: 14),

                // Seccion CANALES DE ATENCION
                const Text(
                  'CANALES DE ATENCIÓN',
                  style: TextStyle(color: ColoresApp.azul, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Selecciona la manera de comunicarte con nosotros:',
                  style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13.5),
                ),
                const SizedBox(height: 12),
                _CanalAtencion(
                  icono: FontAwesomeIcons.envelope,
                  color: ColoresApp.azul,
                  titulo: 'Correo electrónico',
                  valor: 'unitaxi@uap.edu.bo',
                  onTap: () => _abrirEnlace(context, Uri.parse('mailto:unitaxi@uap.edu.bo'), 'unitaxi@uap.edu.bo'),
                ),
                const SizedBox(height: 10),
                _CanalAtencion(
                  icono: FontAwesomeIcons.locationDot,
                  color: ColoresApp.rojo,
                  titulo: 'Dirección',
                  valor: 'X6JW+Q5P, C. Bruno Racua, Cobija',
                  onTap: () => _abrirEnlace(
                    context,
                    Uri.parse('https://maps.app.goo.gl/FTmrpKDkZqsoKCcb9'),
                    'la dirección',
                  ),
                ),
                const SizedBox(height: 10),
                _CanalAtencion(
                  icono: FontAwesomeIcons.clock,
                  color: ColoresApp.exito,
                  titulo: 'Horario de atención',
                  valor: 'Lunes a viernes: 8:00 - 12:00 y 14:00 - 16:00',
                  onTap: null,
                ),
                const SizedBox(height: 18),
                const Divider(color: ColoresApp.borde),
                const SizedBox(height: 12),

                // Emergencia
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
                const SizedBox(height: 12),

                // Cierre
                const Text(
                  '¿Tienes preguntas? Estamos encantados de ayudarte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _TipAyudaRapida extends StatelessWidget {
  final FaIconData icono;
  final String texto;

  const _TipAyudaRapida({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: ColoresApp.azulSuave, shape: BoxShape.circle),
          child: Center(child: FaIcon(icono, color: ColoresApp.azul, size: 14)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(texto, style: const TextStyle(color: ColoresApp.texto, fontSize: 14))),
      ],
    );
  }
}

class _CanalAtencion extends StatelessWidget {
  final FaIconData icono;
  final Color color;
  final String titulo;
  final String valor;
  final VoidCallback? onTap;

  const _CanalAtencion({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.valor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
                child: Center(child: FaIcon(icono, color: color, size: 15)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      valor,
                      style: const TextStyle(color: ColoresApp.texto, fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                FaIcon(FontAwesomeIcons.chevronRight, color: color.withValues(alpha: 0.5), size: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abre un enlace externo; si falla, copia el texto al portapapeles como respaldo.
Future<void> _abrirEnlace(BuildContext context, Uri uri, String textoPortapapeles) async {
  try {
    final pudo = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!pudo && context.mounted) {
      await Clipboard.setData(ClipboardData(text: textoPortapapeles));
      if (context.mounted) {
        mostrarMensaje(context, 'No se pudo abrir. Copiado al portapapeles.');
      }
    }
  } catch (_) {
    if (context.mounted) {
      await Clipboard.setData(ClipboardData(text: textoPortapapeles));
      if (context.mounted) {
        mostrarMensaje(context, 'No se pudo abrir. Copiado al portapapeles.');
      }
    }
  }
}
