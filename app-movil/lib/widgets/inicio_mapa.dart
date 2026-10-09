import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/enlaces.dart';
import '../core/iconos.dart';
import '../core/tema.dart';

/// Ancho maximo de la columna de controles sobre el mapa en pantallas anchas (PC): la cabecera y
/// el buscador no se estiran de lado a lado.
const double anchoControlesMapa = 560;

/// Alto de la pildora "¿A donde vas?".
const double altoBarraDestino = 56;

/// Foto de perfil redonda de la cabecera; sin foto, el icono del modo (moto para el conductor,
/// silueta para el pasajero) en negro sobre gris.
class AvatarCabecera extends StatelessWidget {
  final Uint8List? foto;
  final IconData iconoSinFoto;
  final double tamano;

  const AvatarCabecera({super.key, this.foto, required this.iconoSinFoto, this.tamano = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: const BoxDecoration(color: ColoresApp.gris, shape: BoxShape.circle),
      child: foto == null
          ? Center(child: Icon(iconoSinFoto, color: ColoresApp.tinta, size: tamano * 0.4))
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
  final IconData iconoBoton;
  final String tooltipBoton;
  final VoidCallback onBoton;

  /// Espacio extra al pie de la cabecera, para que el buscador quede dentro de ella.
  final double solape;

  /// Si no es null, en lugar de la foto va una flecha para volver (conductor viendo una ruta).
  final VoidCallback? onAtras;

  /// Foto de perfil; sin ella se muestra [iconoSinFoto].
  final Uint8List? foto;
  final IconData iconoSinFoto;

  /// Tocar la foto o el saludo (por ejemplo, ir a Mas).
  final VoidCallback? onPerfil;

  const CabeceraInicio({
    super.key,
    this.saludo = 'Bienvenido',
    required this.nombre,
    required this.ubicacion,
    this.iconoBoton = Iconos.headset,
    this.tooltipBoton = 'Ayuda',
    required this.onBoton,
    this.solape = 0,
    this.onAtras,
    this.foto,
    this.iconoSinFoto = Iconos.solidUser,
    this.onPerfil,
  });

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    // Fondo blanco arriba: la hora y la bateria del telefono en negro.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: BarraSistema.sobreClaro,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, arriba + 12, 16, 16 + solape),
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
                  BotonGris(icono: Iconos.arrowLeft, tooltip: 'Volver', onTap: onAtras!),
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Iconos.locationDot, size: 11, color: ColoresApp.grisTexto),
                          const SizedBox(width: 4),
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
                const SizedBox(width: 12),
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
  final IconData icono;
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
            child: Center(child: Icon(icono, color: ColoresApp.tinta, size: 17)),
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
              const SizedBox(width: 16),
              Icon(
                conDestino ? Iconos.solidSquare : Iconos.magnifyingGlass,
                color: ColoresApp.tinta,
                size: conDestino ? 12 : 18,
              ),
              const SizedBox(width: 16),
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
                  icon: const Icon(Iconos.xmark, color: ColoresApp.tinta, size: 18),
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

/// Hoja de soporte: asistencia, ayuda rapida y canales de atencion.
Future<void> mostrarAyuda(BuildContext context, {required bool esConductor}) {
  final pasos = esConductor
      ? const [
          (Iconos.powerOff, 'Conéctate con el botón verde de Inicio para recibir solicitudes.'),
          (Iconos.route, 'Cada solicitud muestra la ruta y cuánto cobras: tienes 15 segundos para aceptarla.'),
          (Iconos.flagCheckered, 'El viaje se finaliza al llegar a menos de 50 m del destino.'),
        ]
      : const [
          (Iconos.magnifyingGlass, 'Busca tu destino o tócalo en el mapa.'),
          (Iconos.paperPlane, 'Elige tu servicio, revisa el precio y toca Solicitar moto taxi.'),
          (Iconos.solidStar, 'Al llegar, califica a tu conductor.'),
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
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
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
                    child: const Center(child: Icon(Iconos.headset, color: ColoresApp.azul, size: 22)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  pregunta,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ColoresApp.azul, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  afirmacion,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ColoresApp.textoSuave, fontSize: 14),
                ),
                const SizedBox(height: 24),

                // Seccion AYUDA RAPIDA
                const Text(
                  'AYUDA RÁPIDA',
                  style: TextStyle(color: ColoresApp.azul, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                _TipAyudaRapida(
                  icono: Iconos.locationCrosshairs,
                  texto: 'Activa tu ubicación para que el conductor te encuentre.',
                ),
                const SizedBox(height: 8),
                _TipAyudaRapida(
                  icono: Iconos.bell,
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
                          child: Center(child: Icon(icono, color: ColoresApp.azul, size: 16)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Text(texto, style: const TextStyle(color: ColoresApp.texto, fontSize: 14.5))),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                const Divider(color: ColoresApp.borde),
                const SizedBox(height: 16),

                // Seccion CANALES DE ATENCION
                const Text(
                  'CANALES DE ATENCIÓN',
                  style: TextStyle(color: ColoresApp.azul, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Selecciona la manera de comunicarte con nosotros:',
                  style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13.5),
                ),
                const SizedBox(height: 12),
                _CanalAtencion(
                  icono: Iconos.envelope,
                  color: ColoresApp.azul,
                  titulo: 'Correo electrónico',
                  valor: 'unitaxi@uap.edu.bo',
                  onTap: () => abrirEnlaceExterno(context, Uri.parse('mailto:unitaxi@uap.edu.bo'), 'unitaxi@uap.edu.bo'),
                ),
                const SizedBox(height: 12),
                _CanalAtencion(
                  icono: Iconos.locationDot,
                  color: ColoresApp.rojo,
                  titulo: 'Dirección',
                  valor: 'X6JW+Q5P, C. Bruno Racua, Cobija',
                  onTap: () => abrirEnlaceExterno(
                    context,
                    Uri.parse('https://maps.app.goo.gl/FTmrpKDkZqsoKCcb9'),
                    'la dirección',
                  ),
                ),
                const SizedBox(height: 12),
                _CanalAtencion(
                  icono: Iconos.clock,
                  color: ColoresApp.exito,
                  titulo: 'Horario de atención',
                  valor: 'Lunes a viernes: 8:00 - 12:00 y 14:00 - 16:00',
                  onTap: null,
                ),
                const SizedBox(height: 16),
                const Divider(color: ColoresApp.borde),
                const SizedBox(height: 12),

                // Emergencia
                const Row(
                  children: [
                    Icon(Iconos.triangleExclamation, color: ColoresApp.rojo, size: 16),
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
  final IconData icono;
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
          child: Center(child: Icon(icono, color: ColoresApp.azul, size: 14)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(texto, style: const TextStyle(color: ColoresApp.texto, fontSize: 14))),
      ],
    );
  }
}

class _CanalAtencion extends StatelessWidget {
  final IconData icono;
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
                child: Center(child: Icon(icono, color: color, size: 15)),
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
                    const SizedBox(height: 4),
                    Text(
                      valor,
                      style: const TextStyle(color: ColoresApp.texto, fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Iconos.chevronRight, color: color.withValues(alpha: 0.5), size: 12),
            ],
          ),
        ),
      ),
    );
  }
}

