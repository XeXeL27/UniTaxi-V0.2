import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/formato.dart';
import '../../../core/tema.dart';
import '../../../widgets/boton_principal.dart';
import '../../../widgets/paneles.dart';
import 'flujo_pasajero.dart';
import '../../../comun/modelos_viaje.dart';

/// Panel mientras el pasajero elige su destino: partida (GPS), destino, ruta, precio y el boton
/// para solicitar el taxi.
class PanelEligiendo extends StatelessWidget {
  final FlujoPasajero flujo;
  final bool enviando;
  final VoidCallback onSolicitar;
  final VoidCallback onGuardarDestino;

  const PanelEligiendo({
    super.key,
    required this.flujo,
    required this.enviando,
    required this.onSolicitar,
    required this.onGuardarDestino,
  });

  @override
  Widget build(BuildContext context) {
    final mapa = flujo.mapa;
    final a = mapa.a;
    final b = mapa.b;
    final ruta = mapa.ruta;

    if (flujo.guardandoLugar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Indicacion(
            icono: FontAwesomeIcons.solidStar,
            texto: 'Toca el mapa en el lugar que quieres guardar como favorito',
          ),
          const SizedBox(height: 14),
          BotonSecundario(texto: 'Cancelar', onPressed: () => flujo.cambiarGuardandoLugar(false)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (a == null)
          mapa.gpsDisponible == false
              ? const _Indicacion(
                  icono: FontAwesomeIcons.locationCrosshairs,
                  texto: 'No pudimos obtener tu ubicación. Toca el mapa para marcar tu punto de partida.',
                )
              : const _Indicacion(icono: FontAwesomeIcons.satelliteDish, texto: 'Obteniendo tu ubicación...')
        else
          FilaLugar.partida(
            etiqueta: mapa.aSigueGps && a.texto == 'Mi ubicación actual' ? 'Mi ubicación actual (A)' : 'Punto de partida (A)',
            texto: flujo.direccionOrigen ?? a.texto,
          ),
        if (a != null && b == null) ...[
          const SizedBox(height: 10),
          const _Indicacion(
            icono: FontAwesomeIcons.handPointer,
            texto: 'Toca el mapa en el lugar a donde quieres ir, o elige uno de tus favoritos en el menú.',
          ),
        ],
        if (b != null) ...[
          FilaLugar.destino(
            texto: b.texto,
            accion: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onGuardarDestino,
                  tooltip: 'Guardar como favorito',
                  icon: const FaIcon(FontAwesomeIcons.star, color: ColoresApp.textoSuave, size: 17),
                ),
                IconButton(
                  onPressed: flujo.quitarDestino,
                  tooltip: 'Quitar destino',
                  icon: const FaIcon(FontAwesomeIcons.xmark, color: ColoresApp.textoSuave, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (ruta == null)
            const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ColoresApp.ruta),
                ),
                SizedBox(width: 10),
                Text('Trazando la ruta...', style: TextStyle(color: ColoresApp.textoSuave)),
              ],
            )
          else
            Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                DatoRuta(icono: FontAwesomeIcons.route, texto: ruta.distanciaTexto),
                DatoRuta(icono: FontAwesomeIcons.clock, texto: ruta.duracionTexto),
                if (ruta.aproximada)
                  const Text(
                    'Ruta aproximada',
                    style: TextStyle(color: ColoresApp.rojo, fontSize: 12.5),
                  ),
              ],
            ),
          const SizedBox(height: 14),
          RecuadroPrecio(
            etiqueta: 'Precio del viaje',
            detalle: 'Pagas en efectivo al conductor',
            monto: flujo.precio?.precio != null ? formatoBs(flujo.precio!.precio) : 'A calcular',
          ),
          const SizedBox(height: 14),
          BotonPrincipal(
            texto: 'Solicitar taxi',
            cargando: enviando,
            onPressed: flujo.puedeSolicitar ? onSolicitar : null,
          ),
        ],
      ],
    );
  }
}

/// Panel mientras la solicitud espera que un conductor la acepte.
class PanelBuscando extends StatefulWidget {
  final FlujoPasajero flujo;
  final bool cancelando;
  final VoidCallback onCancelar;

  const PanelBuscando({super.key, required this.flujo, required this.cancelando, required this.onCancelar});

  @override
  State<PanelBuscando> createState() => _PanelBuscandoState();
}

