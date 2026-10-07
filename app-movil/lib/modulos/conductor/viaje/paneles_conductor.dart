import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../widgets/dialogos.dart';
import '../../../core/api_excepcion.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../core/formato.dart';
import '../../../core/tema.dart';
import '../../../mapa/servicios_mapa.dart';
import '../../../widgets/boton_principal.dart';
import '../../../widgets/paneles.dart';
import 'flujo_conductor.dart';
import '../../../comun/modelos_viaje.dart';
import '../../../comun/vista_chat.dart';
import 'panel_delivery_conductor.dart';

String _km(double? metros) {
  if (metros == null) return '-';
  if (metros < 1000) return '${metros.round()} m';
  return '${(metros / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// Lista de solicitudes de viaje disponibles, desplegable: cerrada solo se ve la barra "Solicitudes
/// de viaje" con el contador, asi no tapa el mapa; la flecha (o tocar la barra) la abre y la cierra.
class PanelSolicitudes extends StatelessWidget {
  final FlujoConductor flujo;

  /// Vuelve a consultar si la administracion ya aprobo la cuenta (solo en revision).
  final VoidCallback? onRevisarAprobacion;

  /// Abre Mis documentos para subir los que faltan (cuenta bloqueada por documentos).
  final VoidCallback? onSubirDocumentos;

  const PanelSolicitudes({super.key, required this.flujo, this.onRevisarAprobacion, this.onSubirDocumentos});

  @override
  Widget build(BuildContext context) {
    final lista = flujo.solicitudes;
    final abierto = flujo.listaAbierta;
    final onAlternar = flujo.alternarLista;
    final nuevas = flujo.nuevas;
    if (flujo.enRevision) {
      return _EnRevision(
        situacion: flujo.situacionAprobacion,
        faltantes: flujo.documentosFaltantes,
        onRevisar: onRevisarAprobacion,
        onSubirDocumentos: onSubirDocumentos,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: abierto ? 'Esconder solicitudes' : 'Ver solicitudes',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAlternar,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Solicitudes de viaje',
                      style: TextStyle(color: ColoresApp.azul, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
            if (nuevas > 0)
              Tooltip(
                message: 'Ver solicitudes nuevas',
                child: Material(
                  color: ColoresApp.rojo,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: flujo.verNuevas,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text(
                        '$nuevas',
                        style: const TextStyle(color: ColoresApp.blanco, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
            IconButton(
              onPressed: flujo.refrescarLista,
              tooltip: 'Actualizar',
              icon: const FaIcon(FontAwesomeIcons.arrowsRotate, color: ColoresApp.textoSuave, size: 16),
            ),
            IconButton(
              onPressed: onAlternar,
              tooltip: abierto ? 'Esconder solicitudes' : 'Ver solicitudes',
              style: IconButton.styleFrom(backgroundColor: ColoresApp.azulSuave),
              icon: AnimatedRotation(
                turns: abierto ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const FaIcon(FontAwesomeIcons.chevronUp, color: ColoresApp.azul, size: 15),
              ),
            ),
          ],
        ),
        if (!abierto)
          const SizedBox.shrink()
        else ...[
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
    // En una compra todavia sin comercio no hay partida: sin ella no hay distancia que mostrar.
    final metrosViaje = solicitud.tieneRuta
        ? ServiciosMapa.metros(solicitud.partida!.posicion, solicitud.destino!)
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
                  if (solicitud.datosEntrega != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        key: const ValueKey('tipo-envio-solicitud'),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: ColoresApp.rojoSuave, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          solicitud.datosEntrega!.tipoEnvio.nombre,
                          style: const TextStyle(color: ColoresApp.rojo, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ),
                  AvatarIniciales(nombre: solicitud.tercero?.nombre ?? solicitud.nombrePasajero, radio: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      solicitud.tercero == null ? solicitud.nombrePasajero : 'Para: ${solicitud.tercero!.nombre}',
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
                  _DatoPago(solicitud.metodoPago),
                  if (solicitud.tercero?.pagaSolicitante ?? false)
                    const DatoRuta(icono: FontAwesomeIcons.userCheck, texto: 'Paga quien pidió'),
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

  /// false: los botones Volver / Aceptar van fijos en el pie del panel ([BotonesDetalleSolicitud]).
  final bool conBotones;

  const PanelDetalleSolicitud({super.key, required this.flujo, required this.onAceptar, this.conBotones = true});

  @override
  Widget build(BuildContext context) {
    final solicitud = flujo.seleccionada;
    if (solicitud == null) return const SizedBox.shrink();
    final ruta = flujo.mapa.ruta;
    final acercamiento = flujo.mapa.acercamiento;
    final esDelivery = solicitud.datosEntrega != null;
    final comision = flujo.precio?.comisionPorcentaje ?? 0;
    final ganancia = solicitud.precio == null ? null : solicitud.precio! * (1 - comision / 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AvatarIniciales(nombre: solicitud.tercero?.nombre ?? solicitud.nombrePasajero, radio: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    solicitud.tercero?.nombre ?? solicitud.nombrePasajero,
                    style: const TextStyle(color: ColoresApp.azul, fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    solicitud.tercero == null
                        ? 'Pasajero'
                        : 'Pasajero. Lo pidió ${solicitud.nombrePasajero}'
                              '${solicitud.tercero!.pagaSolicitante ? ', que paga por QR' : ''}',
                    style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
                  ),
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
          etiqueta: MetodoPago.frase('Cobras', solicitud.metodoPago),
          detalle: [
            if (solicitud.descuentoEstudiante > 0)
              'Estudiante UAP: ${formatoBs(solicitud.precioNormal)} menos ${formatoBs(solicitud.descuentoEstudiante)}',
            if (!esDelivery && ganancia != null)
              'Tu ganancia: ${formatoBs(ganancia)} (comisión ${comision.toStringAsFixed(0)}%)',
          ].join('\n'),
          monto: formatoBs(solicitud.precio),
        ),
        if (conBotones) ...[const SizedBox(height: 14), BotonesDetalleSolicitud(flujo: flujo, onAceptar: onAceptar)],
      ],
    );
  }
}

/// Volver a la lista o aceptar la solicitud elegida.
class BotonesDetalleSolicitud extends StatelessWidget {
  final FlujoConductor flujo;
  final VoidCallback onAceptar;

  const BotonesDetalleSolicitud({super.key, required this.flujo, required this.onAceptar});

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

/// Texto y color del estado del viaje para el conductor, y el boton del siguiente paso ('' si no hay).
(String, Color, String, Color) estadoViajeConductor(Viaje viaje) => switch (viaje.situacion) {
  SituacionViaje.confirmado => (
    'Viaje aceptado. Avisa que vas en camino.',
    ColoresApp.exito,
    'Voy en camino',
    ColoresApp.azul,
  ),
  SituacionViaje.enCamino => (
    'Ve a recoger a ${viaje.tercero?.primerNombre ?? viaje.primerNombrePasajero} (punto A)',
    ColoresApp.ruta,
    'Llegué al punto de partida',
    ColoresApp.azul,
  ),
  SituacionViaje.llego => (
    'Esperando a ${viaje.tercero?.primerNombre ?? viaje.primerNombrePasajero}',
    ColoresApp.rojo,
    'Iniciar viaje',
    ColoresApp.azul,
  ),
  SituacionViaje.enCurso => ('En viaje hacia el destino (B)', ColoresApp.azul, 'Finalizar viaje', ColoresApp.rojo),
  _ => (SituacionViaje.nombre(viaje.situacion), ColoresApp.textoSuave, '', ColoresApp.azul),
};

/// Viaje en curso del conductor: estado, pasajero, lugares y el boton del siguiente paso.
class PanelViajeConductor extends StatelessWidget {
  final FlujoConductor flujo;
  final VoidCallback onAvanzar;
  final VoidCallback onCancelar;

  /// Cambiar el metodo de pago (efectivo o QR) directamente.
  final ValueChanged<String> onCambiarPago;

  /// Aceptar (true) o rechazar el cambio de pago que pidio el pasajero.
  final ValueChanged<bool> onResponderPago;

  /// false: el boton del siguiente paso va fijo en el pie del panel (siempre a la vista).
  final bool conBotonPrincipal;

  const PanelViajeConductor({
    super.key,
    required this.flujo,
    required this.onAvanzar,
    required this.onCancelar,
    required this.onCambiarPago,
    required this.onResponderPago,
    this.conBotonPrincipal = true,
  });

  @override
  Widget build(BuildContext context) {
    final viaje = flujo.viaje;
    if (viaje == null) return const SizedBox.shrink();
    if (viaje.datosEntrega != null) {
      // El reparto necesita los datos del pedido (ruta, monto, chat y cancelar) ademas del formulario
      // de la accion del momento; si no, el repartidor va a la deriva con el mapa tapado.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResumenEntregaConductor(
            viaje: viaje,
            onCancelar: onCancelar,
            ocupado: flujo.ocupado,
            botonChat: BotonChat(idViaje: viaje.id, nombreContraparte: viaje.nombrePasajero),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1)),
          PanelDeliveryConductor(flujo: flujo),
        ],
      );
    }
    final (texto, color, boton, colorBoton) = estadoViajeConductor(viaje);
    final distanciaDestino = flujo.metrosDesdeMi(viaje.destino);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Text(
            texto,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            AvatarIniciales(nombre: viaje.nombreQuienViaja, radio: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    viaje.nombreQuienViaja,
                    style: const TextStyle(color: ColoresApp.azul, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (viaje.tercero != null)
                    Text(
                      'Lo pidió ${viaje.nombrePasajero}',
                      style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
                    ),
                ],
              ),
            ),
            if (viaje.tercero?.telefono != null)
              IconButton(
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: viaje.tercero!.telefono)),
                tooltip: 'Llamar a ${viaje.tercero!.primerNombre}',
                icon: const FaIcon(FontAwesomeIcons.phone, size: 16, color: ColoresApp.azul),
              ),
            BotonChat(idViaje: viaje.id, nombreContraparte: viaje.nombrePasajero),
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
        if (viaje.metodoPagoPedido != null) ...[
          _PedidoCambioPago(viaje: viaje, ocupado: flujo.ocupado, onResponder: onResponderPago),
          const SizedBox(height: 10),
        ],
        RecuadroPrecio(
          etiqueta: viaje.pagaSolicitante ? 'Lo paga quien pidió (QR)' : MetodoPago.frase('Cobra', viaje.metodoPago),
          monto: formatoBs(viaje.precioFinal),
        ),
        if (viaje.pagaConQr) ...[
          const SizedBox(height: 8),
          _EstadoPagoQr(viaje: viaje, ocupado: flujo.ocupado, onConfirmar: flujo.confirmarPagoRecibido),
        ],
        if (viaje.pagaConQr && !viaje.conductorTieneQr) ...[
          const SizedBox(height: 8),
          const _Mensaje(
            icono: FontAwesomeIcons.triangleExclamation,
            texto: 'No tienes QR registrado. Agrégalo en Perfil > Mis QR de cobro o cambia el cobro a efectivo.',
            color: ColoresApp.rojo,
          ),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: flujo.ocupado
                ? null
                : () => onCambiarPago(viaje.pagaConQr ? MetodoPago.efectivo : MetodoPago.qr),
            icon: FaIcon(viaje.pagaConQr ? FontAwesomeIcons.moneyBill1 : FontAwesomeIcons.qrcode, size: 14),
            label: Text(viaje.pagaConQr ? 'Cobrar en efectivo' : 'Cobrar por QR'),
          ),
        ),
        const SizedBox(height: 4),
        if (viaje.situacion == SituacionViaje.llego) ...[
          _EsperaPasajero(viaje: viaje, flujo: flujo),
          const SizedBox(height: 8),
        ],
        if (boton.isNotEmpty && conBotonPrincipal)
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

/// El conductor llego y espera: puede avisar de nuevo al pasajero (hasta 3 avisos, 1 minuto entre
/// cada uno), llamarlo y, un minuto despues del tercer aviso, marcar que no se presento (cancela sin
/// republicar y deja un reporte para el admin).
class _EsperaPasajero extends StatefulWidget {
  final Viaje viaje;
  final FlujoConductor flujo;

  const _EsperaPasajero({required this.viaje, required this.flujo});

  @override
  State<_EsperaPasajero> createState() => _EsperaPasajeroState();
}

class _EsperaPasajeroState extends State<_EsperaPasajero> {
  static const _maximo = 3;
  static const _espera = Duration(minutes: 1);
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    // Cada segundo, para la cuenta regresiva del proximo aviso.
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  int get _faltan {
    final ultimo = widget.viaje.ultimoAvisoEspera;
    if (ultimo == null) return 0;
    final resto = _espera - DateTime.now().difference(ultimo);
    return resto.isNegative ? 0 : resto.inSeconds + 1;
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    try {
      await accion();
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    }
  }

  Future<void> _noSePresento() async {
    final comentario = await _pedirComentario(context);
    if (comentario == null || !mounted) return;
    await _ejecutar(() => widget.flujo.pasajeroNoSePresento(comentario));
  }

  @override
  Widget build(BuildContext context) {
    final viaje = widget.viaje;
    final avisos = viaje.avisosEspera < 1 ? 1 : viaje.avisosEspera;
    final faltan = _faltan;
    final telefono = viaje.tercero?.telefono ?? viaje.telefonoPasajero;
    final quien = viaje.tercero?.primerNombre ?? viaje.primerNombrePasajero;
    const naranja = Color(0xFFE67E22);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: naranja.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: naranja.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Esperando a $quien: aviso $avisos de $_maximo',
            style: const TextStyle(color: naranja, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            avisos < _maximo
                ? (faltan > 0 ? 'Podrás avisar de nuevo en $faltan s.' : 'Si no aparece, avísale de nuevo.')
                : (faltan > 0
                      ? 'Llámalo. Si no aparece, en $faltan s podrás marcar que no se presentó.'
                      : 'Si no aparece, marca que no se presentó: el administrador revisará el caso.'),
            style: const TextStyle(color: ColoresApp.texto, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (telefono != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: telefono)),
                    icon: const FaIcon(FontAwesomeIcons.phone, size: 13),
                    label: Text('Llamar a $quien', overflow: TextOverflow.ellipsis),
                  ),
                ),
              if (telefono != null) const SizedBox(width: 8),
              Expanded(
                child: avisos < _maximo
                    ? OutlinedButton.icon(
                        onPressed: widget.flujo.ocupado || faltan > 0
                            ? null
                            : () => _ejecutar(widget.flujo.avisarEspera),
                        icon: const FaIcon(FontAwesomeIcons.bell, size: 13),
                        label: const Text('Avisar de nuevo'),
                      )
                    : OutlinedButton.icon(
                        onPressed: widget.flujo.ocupado || faltan > 0 ? null : _noSePresento,
                        style: OutlinedButton.styleFrom(foregroundColor: ColoresApp.rojo),
                        icon: const FaIcon(FontAwesomeIcons.userXmark, size: 13),
                        label: const Text('No se presentó', overflow: TextOverflow.ellipsis),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Comentario obligatorio al reportar que el pasajero no se presento (lo lee el admin).
Future<String?> _pedirComentario(BuildContext context) {
  final controlador = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (contexto) => StatefulBuilder(
      builder: (contexto, actualizar) => AlertDialog(
        title: const Text('El pasajero no se presentó'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'El viaje se cancelará y quedará un reporte para que el administrador lo revise. '
              'Cuenta qué pasó (por ejemplo, si lo llamaste).',
              style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controlador,
              maxLines: 3,
              maxLength: 500,
              onChanged: (_) => actualizar(() {}),
              decoration: const InputDecoration(labelText: 'Comentario'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(contexto).pop(), child: const Text('Volver')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ColoresApp.rojo),
            onPressed: controlador.text.trim().isEmpty
                ? null
                : () => Navigator.of(contexto).pop(controlador.text.trim()),
            child: const Text('Cancelar y reportar'),
          ),
        ],
      ),
    ),
  );
}

/// Pago por QR del viaje: el conductor confirma cuando le llega (lo pague quien pidio o quien viaja).
class _EstadoPagoQr extends StatelessWidget {
  final Viaje viaje;
  final bool ocupado;
  final Future<void> Function() onConfirmar;

  const _EstadoPagoQr({required this.viaje, required this.ocupado, required this.onConfirmar});

  @override
  Widget build(BuildContext context) {
    if (viaje.pagoRecibidoEn != null) {
      return const _Mensaje(
        icono: FontAwesomeIcons.circleCheck,
        texto: 'Confirmaste que recibiste el pago por QR.',
        color: ColoresApp.exito,
      );
    }
    final texto = viaje.pagaSolicitante
        ? viaje.pagoAvisadoEn != null
              ? '${viaje.primerNombrePasajero} avisó que ya pagó por QR. Revisa tu banco y confírmalo.'
              : '${viaje.primerNombrePasajero} pagará por QR desde su app. Todavía no avisó el pago.'
        : 'Cobra por QR. Confirma cuando te llegue el pago.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Mensaje(icono: FontAwesomeIcons.qrcode, texto: texto, color: const Color(0xFFE67E22)),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: ocupado ? null : () => _confirmar(context),
          icon: const FaIcon(FontAwesomeIcons.check, size: 14),
          label: const Text('Confirmar pago recibido'),
        ),
      ],
    );
  }

  Future<void> _confirmar(BuildContext context) async {
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Recibiste el pago?',
      mensaje: 'Confirma que te llegaron ${formatoBs(viaje.precioFinal)} por QR.',
      textoConfirmar: 'Sí, lo recibí',
    );
    if (!confirmado) return;
    try {
      await onConfirmar();
    } on ApiExcepcion catch (e) {
      if (context.mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    }
  }
}

/// Metodo de pago de una solicitud, en la tarjeta de la lista.
class _DatoPago extends StatelessWidget {
  final String metodoPago;

  const _DatoPago(this.metodoPago);

  @override
  Widget build(BuildContext context) => DatoRuta(
    icono: metodoPago == MetodoPago.qr ? FontAwesomeIcons.qrcode : FontAwesomeIcons.moneyBill1,
    texto: metodoPago == MetodoPago.qr ? 'Paga por QR' : 'Paga en efectivo',
  );
}

/// El pasajero pidio pagar de otra forma: el conductor acepta o rechaza.
class _PedidoCambioPago extends StatelessWidget {
  final Viaje viaje;
  final bool ocupado;
  final ValueChanged<bool> onResponder;

  const _PedidoCambioPago({required this.viaje, required this.ocupado, required this.onResponder});

  @override
  Widget build(BuildContext context) {
    const naranja = Color(0xFFE67E22);
    final pedido = viaje.metodoPagoPedido ?? MetodoPago.efectivo;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: naranja.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: naranja.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${viaje.primerNombrePasajero} pide pagar ${pedido == MetodoPago.qr ? 'por QR' : 'en efectivo'}',
            style: const TextStyle(color: naranja, fontWeight: FontWeight.w700, fontSize: 14.5),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: ocupado ? null : () => onResponder(false),
                style: TextButton.styleFrom(foregroundColor: ColoresApp.rojo),
                child: const Text('Rechazar'),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: ocupado ? null : () => onResponder(true),
                style: FilledButton.styleFrom(backgroundColor: ColoresApp.exito),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nombre de un documento obligatorio para los avisos.
String _nombreDocumento(String tipo) => switch (tipo) {
  'CI' => 'carnet de identidad',
  'LICENCIA' => 'licencia de conducir',
  _ => tipo.toLowerCase(),
};

/// La cuenta todavia no esta aprobada o le faltan documentos: explica que falta y deja subirlos o
/// volver a consultar.
class _EnRevision extends StatelessWidget {
  final String? situacion;
  final List<String> faltantes;
  final VoidCallback? onRevisar;
  final VoidCallback? onSubirDocumentos;

  const _EnRevision({
    required this.situacion,
    required this.faltantes,
    required this.onRevisar,
    this.onSubirDocumentos,
  });

  @override
  Widget build(BuildContext context) {
    final (titulo, texto, color) = switch (situacion) {
      _ when faltantes.isNotEmpty => (
        'Faltan documentos',
        'Para usar la app sube el PDF de tu ${faltantes.map(_nombreDocumento).join(' y ')}. Puedes hacerlo en Perfil > Mis documentos.',
        ColoresApp.rojo,
      ),
      'RECHAZADO' => (
        'Registro rechazado',
        'La administración rechazó tu registro. Revisa tus documentos en Perfil > Mis documentos o comunícate con UNITAXI.',
        ColoresApp.rojo,
      ),
      'SUSPENDIDO' => (
        'Cuenta suspendida',
        'Tu cuenta de conductor está suspendida. Comunícate con la administración de UNITAXI.',
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
              child: Center(
                child: FaIcon(
                  faltantes.isNotEmpty ? FontAwesomeIcons.fileCircleExclamation : FontAwesomeIcons.hourglassHalf,
                  color: color,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titulo,
                style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(texto, style: const TextStyle(color: ColoresApp.texto, fontSize: 14, height: 1.4)),
        if (faltantes.isNotEmpty && onSubirDocumentos != null) ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onSubirDocumentos,
            style: FilledButton.styleFrom(
              backgroundColor: ColoresApp.rojo,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const FaIcon(FontAwesomeIcons.fileArrowUp, size: 15),
            label: const Text('Subir mis documentos', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ] else if (onRevisar != null) ...[
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
          Expanded(
            child: Text(texto, style: TextStyle(color: color == ColoresApp.textoSuave ? ColoresApp.texto : color)),
          ),
        ],
      ),
    );
  }
}
