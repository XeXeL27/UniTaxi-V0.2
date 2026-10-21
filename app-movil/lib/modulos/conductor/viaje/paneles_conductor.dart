import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/iconos.dart';
import '../../../widgets/guia_inicio.dart';
import '../../../widgets/dialogos.dart';
import '../../../core/api_excepcion.dart';


import '../../../core/formato.dart';
import '../../../core/sesion.dart';
import '../../../core/tema.dart';
import '../../../widgets/boton_plegar.dart';
import '../../../widgets/boton_principal.dart';
import '../../../widgets/notificaciones.dart';
import '../../../widgets/paneles.dart';
import 'espera_cronometro.dart';
import 'flujo_conductor.dart';
import '../../../comun/modelos_viaje.dart';
import '../../../comun/vista_chat.dart';
import '../../login/ayuda_ingreso.dart';
import 'panel_delivery_conductor.dart';
import 'tarjetas_conductor.dart';

String _km(double? metros) {
  if (metros == null) return '-';
  if (metros < 1000) return '${metros.round()} m';
  return '${(metros / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// Inicio del conductor sin viaje: "Solicitudes cerca" (con el boton azul se baja a una sola linea
/// para ver el mapa) o, desconectado, la invitacion a conectarse. Los botones Conectarme /
/// Desconectarme van fijos en el pie del panel.
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
    if (flujo.enRevision) {
      return _EnRevision(
        situacion: flujo.situacionAprobacion,
        faltantes: flujo.documentosFaltantes,
        onRevisar: onRevisarAprobacion,
        onSubirDocumentos: onSubirDocumentos,
      );
    }
    if (!flujo.enLinea) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '¿Listo para trabajar?',
            style: TextStyle(color: ColoresApp.tinta, fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            flujo.esRepartidor
                ? 'Conéctate para aparecer en el mapa y recibir pedidos de entrega.'
                : 'Conéctate para aparecer en el mapa y recibir solicitudes.',
            style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 14),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                flujo.esRepartidor ? 'Pedidos cerca' : 'Solicitudes cerca',
                style: const TextStyle(color: ColoresApp.tinta, fontSize: 19, fontWeight: FontWeight.w800),
              ),
            ),
            if (lista.isNotEmpty)
              Container(
                constraints: const BoxConstraints(minWidth: 26),
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: ColoresApp.rojo, borderRadius: BorderRadius.circular(13)),
                child: Text(
                  '${lista.length}',
                  style: const TextStyle(color: ColoresApp.blanco, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            IconButton(
              onPressed: flujo.refrescarLista,
              tooltip: 'Actualizar',
              icon: const Icon(Iconos.arrowsRotate, color: ColoresApp.grisTexto, size: 15),
            ),
            const SizedBox(width: 4),
            BotonPlegarHoja(
              abierta: flujo.listaAbierta,
              onTap: flujo.alternarLista,
              textoBajar: 'Bajar para ver el mapa',
            ),
          ],
        ),
        // Bajado queda solo la linea del titulo (y el contador) para ver el mapa.
        if (flujo.listaAbierta) ...[
          const SizedBox(height: 8),
          if (!flujo.listaCargada)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: ColoresApp.azul)),
            )
          else if (flujo.errorLista != null)
            _Mensaje(icono: Iconos.circleExclamation, texto: flujo.errorLista!, color: ColoresApp.rojo)
          else if (lista.isEmpty)
            _Mensaje(
              icono: Iconos.hourglassHalf,
              texto: flujo.esRepartidor
                  ? 'No hay pedidos por ahora. Cuando un cliente pida una entrega te aparecerá aquí.'
                  : 'No hay solicitudes por ahora. Cuando un pasajero pida un taxi te aparecerá aquí.',
              color: ColoresApp.textoSuave,
            )
          else
            for (final solicitud in lista)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
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

/// Una solicitud de la lista: a quien, de donde, a cuanto de mi, el recorrido y lo que se cobra.
class _TarjetaSolicitud extends StatelessWidget {
  final Solicitud solicitud;
  final double? distanciaAMi;
  final VoidCallback onTap;

