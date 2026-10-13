import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../comun/modelos_viaje.dart';
import '../../../comun/vista_chat.dart';
import '../../../core/chat.dart';
import '../../../core/enlaces.dart';
import '../../../core/formato.dart';
import '../../../core/iconos.dart';
import '../../../core/tema.dart';
import '../../../widgets/inicio_mapa.dart';
import '../../../widgets/notificaciones.dart';
import '../../../widgets/paneles.dart';

/// Abre Google Maps con la ruta hasta [punto] (la app de Maps en Android; el navegador si no esta).
Future<void> abrirEnMaps(BuildContext context, LatLng punto) {
  final destino = '${punto.latitude},${punto.longitude}';
  return abrirEnlaceExterno(
    context,
    Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': destino, 'travelmode': 'driving'}),
    destino,
  );
}

/// Tarjeta de arriba del conductor: su foto (lleva a Perfil), el estado ("En linea", "Desconectado")
/// y cuantos viajes o entregas hizo hoy. Nunca muestra lo que gano.
class TarjetaEstadoConductor extends StatelessWidget {
  final Uint8List? foto;
  final Color colorPunto;
  final String titulo;
  final String subtitulo;

  /// "7 viajes" o "5 entregas"; null mientras no se sabe.
  final String? hoy;
  final VoidCallback onPerfil;
  final VoidCallback onAyuda;

