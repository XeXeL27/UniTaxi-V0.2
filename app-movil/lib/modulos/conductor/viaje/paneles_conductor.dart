import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/formato.dart';
import '../../../core/tema.dart';
import '../../../mapa/servicios_mapa.dart';
import '../../../widgets/boton_principal.dart';
import '../../../widgets/paneles.dart';
import 'flujo_conductor.dart';
import '../../../comun/modelos_viaje.dart';

String _km(double? metros) {
  if (metros == null) return '-';
  if (metros < 1000) return '${metros.round()} m';
  return '${(metros / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// Lista de solicitudes de viaje disponibles.
class PanelSolicitudes extends StatelessWidget {
  final FlujoConductor flujo;

  /// Vuelve a consultar si la administracion ya aprobo la cuenta (solo en revision).
  final VoidCallback? onRevisarAprobacion;

  const PanelSolicitudes({super.key, required this.flujo, this.onRevisarAprobacion});

  @override
  Widget build(BuildContext context) {
    final lista = flujo.solicitudes;
    if (flujo.enRevision) return _EnRevision(situacion: flujo.situacionAprobacion, onRevisar: onRevisarAprobacion);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Solicitudes de viaje',
                style: TextStyle(color: ColoresApp.azul, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            if (lista.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: ColoresApp.rojo, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${lista.length}',
                  style: const TextStyle(color: ColoresApp.blanco, fontWeight: FontWeight.w700),
                ),
              ),
            IconButton(
              onPressed: flujo.refrescarLista,
              tooltip: 'Actualizar',
              icon: const FaIcon(FontAwesomeIcons.arrowsRotate, color: ColoresApp.textoSuave, size: 16),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (!flujo.enLinea)
          const _Mensaje(
            icono: FontAwesomeIcons.powerOff,
            texto: 'Estás desconectado. Toca el botón del centro para conectarte y recibir solicitudes.',
            color: ColoresApp.textoSuave,
          )
        else if (!flujo.listaCargada)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator(color: ColoresApp.azul)),
          )
        else if (flujo.errorLista != null)
          _Mensaje(icono: FontAwesomeIcons.circleExclamation, texto: flujo.errorLista!, color: ColoresApp.rojo)
        else if (lista.isEmpty)
          const _Mensaje(
            icono: FontAwesomeIcons.hourglassHalf,
            texto: 'No hay solicitudes por ahora. La lista se actualiza sola: cuando un pasajero pida un taxi aparecerá aquí.',
            color: ColoresApp.textoSuave,
          )
        else
          for (final solicitud in lista)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TarjetaSolicitud(
                solicitud: solicitud,
                distanciaAMi: flujo.metrosDesdeMi(solicitud.origen),
                onTap: () => flujo.verSolicitud(solicitud),
              ),
            ),
      ],
    );
  }
}

class _TarjetaSolicitud extends StatelessWidget {
  final Solicitud solicitud;
  final double? distanciaAMi;
  final VoidCallback onTap;