  const _TarjetaSolicitud({required this.solicitud, required this.distanciaAMi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // En una compra todavia sin comercio no hay partida: sin ella no hay distancia que mostrar.
    final metrosViaje = solicitud.metrosRecorrido;
    final esEntrega = solicitud.datosEntrega != null;
    final esCompra = solicitud.datosEntrega?.tipoEnvio == TipoEnvio.compraYEntrega;
    final datos = [
      if (distanciaAMi != null) 'A ${_km(distanciaAMi)} de ti',
      if (metrosViaje != null) '${esEntrega ? 'recorrido' : 'viaje'} de ${_km(metrosViaje)}',
      solicitud.metodoPago == MetodoPago.qr ? 'QR' : 'efectivo',
    ].join(' · ');
    return Material(
      color: ColoresApp.blanco,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ColoresApp.borde),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (esEntrega)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              key: const ValueKey('tipo-envio-solicitud'),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: ColoresApp.rojoSuave, borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                solicitud.datosEntrega!.tipoEnvio.nombre,
                                style: const TextStyle(color: ColoresApp.rojo, fontWeight: FontWeight.w700, fontSize: 11.5),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            solicitud.tercero == null ? solicitud.nombrePasajero : 'Para: ${solicitud.tercero!.nombre}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      // Una compra no tiene punto de recogida: se ve a donde se entrega.
                      esCompra ? solicitud.destinoDireccion : solicitud.origenDireccion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColoresApp.tinta, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      datos,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                // Una compra se cotiza recien con el comercio y el monto del producto.
                solicitud.precio == null && esCompra ? 'A calcular' : formatoBs(solicitud.precio),
                style: TextStyle(
                  color: ColoresApp.tinta,
                  fontWeight: FontWeight.w800,
                  fontSize: solicitud.precio == null ? 14 : 18,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Iconos.chevronRight, color: ColoresApp.grisTexto, size: 13),
            ],
          ),
        ),
      ),
    );
  }
}

/// Punto de una ruta resumida: circulo azul (partida) o cuadrado rojo (destino).
class _Punto extends StatelessWidget {
  final String texto;
  final bool destino;