  const TarjetaEstadoConductor({
    super.key,
    required this.foto,
    required this.colorPunto,
    required this.titulo,
    required this.subtitulo,
    required this.hoy,
    required this.onPerfil,
    required this.onAyuda,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColoresApp.blanco,
      elevation: 5,
      shadowColor: const Color(0x330A2342),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          children: [
            Tooltip(
              message: 'Tu perfil',
              child: InkWell(
                onTap: onPerfil,
                customBorder: const CircleBorder(),
                child: AvatarCabecera(foto: foto, iconoSinFoto: Iconos.motorcycle, tamano: 44),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: colorPunto, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: ColoresApp.tinta, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    subtitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (hoy != null) ...[
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Hoy', style: TextStyle(color: ColoresApp.grisTexto, fontSize: 12)),
                  Text(
                    hoy!,
                    style: const TextStyle(color: ColoresApp.tinta, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
            IconButton(
              onPressed: onAyuda,
              tooltip: 'Ayuda',
              icon: const Icon(Iconos.headset, color: ColoresApp.tinta, size: 17),
            ),
          ],
        ),
      ),
    );
  }
}

/// Franja azul de arriba durante el viaje: a donde ir ahora y "Abrir en Maps".
class BannerDestino extends StatelessWidget {
  final String etiqueta;
  final String lugar;
  final LatLng? punto;

  const BannerDestino({super.key, required this.etiqueta, required this.lugar, required this.punto});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColoresApp.azul,
      elevation: 6,
      shadowColor: const Color(0x550A2342),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            const Icon(Iconos.locationDot, color: ColoresApp.blanco, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFC7D2E0), fontSize: 13),
                  ),
                  Text(
                    lugar,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ColoresApp.blanco, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            if (punto != null) ...[
              const SizedBox(width: 8),
              Material(
                color: ColoresApp.blanco,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => abrirEnMaps(context, punto!),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'Abrir en Maps',
                      style: TextStyle(color: ColoresApp.azul, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pestañas del repartidor con varios pedidos: el nombre del cliente y la etapa de cada uno.
class PestanasPedidos extends StatelessWidget {
  final List<Viaje> pedidos;
  final int? idActual;
  final int maximo;

  /// "5 entregas" hoy; null mientras no se sabe.
  final String? hoy;
  final ValueChanged<Viaje> onElegir;

  const PestanasPedidos({
    super.key,
    required this.pedidos,
    required this.idActual,
    required this.maximo,
    required this.hoy,
    required this.onElegir,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColoresApp.blanco,
      elevation: 5,
      shadowColor: const Color(0x330A2342),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: ColoresApp.rojo, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${pedidos.length} de $maximo pedidos',
                      style: const TextStyle(color: ColoresApp.tinta, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (hoy != null)
                    Text.rich(
                      TextSpan(
                        text: 'Hoy: ',
                        children: [
                          TextSpan(
                            text: hoy,
                            style: const TextStyle(color: ColoresApp.tinta, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 13),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: ColoresApp.gris, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  for (var i = 0; i < pedidos.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _Pestana(
                        viaje: pedidos[i],
                        elegida: pedidos[i].id == idActual,
                        onTap: () => onElegir(pedidos[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  final Viaje viaje;
  final bool elegida;
  final VoidCallback onTap;

  const _Pestana({required this.viaje, required this.elegida, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: elegida,
      button: true,
      child: Material(
        color: elegida ? ColoresApp.azul : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            height: 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  viaje.primerNombrePasajero,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: elegida ? ColoresApp.blanco : ColoresApp.tinta,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  etapaCortaPedido(viaje),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: elegida ? const Color(0xFFC7D2E0) : ColoresApp.grisTexto, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Paso 1 de 2" (recoger o comprar) o "Paso 2 de 2" (entregar) de un pedido.
String pasoDelPedido(Viaje viaje) {
  final datos = viaje.datosEntrega;
  final conPaquete =
      datos != null &&
      (datos.esperandoEnEntrega ||
          datos.estadoEntrega == EstadoEntrega.enMano ||
          datos.estadoEntrega == EstadoEntrega.entregado);
  return conPaquete ? 'Paso 2 de 2' : 'Paso 1 de 2';
}

/// Etapa de un pedido en una palabra o dos, para las pestañas.
String etapaCortaPedido(Viaje viaje) {
  final datos = viaje.datosEntrega;
  if (datos == null) return SituacionViaje.nombre(viaje.situacion);
  if (datos.esperandoEnEntrega) return 'En la entrega';
  return switch (datos.estadoEntrega) {
    EstadoEntrega.enMano => 'En mano',
    EstadoEntrega.entregado => 'Entregado',
    _ when datos.tipoEnvio == TipoEnvio.compraYEntrega => 'Comprar',
    _ => 'Recoger',
  };
}

/// Cliente o pasajero con los botones de llamar y de mensaje (con los no leidos).
class FilaCliente extends StatelessWidget {
  final String nombre;
  final String detalle;
  final String? telefono;
  final int idViaje;

  const FilaCliente({
    super.key,
    required this.nombre,
    required this.detalle,
    required this.telefono,
    required this.idViaje,
  });

  @override
  Widget build(BuildContext context) {
    final noLeidos = context.select<ChatEstado, int>((chat) => chat.noLeidosDe(idViaje));
    final numero = telefono?.trim() ?? '';
    return VinculoChat(
      idViaje: idViaje,
      nombreContraparte: nombre,
      child: Row(
        children: [
          AvatarIniciales(nombre: nombre, radio: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enTitulo(nombre),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ColoresApp.tinta, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                Text(
                  detalle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 13.5),
                ),
              ],
            ),
          ),
          _BotonRedondo(
            icono: Iconos.phone,
            tooltip: 'Llamar',
            onTap: numero.isEmpty
                ? () => mostrarMensaje(context, 'El celular no está disponible.', error: true)
                : () => abrirEnlaceExterno(context, Uri(scheme: 'tel', path: numero), numero),
          ),
          const SizedBox(width: 8),
          _BotonRedondo(
            icono: Iconos.message,
            tooltip: 'Mensaje',
            insignia: noLeidos,
            onTap: () => abrirChat(context, idViaje: idViaje, nombreContraparte: nombre),
          ),
        ],
      ),
    );
  }
}

class _BotonRedondo extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final VoidCallback onTap;
  final int insignia;

  const _BotonRedondo({required this.icono, required this.tooltip, required this.onTap, this.insignia = 0});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Badge(
        isLabelVisible: insignia > 0,
        backgroundColor: ColoresApp.rojo,
        label: Text('$insignia', style: const TextStyle(color: ColoresApp.blanco, fontSize: 10)),
        child: Material(
          color: ColoresApp.gris,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Center(child: Icon(icono, color: ColoresApp.tinta, size: 17)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Anillo con los segundos que quedan para responder una solicitud nueva. Al llegar a 0 llama a
/// [onTerminado] (se trata como rechazada).
class CuentaRegresivaSolicitud extends StatefulWidget {
  static const Duration duracion = Duration(seconds: 15);

  final VoidCallback onTerminado;

  /// Mientras se acepta la cuenta se detiene: no debe rechazarse sola a mitad de la respuesta.
  final bool pausada;

  const CuentaRegresivaSolicitud({super.key, required this.onTerminado, this.pausada = false});

  @override
  State<CuentaRegresivaSolicitud> createState() => _CuentaRegresivaSolicitudState();
}

class _CuentaRegresivaSolicitudState extends State<CuentaRegresivaSolicitud> with SingleTickerProviderStateMixin {
  late final AnimationController _reloj = AnimationController(vsync: this, duration: CuentaRegresivaSolicitud.duracion)
    ..addStatusListener((estado) {
      if (estado == AnimationStatus.completed && mounted) widget.onTerminado();
    })
    ..forward();

  @override
  void didUpdateWidget(covariant CuentaRegresivaSolicitud anterior) {
    super.didUpdateWidget(anterior);
    if (widget.pausada && _reloj.isAnimating) {
      _reloj.stop();
    } else if (!widget.pausada && !_reloj.isAnimating && !_reloj.isCompleted) {
      _reloj.forward();
    }
  }

  @override
  void dispose() {
    _reloj.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _reloj,
      builder: (context, _) {
        final quedan = (CuentaRegresivaSolicitud.duracion.inSeconds * (1 - _reloj.value)).ceil();
        return Semantics(
          label: 'Quedan $quedan segundos para responder',
          child: SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: 1 - _reloj.value,
                    strokeWidth: 6,
                    color: quedan <= 5 ? ColoresApp.rojo : ColoresApp.azul,
                    backgroundColor: ColoresApp.borde,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '$quedan',
                  style: const TextStyle(color: ColoresApp.tinta, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