  const _TarjetaSolicitud({required this.solicitud, required this.distanciaAMi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final metrosViaje = solicitud.tieneRuta
        ? ServiciosMapa.metros(solicitud.origen!, solicitud.destino!)
        : null;
    return Material(
      color: ColoresApp.blanco,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ColoresApp.borde),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AvatarIniciales(nombre: solicitud.nombrePasajero, radio: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      solicitud.nombrePasajero,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  Text(
                    formatoBs(solicitud.precio),
                    style: const TextStyle(color: ColoresApp.exito, fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FilaLugar.partida(etiqueta: 'Recoger en (A)', texto: solicitud.origenDireccion),
              FilaLugar.destino(etiqueta: 'Llevar a (B)', texto: solicitud.destinoDireccion),
              const SizedBox(height: 4),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (distanciaAMi != null)
                    DatoRuta(icono: FontAwesomeIcons.locationArrow, texto: 'A ${_km(distanciaAMi)} de ti'),
                  if (metrosViaje != null)
                    DatoRuta(icono: FontAwesomeIcons.route, texto: 'Viaje de ${_km(metrosViaje)} aprox.'),
                ],
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Ver ruta',
                    style: TextStyle(color: ColoresApp.ruta, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 6),
                  FaIcon(FontAwesomeIcons.chevronRight, color: ColoresApp.ruta, size: 12),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detalle de una solicitud con su ruta en el mapa, antes de aceptarla.
class PanelDetalleSolicitud extends StatelessWidget {
  final FlujoConductor flujo;
  final VoidCallback onAceptar;

  const PanelDetalleSolicitud({super.key, required this.flujo, required this.onAceptar});

  @override
  Widget build(BuildContext context) {
    final solicitud = flujo.seleccionada;
    if (solicitud == null) return const SizedBox.shrink();
    final ruta = flujo.mapa.ruta;
    final acercamiento = flujo.mapa.acercamiento;
    final comision = flujo.precio?.comisionPorcentaje ?? 0;
    final ganancia = solicitud.precio == null ? null : solicitud.precio! * (1 - comision / 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AvatarIniciales(nombre: solicitud.nombrePasajero, radio: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    solicitud.nombrePasajero,
                    style: const TextStyle(color: ColoresApp.azul, fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const Text('Pasajero', style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FilaLugar.partida(etiqueta: 'Recoger en (A)', texto: solicitud.origenDireccion),
        FilaLugar.destino(etiqueta: 'Llevar a (B)', texto: solicitud.destinoDireccion),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            if (acercamiento != null)
              DatoRuta(
                icono: FontAwesomeIcons.locationArrow,
                texto: 'Hasta el pasajero: ${acercamiento.distanciaTexto}, ${acercamiento.duracionTexto}',
              ),
            if (ruta != null)
              DatoRuta(icono: FontAwesomeIcons.route, texto: 'Viaje: ${ruta.distanciaTexto}, ${ruta.duracionTexto}')
            else
              const Text('Trazando la ruta...', style: TextStyle(color: ColoresApp.textoSuave)),
          ],
        ),
        const SizedBox(height: 12),
        RecuadroPrecio(
          etiqueta: 'Cobras en efectivo',
          detalle: ganancia == null
              ? null
              : 'Tu ganancia: ${formatoBs(ganancia)} (comisión ${comision.toStringAsFixed(0)}%)',
          monto: formatoBs(solicitud.precio),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: BotonSecundario(texto: 'Volver', onPressed: flujo.ocupado ? null : flujo.volverALista),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: BotonPrincipal(texto: 'Aceptar viaje', cargando: flujo.ocupado, onPressed: onAceptar),
            ),
          ],
        ),
      ],
    );
  }
}

/// Viaje en curso del conductor: estado, pasajero, lugares y el boton del siguiente paso.
class PanelViajeConductor extends StatelessWidget {
  final FlujoConductor flujo;
  final VoidCallback onAvanzar;
  final VoidCallback onCancelar;

  const PanelViajeConductor({super.key, required this.flujo, required this.onAvanzar, required this.onCancelar});

  @override
  Widget build(BuildContext context) {
    final viaje = flujo.viaje;
    if (viaje == null) return const SizedBox.shrink();
    final (texto, color, boton, colorBoton) = switch (viaje.situacion) {
      SituacionViaje.confirmado => (
        'Viaje aceptado. Avisa que vas en camino.',
        ColoresApp.exito,
        'Voy en camino',
        ColoresApp.azul,
      ),
      SituacionViaje.enCamino => (
        'Ve a recoger a ${viaje.primerNombrePasajero} (punto A)',
        ColoresApp.ruta,
        'Llegué al punto de partida',
        ColoresApp.azul,
      ),
      SituacionViaje.llego => (
        'Esperando a ${viaje.primerNombrePasajero}',
        ColoresApp.rojo,
        'Iniciar viaje',
        ColoresApp.azul,
      ),
      SituacionViaje.enCurso => ('En viaje hacia el destino (B)', ColoresApp.azul, 'Finalizar viaje', ColoresApp.rojo),
      _ => (SituacionViaje.nombre(viaje.situacion), ColoresApp.textoSuave, '', ColoresApp.azul),
    };
    final distanciaDestino = flujo.metrosDesdeMi(viaje.destino);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            AvatarIniciales(nombre: viaje.nombrePasajero, radio: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                viaje.nombrePasajero,
                style: const TextStyle(color: ColoresApp.azul, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilaLugar.partida(etiqueta: 'Recoger en (A)', texto: viaje.origenDireccion),
        FilaLugar.destino(etiqueta: 'Llevar a (B)', texto: viaje.destinoDireccion),
        if (viaje.situacion == SituacionViaje.enCurso) ...[
          const SizedBox(height: 6),
          Text(
            distanciaDestino == null
                ? 'El viaje se finaliza solo al llegar a menos de 50 m del destino.'
                : 'Faltan ${_km(distanciaDestino)} en línea recta. Se finaliza solo a menos de 50 m del destino.',
            style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
          ),
        ],
        const SizedBox(height: 10),
        RecuadroPrecio(etiqueta: 'Cobra en efectivo', monto: formatoBs(viaje.precioFinal)),
        const SizedBox(height: 14),
        if (boton.isNotEmpty)
          BotonPrincipal(texto: boton, color: colorBoton, cargando: flujo.ocupado, onPressed: onAvanzar),
        if (SituacionViaje.cancelables.contains(viaje.situacion)) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: flujo.ocupado ? null : onCancelar,
            style: TextButton.styleFrom(foregroundColor: ColoresApp.rojo),
            child: const Text('Cancelar viaje', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
}

/// La cuenta todavia no esta aprobada: explica que falta y deja volver a consultar.
class _EnRevision extends StatelessWidget {
  final String? situacion;
  final VoidCallback? onRevisar;

  const _EnRevision({required this.situacion, required this.onRevisar});

  @override
  Widget build(BuildContext context) {
    final (titulo, texto, color) = switch (situacion) {
      'RECHAZADO' => (
        'Registro rechazado',
        'La administración rechazó tu registro. Revisa tus documentos en Más > Mis documentos o comunícate con TaxiUAP.',
        ColoresApp.rojo,
      ),
      'SUSPENDIDO' => (
        'Cuenta suspendida',
        'Tu cuenta de conductor está suspendida. Comunícate con la administración de TaxiUAP.',
        ColoresApp.rojo,
      ),
      _ => (
        'Cuenta en revisión',
        'La administración está revisando tus datos y documentos. Cuando te aprueben podrás conectarte y recibir solicitudes.',
        const Color(0xFFE67E22),
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: Center(child: FaIcon(FontAwesomeIcons.hourglassHalf, color: color, size: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(titulo, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(texto, style: const TextStyle(color: ColoresApp.texto, fontSize: 14, height: 1.4)),
        if (onRevisar != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRevisar,
              icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 14),
              label: const Text('Ver si ya me aprobaron'),
            ),
          ),
        ],
      ],
    );
  }
}

class _Mensaje extends StatelessWidget {
  final FaIconData icono;
  final String texto;
  final Color color;

  const _Mensaje({required this.icono, required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ColoresApp.fondo, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          FaIcon(icono, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: TextStyle(color: color == ColoresApp.textoSuave ? ColoresApp.texto : color))),
        ],
      ),
    );
  }
}