class _PanelBuscandoState extends State<PanelBuscando> with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final solicitud = widget.flujo.solicitud;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: AnimatedBuilder(
                animation: _pulso,
                builder: (context, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 30 + 26 * _pulso.value,
                      height: 30 + 26 * _pulso.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ColoresApp.rojo.withValues(alpha: 0.25 * (1 - _pulso.value)),
                      ),
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: ColoresApp.rojo, shape: BoxShape.circle),
                      child: const FaIcon(FontAwesomeIcons.taxi, color: ColoresApp.blanco, size: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buscando conductor...',
                    style: TextStyle(color: ColoresApp.azul, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tu solicitud ya les llegó a los taxistas. Espera un momento.',
                    style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          child: LinearProgressIndicator(minHeight: 4, color: ColoresApp.rojo, backgroundColor: ColoresApp.rojoSuave),
        ),
        const SizedBox(height: 12),
        if (solicitud != null) ...[
          FilaLugar.partida(texto: solicitud.origenDireccion),
          FilaLugar.destino(texto: solicitud.destinoDireccion),
          const SizedBox(height: 10),
          RecuadroPrecio(etiqueta: 'Precio del viaje', detalle: 'Pago en efectivo', monto: formatoBs(solicitud.precio)),
        ],
        const SizedBox(height: 14),
        widget.cancelando
            ? const Center(child: CircularProgressIndicator(color: ColoresApp.azul))
            : BotonSecundario(texto: 'Cancelar solicitud', onPressed: widget.onCancelar),
      ],
    );
  }
}

/// Panel del viaje asignado: estado, datos del conductor y del vehiculo, lugares y precio.
class PanelViaje extends StatelessWidget {
  final FlujoPasajero flujo;
  final VoidCallback onCancelar;

  const PanelViaje({super.key, required this.flujo, required this.onCancelar});

  @override
  Widget build(BuildContext context) {
    final viaje = flujo.viaje;
    if (viaje == null) return const SizedBox.shrink();
    final (icono, texto, color) = switch (viaje.situacion) {
      SituacionViaje.confirmado => (FontAwesomeIcons.circleCheck, 'Tu conductor aceptó el viaje', ColoresApp.exito),
      SituacionViaje.enCamino => (FontAwesomeIcons.carSide, 'Tu conductor va en camino', ColoresApp.ruta),
      SituacionViaje.llego => (
        FontAwesomeIcons.locationDot,
        'Tu conductor llegó. Te está esperando',
        ColoresApp.rojo,
      ),
      SituacionViaje.enCurso => (FontAwesomeIcons.route, 'En viaje a tu destino', ColoresApp.azul),
      _ => (FontAwesomeIcons.circleInfo, SituacionViaje.nombre(viaje.situacion), ColoresApp.textoSuave),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              FaIcon(icono, color: color, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ],
          ),
        ),
        if (flujo.llegandoDestino) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: ColoresApp.exito.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                FaIcon(FontAwesomeIcons.flagCheckered, color: ColoresApp.exito, size: 16),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Llegaste a tu destino. El conductor finalizará el viaje.',
                    style: TextStyle(color: ColoresApp.exito, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            AvatarIniciales(nombre: viaje.nombreConductor, radio: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    viaje.nombreConductor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ColoresApp.azul, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Estrellas(valor: viaje.calificacionConductor ?? 0, tamano: 12),
                      const SizedBox(width: 6),
                      Text(
                        (viaje.calificacionConductor ?? 0).toStringAsFixed(1).replaceAll('.', ','),
                        style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
                      ),
                    ],
                  ),
                  if (viaje.vehiculo.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(viaje.vehiculo, style: const TextStyle(color: ColoresApp.texto, fontSize: 13)),
                  ],
                ],
              ),
            ),
            if (viaje.placa != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: ColoresApp.azul, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  viaje.placa!,
                  style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
              ),
          ],
        ),
        const Divider(height: 26, color: ColoresApp.borde),
        FilaLugar.partida(texto: viaje.origenDireccion),
        FilaLugar.destino(texto: viaje.destinoDireccion),
        const SizedBox(height: 10),
        RecuadroPrecio(etiqueta: 'Pagas en efectivo', monto: formatoBs(viaje.precioFinal)),
        if (SituacionViaje.cancelables.contains(viaje.situacion)) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: onCancelar,
            style: TextButton.styleFrom(foregroundColor: ColoresApp.rojo),
            child: const Text('Cancelar viaje', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
}

class _Indicacion extends StatelessWidget {
  final FaIconData icono;
  final String texto;

  const _Indicacion({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ColoresApp.fondo, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          FaIcon(icono, color: ColoresApp.azul, size: 16),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: const TextStyle(color: ColoresApp.texto, fontSize: 14))),
        ],
      ),
    );
  }
}