  const _Punto(this.texto, {this.destino = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: destino ? ColoresApp.rojo : ColoresApp.azul,
              borderRadius: BorderRadius.circular(destino ? 2 : 5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: ColoresApp.tinta, fontSize: 14.5, fontWeight: destino ? FontWeight.w600 : FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recuadro gris con un dato del recorrido ("Hasta el pasajero: 600 m · 2 min").
class _Caja extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _Caja(this.etiqueta, this.valor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 12.5)),
          const SizedBox(height: 4),
          Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ColoresApp.tinta, fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Solicitud elegida (o recien llegada, con la cuenta regresiva de 15 s) con su ruta en el mapa:
/// cuanto se cobra, las distancias, la ruta y el cliente. Nunca muestra ganancias.
class PanelDetalleSolicitud extends StatelessWidget {
  final FlujoConductor flujo;
  final VoidCallback onAceptar;

  /// false: los botones Rechazar o Volver / Aceptar van fijos en el pie del panel
  /// ([BotonesDetalleSolicitud]).
  final bool conBotones;

  const PanelDetalleSolicitud({super.key, required this.flujo, required this.onAceptar, this.conBotones = true});

  @override
  Widget build(BuildContext context) {
    final solicitud = flujo.seleccionada;
    if (solicitud == null) return const SizedBox.shrink();
    final ruta = flujo.mapa.ruta;
    final acercamiento = flujo.mapa.acercamiento;
    final esEntrega = solicitud.datosEntrega != null;
    final esCompra = solicitud.datosEntrega?.tipoEnvio == TipoEnvio.compraYEntrega;
    final tipo = esEntrega ? solicitud.datosEntrega!.tipoEnvio.nombre : 'Moto taxi';
    final cobro = solicitud.tercero?.pagaSolicitante ?? false
        ? 'Lo paga quien pidió, por QR'
        : solicitud.metodoPago == MetodoPago.qr
        ? 'Cobras por QR'
        : 'Cobras en efectivo';
    final cliente = solicitud.tercero?.nombre ?? solicitud.nombrePasajero;
    final detalleCliente = [
      if (solicitud.tercero != null) 'Lo pidió ${enTitulo(solicitud.nombrePasajero.split(' ').first)}',
      if (esEntrega) solicitud.datosEntrega!.descripcion,
      if (solicitud.descuentoEstudiante > 0) 'Estudiante UAP',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFE8EEF6), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      flujo.conCuentaRegresiva ? 'Nueva solicitud · $tipo' : tipo,
                      style: const TextStyle(color: ColoresApp.azul, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(cobro, style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 13)),
                  Text(
                    solicitud.precio == null && esCompra ? 'A calcular' : formatoBs(solicitud.precio),
                    style: TextStyle(
                      color: ColoresApp.tinta,
                      fontSize: solicitud.precio == null ? 26 : 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            if (flujo.conCuentaRegresiva)
              CuentaRegresivaSolicitud(
                key: ValueKey('cuenta-${solicitud.id}'),
                pausada: flujo.ocupado,
                onTerminado: flujo.dejarPasarSolicitud,
              ),
          ],
        ),
        if (solicitud.descuentoEstudiante > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Estudiante UAP: precio normal ${formatoBs(solicitud.precioNormal)}, '
            '${formatoBs(solicitud.descuentoEstudiante)} menos',
            style: const TextStyle(color: ColoresApp.exito, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
        if (esCompra && solicitud.precio == null) ...[
          const SizedBox(height: 4),
          const Text(
            'El precio del envío se calcula con el comercio y el monto de la compra.',
            style: TextStyle(color: ColoresApp.grisTexto, fontSize: 12.5),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Caja(
                esCompra ? 'Hasta el cliente' : esEntrega ? 'Hasta la recogida' : 'Hasta el pasajero',
                acercamiento == null ? 'Calculando...' : '${acercamiento.distanciaTexto} · ${acercamiento.duracionTexto}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Caja(
                esEntrega ? 'Recorrido' : 'Viaje',
                ruta != null
                    ? '${ruta.distanciaTexto} · ${ruta.duracionTexto}'
                    // Una compra no tiene ruta hasta que el repartidor elige el comercio.
                    : esCompra
                    ? 'Según el comercio'
                    : 'Calculando...',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Una compra no tiene punto de recogida: el repartidor elige el comercio y entrega al cliente.
        if (!esCompra) _Punto(solicitud.origenDireccion),
        _Punto(solicitud.destinoDireccion, destino: true),
        const SizedBox(height: 12),
        Row(
          children: [
            AvatarIniciales(nombre: cliente, radio: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: enTitulo(cliente),
                      style: const TextStyle(color: ColoresApp.tinta, fontWeight: FontWeight.w700),
                    ),
                    if (detalleCliente.isNotEmpty) TextSpan(text: ' · $detalleCliente'),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 14),
              ),
            ),
          ],
        ),
        if (conBotones) ...[const SizedBox(height: 16), BotonesDetalleSolicitud(flujo: flujo, onAceptar: onAceptar)],
      ],
    );
  }
}

/// Rechazar (solicitud recien llegada) o Volver a la lista, y aceptar la solicitud.
class BotonesDetalleSolicitud extends StatelessWidget {
  final FlujoConductor flujo;
  final VoidCallback onAceptar;

  const BotonesDetalleSolicitud({super.key, required this.flujo, required this.onAceptar});

  @override
  Widget build(BuildContext context) {
    final aviso = flujo.conCuentaRegresiva;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 54,
            child: OutlinedButton(
              onPressed: flujo.ocupado ? null : (aviso ? flujo.rechazarSolicitud : flujo.volverALista),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColoresApp.tinta,
                side: const BorderSide(color: ColoresApp.borde, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              child: Text(aviso ? 'Rechazar' : 'Volver', maxLines: 1, softWrap: false),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: BotonPrincipal(
            texto: flujo.seleccionada?.datosEntrega != null ? 'Aceptar pedido' : 'Aceptar viaje',
            color: ColoresApp.azul,
            cargando: flujo.ocupado,
            onPressed: onAceptar,
          ),
        ),
      ],
    );
  }
}

/// Texto y color del estado del viaje para el conductor, y el paso siguiente ('' si no hay). Iniciar
/// y finalizar se deslizan (no se tocan por error con la moto en marcha).
(String, Color, String, Color) estadoViajeConductor(Viaje viaje) => switch (viaje.situacion) {
  SituacionViaje.confirmado => ('Viaje aceptado', ColoresApp.exito, 'Voy en camino', ColoresApp.azul),
  SituacionViaje.enCamino => (
    'Ve a recoger a ${viaje.tercero?.primerNombre ?? viaje.primerNombrePasajero}',
    ColoresApp.azul,
    'Llegué al punto de recogida',
    ColoresApp.azul,
  ),
  // "Esperando a Diego" ya lo dice el recuadro de la espera: aca va donde esta.
  SituacionViaje.llego => (
    'En el punto de recogida',
    const Color(0xFFC0610F),
    'Desliza para iniciar el viaje',
    ColoresApp.azul,
  ),
  SituacionViaje.enCurso => ('En viaje al destino', ColoresApp.azul, 'Desliza para finalizar', ColoresApp.azul),
  _ => (SituacionViaje.nombre(viaje.situacion), ColoresApp.textoSuave, '', ColoresApp.azul),
};

/// Viaje en curso del conductor (taxi): espera con cronometro, pasajero con llamar y mensaje, ruta,
/// cobro (QR o efectivo, cambio de pago) y cancelar. El paso siguiente va fijo en el pie del panel.
/// En un reparto muestra el pedido y las acciones con codigo y foto.
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
          // Llegada y espera (A o B) primero y despues la accion del paso (codigo, foto, cobro), a la
          // vista sin desplazar el panel; el resumen del pedido (con "Cancelar pedido") va al final.
          EsperaDelivery(flujo: flujo),
          PanelDeliveryConductor(flujo: flujo),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
          ResumenEntregaConductor(
            viaje: viaje,
            onCancelar: onCancelar,
            ocupado: flujo.ocupado,
            botonChat: BotonChat(idViaje: viaje.id, nombreContraparte: viaje.nombrePasajero),
          ),
        ],
      );
    }
    final (_, _, boton, colorBoton) = estadoViajeConductor(viaje);
    final distanciaDestino = flujo.metrosDesdeMi(viaje.destino);
    final cobro = viaje.pagaSolicitante
        ? 'Lo paga quien pidió (QR)'
        : viaje.pagaConQr
        ? 'Cobra por QR'
        : 'Cobra en efectivo';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Esperando al pasajero: el cronometro y los avisos van arriba, a la vista sin desplazar.
        if (viaje.situacion == SituacionViaje.llego) ...[
          _EsperaPasajero(viaje: viaje, flujo: flujo),
          const SizedBox(height: 12),
        ],
        MarcaGuia(
          id: 'conductor.cliente',
          child: FilaCliente(
            nombre: viaje.nombreQuienViaja,
            detalle: viaje.tercero != null
                ? 'Lo pidió ${enTitulo(viaje.nombrePasajero.split(' ').first)}'
                : '${formatoBs(viaje.precioFinal)} · ${viaje.pagaConQr ? 'QR' : 'Efectivo'}',
            telefono: viaje.tercero?.telefono ?? viaje.telefonoPasajero,
            idViaje: viaje.id,
          ),
        ),
        const Divider(height: 26, color: ColoresApp.borde),
        _Punto(viaje.origenDireccion),
        _Punto(viaje.destinoDireccion, destino: true),
        if (viaje.situacion == SituacionViaje.enCurso)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              distanciaDestino == null
                  ? 'Al llegar al destino desliza para finalizar y confirma que cobraste.'
                  : 'Faltan ${_km(distanciaDestino)} en línea recta. Al llegar desliza para finalizar y confirma que '
                        'cobraste.',
              style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 12.5),
            ),
          ),
        const SizedBox(height: 12),
        if (viaje.metodoPagoPedido != null) ...[
          _PedidoCambioPago(viaje: viaje, ocupado: flujo.ocupado, onResponder: onResponderPago),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Expanded(child: Text(cobro, style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 14))),
              Text(
                formatoBs(viaje.precioFinal),
                style: const TextStyle(color: ColoresApp.tinta, fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        if (viaje.pagaConQr) ...[
          const SizedBox(height: 8),
          _EstadoPagoQr(viaje: viaje, ocupado: flujo.ocupado, onConfirmar: flujo.confirmarPagoRecibido),
        ],
        if (viaje.pagaConQr && !viaje.conductorTieneQr) ...[
          const SizedBox(height: 8),
          const _Mensaje(
            icono: Iconos.triangleExclamation,
            texto: 'No tienes QR registrado. Agrégalo en Perfil > Mis QR de cobro o cambia el cobro a efectivo.',
            color: ColoresApp.rojo,
          ),
        ],
        if (!viaje.pagaSolicitante)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: flujo.ocupado ? null : () => onCambiarPago(viaje.pagaConQr ? MetodoPago.efectivo : MetodoPago.qr),
              style: TextButton.styleFrom(foregroundColor: ColoresApp.azul),
              child: Text(
                viaje.pagaConQr ? 'Cobrar en efectivo' : 'Cobrar por QR',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        if (boton.isNotEmpty && conBotonPrincipal)
          BotonPrincipal(texto: boton, color: colorBoton, cargando: flujo.ocupado, onPressed: onAvanzar),
        if (SituacionViaje.cancelables.contains(viaje.situacion))
          Center(
            child: TextButton(
              onPressed: flujo.ocupado ? null : onCancelar,
              style: TextButton.styleFrom(foregroundColor: ColoresApp.rojoOscuro),
              child: const Text('Cancelar viaje', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}

/// El conductor del taxi llego y espera al pasajero (o a quien viaja): avisos con cronometro y, tras
/// el tercero, seguir esperando o reportar que no se presento (cancela sin republicar).
class _EsperaPasajero extends StatelessWidget {
  final Viaje viaje;
  final FlujoConductor flujo;

  const _EsperaPasajero({required this.viaje, required this.flujo});

  @override
  Widget build(BuildContext context) => EsperaConCronometro(
    quien: viaje.tercero?.primerNombre ?? viaje.primerNombrePasajero,
    avisos: viaje.avisosEspera,
    ultimoAviso: viaje.ultimoAvisoEspera,
    telefono: viaje.tercero?.telefono ?? viaje.telefonoPasajero,
    ocupado: flujo.ocupado,
    onAvisar: flujo.avisarEspera,
    onReportar: () async {
      final comentario = await pedirMotivo(
        context,
        titulo: 'El pasajero no se presentó',
        explicacion:
            'El viaje se cancelará y quedará un reporte para que el administrador lo revise. '
            'Cuenta qué pasó (por ejemplo, si lo llamaste).',
      );
      if (comentario == null) return;
      await flujo.pasajeroNoSePresento(comentario);
    },
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
        icono: Iconos.circleCheck,
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
        _Mensaje(icono: Iconos.qrcode, texto: texto, color: const Color(0xFFE67E22)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: ocupado ? null : () => _confirmar(context),
          icon: const Icon(Iconos.check, size: 14),
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
      if (context.mounted) mostrarMensaje(context, e.mensaje, error: true);
    }
  }
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
              const SizedBox(width: 8),
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
        'La administración rechazó tu registro. Revisa tus documentos en Perfil > Mis documentos o envía un mensaje al '
            'administrador.',
        ColoresApp.rojo,
      ),
      'SUSPENDIDO' => (
        'Cuenta suspendida',
        'Tu cuenta de conductor está suspendida. Envía un mensaje al administrador para que revise tu caso.',
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
                child: Icon(
                  faltantes.isNotEmpty ? Iconos.fileCircleExclamation : Iconos.hourglassHalf,
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
        const SizedBox(height: 12),
        Text(texto, style: const TextStyle(color: ColoresApp.texto, fontSize: 14, height: 1.4)),
        if (faltantes.isNotEmpty && onSubirDocumentos != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onSubirDocumentos,
            style: FilledButton.styleFrom(
              backgroundColor: ColoresApp.rojo,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Iconos.fileArrowUp, size: 15),
            label: const Text('Subir mis documentos', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ] else if (situacion == 'SUSPENDIDO' || situacion == 'RECHAZADO') ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => abrirAyudaIngreso(
              context,
              identificador: context.read<Sesion>().usuario?.nombreUsuario ?? '',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: ColoresApp.rojo,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Iconos.commentDots, size: 15),
            label: const Text('Enviar mensaje al administrador', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (onRevisar != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRevisar,
                icon: const Icon(Iconos.arrowsRotate, size: 14),
                label: const Text('Ver si ya me aprobaron'),
              ),
            ),
        ] else if (onRevisar != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRevisar,
              icon: const Icon(Iconos.arrowsRotate, size: 14),
              label: const Text('Ver si ya me aprobaron'),
            ),
          ),
        ],
      ],
    );
  }
}

class _Mensaje extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;

  const _Mensaje({required this.icono, required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ColoresApp.fondo, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texto, style: TextStyle(color: color == ColoresApp.textoSuave ? ColoresApp.texto : color)),
          ),
        ],
      ),
    );
  }
}
