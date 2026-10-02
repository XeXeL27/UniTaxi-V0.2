import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../core/iconos.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/api_excepcion.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../widgets/dialogos.dart';
import '../../widgets/insignia_estado.dart';
import 'expediente_api.dart';
import 'modelos.dart';

/// Abre un expediente (conductor o pasajero) en un modal grande; en pantallas angostas ocupa todo.
Future<void> abrirExpediente(BuildContext context, Widget expediente) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      if (Pantalla.esMovil(context)) return Dialog.fullscreen(child: expediente);
      final tamano = MediaQuery.sizeOf(context);
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiosApp.tarjeta)),
        child: SizedBox(width: tamano.width > 1180 ? 1100 : tamano.width - 48, height: tamano.height * 0.88, child: expediente),
      );
    },
  );
}

/// Cabecera con la foto y el nombre, y las pestanas del expediente.
class MarcoExpediente extends StatelessWidget {
  final Widget foto;
  final String titulo;
  final String subtitulo;
  final String? situacion;
  final List<(IconData, String)> pestanas;
  final List<Widget> vistas;

  const MarcoExpediente({
    super.key,
    required this.foto,
    required this.titulo,
    required this.subtitulo,
    this.situacion,
    required this.pestanas,
    required this.vistas,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: pestanas.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: ColoresApp.azul,
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    foto,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(subtitulo, style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                        ],
                      ),
                    ),
                    if (situacion != null) InsigniaEstado(situacion!),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Iconos.xmark, color: Colors.white, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: ColoresApp.rojo,
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                  tabs: [
                    for (final (icono, texto) in pestanas)
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [Icon(icono, size: 14, color: Colors.white70), const SizedBox(width: 8), Text(texto)],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ColoredBox(color: ColoresApp.fondo, child: TabBarView(children: vistas)),
          ),
        ],
      ),
    );
  }
}

/// Carga datos del backend con reintento; [builder] recibe los datos y la funcion para recargar.
class Carga<T> extends StatefulWidget {
  final Future<T> Function() cargar;
  final Widget Function(T datos, VoidCallback recargar) builder;

  const Carga({super.key, required this.cargar, required this.builder});

  @override
  State<Carga<T>> createState() => _CargaState<T>();
}

class _CargaState<T> extends State<Carga<T>> {
  late Future<T> _futuro = widget.cargar();

  void _recargar() => setState(() => _futuro = widget.cargar());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _futuro,
      builder: (context, instantanea) {
        if (instantanea.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${instantanea.error}', style: const TextStyle(color: ColoresApp.rojo)),
                TextButton(onPressed: _recargar, child: const Text('Reintentar')),
              ],
            ),
          );
        }
        if (!instantanea.hasData) {
          return const Center(child: CircularProgressIndicator(color: ColoresApp.azul));
        }
        return widget.builder(instantanea.data as T, _recargar);
      },
    );
  }
}

/// Tarjeta blanca con titulo para agrupar datos.
class SeccionExpediente extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Widget child;
  final Widget? accion;

  const SeccionExpediente({super.key, required this.titulo, required this.icono, required this.child, this.accion});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ColoresApp.superficie,
        borderRadius: BorderRadius.circular(RadiosApp.tarjeta),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icono, size: 15, color: ColoresApp.rojo),
              const SizedBox(width: 10),
              Expanded(
                child: Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ColoresApp.azul)),
              ),
              ?accion,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Pares etiqueta-valor en columnas que se acomodan al ancho.
class DatosEnGrilla extends StatelessWidget {
  final List<(String, String?)> datos;

  const DatosEnGrilla(this.datos, {super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        final columnas = restricciones.maxWidth > 700 ? 3 : restricciones.maxWidth > 420 ? 2 : 1;
        final ancho = (restricciones.maxWidth - (columnas - 1) * 16) / columnas;
        return Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            for (final (etiqueta, valor) in datos)
              SizedBox(
                width: ancho,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(etiqueta, style: const TextStyle(fontSize: 12, color: ColoresApp.textoSuave, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      valor == null || valor.isEmpty ? 'Sin dato' : valor,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: valor == null || valor.isEmpty ? ColoresApp.textoSuave : ColoresApp.texto,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Mensaje centrado para listas vacias.
class Vacio extends StatelessWidget {
  final String texto;

  const Vacio(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(child: Text(texto, style: const TextStyle(color: ColoresApp.textoSuave))),
    );
  }
}

String monedaBs(double? monto) {
  if (monto == null) return 'Sin dato';
  final entero = monto == monto.truncateToDouble();
  return '${entero ? monto.toStringAsFixed(0) : monto.toStringAsFixed(2).replaceAll('.', ',')} Bs';
}

// ---------------------------------------------------------------------------- viajes

/// Historial de viajes con su ruta en el mapa.
class ListaViajes extends StatelessWidget {
  final List<ViajeExpediente> viajes;

  /// En el expediente del conductor se muestra el pasajero y viceversa.
  final bool mostrarPasajero;

  const ListaViajes({super.key, required this.viajes, required this.mostrarPasajero});

  @override
  Widget build(BuildContext context) {
    if (viajes.isEmpty) return const Vacio('Todavía no tiene viajes.');
    final completados = viajes.where((v) => v.situacion == 'COMPLETADO').toList();
    final total = completados.fold<double>(0, (s, v) => s + (v.precioFinal ?? 0));
    final ordenados = [...viajes]..sort((a, b) => (b.fecha ?? DateTime(1900)).compareTo(a.fecha ?? DateTime(1900)));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '${viajes.length} viajes, ${completados.length} completados, ${monedaBs(total)} en viajes completados',
          style: const TextStyle(color: ColoresApp.textoSuave),
        ),
        const SizedBox(height: 12),
        for (final viaje in ordenados)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ColoresApp.superficie,
              borderRadius: BorderRadius.circular(RadiosApp.control),
              border: Border.all(color: ColoresApp.borde),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Viaje #${viaje.id}',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azul),
                          ),
                          const SizedBox(width: 10),
                          InsigniaEstado(viaje.situacion),
                          const Spacer(),
                          Text(Formato.fechaHora(viaje.fecha), style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _Lugar(color: ColoresApp.azul, etiqueta: 'Desde', texto: viaje.origenDireccion),
                      _Lugar(color: ColoresApp.rojo, etiqueta: 'Hasta', texto: viaje.destinoDireccion),
                      const SizedBox(height: 6),
                      Text(
                        [
                          mostrarPasajero ? 'Pasajero: ${viaje.nombrePasajero}' : 'Conductor: ${viaje.nombreConductor}',
                          if (!mostrarPasajero && viaje.placa != null) 'Placa ${viaje.placa}',
                          'Precio ${monedaBs(viaje.precioFinal)}',
                          if (viaje.canceladoPor != null) 'Cancelado por ${Formato.enumTexto(viaje.canceladoPor).toLowerCase()}',
                        ].join('   |   '),
                        style: const TextStyle(fontSize: 13, color: ColoresApp.texto),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: viaje.origen == null || viaje.destino == null ? null : () => mostrarRutaViaje(context, viaje),
                  icon: const Icon(Iconos.route, size: 14),
                  label: const Text('Ver ruta'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Lugar extends StatelessWidget {
  final Color color;
  final String etiqueta;
  final String texto;

  const _Lugar({required this.color, required this.etiqueta, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          SizedBox(width: 44, child: Text(etiqueta, style: const TextStyle(fontSize: 12.5, color: ColoresApp.textoSuave))),
          Expanded(child: Text(texto, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }
}

/// Mapa del viaje: punto de partida (azul), destino (rojo) y la ruta por calles (OSRM); si el
/// servicio de rutas no responde se dibuja la linea recta punteada.
Future<void> mostrarRutaViaje(BuildContext context, ViajeExpediente viaje) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiosApp.tarjeta)),
      child: SizedBox(width: 820, height: MediaQuery.sizeOf(context).height * 0.8, child: _MapaViaje(viaje: viaje)),
    ),
  );
}

class _MapaViaje extends StatefulWidget {
  final ViajeExpediente viaje;

  const _MapaViaje({required this.viaje});

  @override
  State<_MapaViaje> createState() => _MapaViajeState();
}

class _MapaViajeState extends State<_MapaViaje> {
  final _mapa = MapController();
  List<LatLng>? _ruta;
  bool _aproximada = false;

  @override
  void initState() {
    super.initState();
    _trazar();
  }

  Future<void> _trazar() async {
    final a = widget.viaje.origen!;
    final b = widget.viaje.destino!;
    try {
      final respuesta = await http
          .get(Uri.parse('https://router.project-osrm.org/route/v1/driving/'
              '${a.longitude},${a.latitude};${b.longitude},${b.latitude}?overview=full&geometries=geojson'))
          .timeout(const Duration(seconds: 10));
      final json = jsonDecode(respuesta.body) as Map<String, dynamic>;
      final coordenadas = ((json['routes'] as List).first['geometry']['coordinates'] as List);
      if (mounted) {
        setState(() => _ruta = [for (final c in coordenadas) LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())]);
        // Con la ruta cargada se encuadra el recorrido completo, no solo A y B.
        _mapa.fitCamera(CameraFit.coordinates(coordinates: [..._ruta!, a, b], padding: const EdgeInsets.all(50)));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ruta = [a, b];
          _aproximada = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.viaje;
    final a = v.origen!;
    final b = v.destino!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ColoresApp.rojo, width: 3))),
          child: Row(
            children: [
              const Icon(Iconos.route, color: ColoresApp.azul, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ruta del viaje #${v.id}${_aproximada ? ' (aproximada)' : ''}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: ColoresApp.azul),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Iconos.xmark, size: 18),
              ),
            ],
          ),
        ),
        Expanded(
          child: FlutterMap(
            mapController: _mapa,
            options: MapOptions(
              initialCameraFit: CameraFit.coordinates(coordinates: [a, b], padding: const EdgeInsets.all(60)),
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'taxiuap.admin'),
              if (_ruta != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _ruta!,
                      strokeWidth: 5,
                      color: const Color(0xFF1A73E8),
                      pattern: _aproximada ? StrokePattern.dashed(segments: const [12, 8]) : const StrokePattern.solid(),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(point: a, width: 30, height: 30, child: const _Punto(letra: 'A', color: ColoresApp.azul)),
                  Marker(point: b, width: 30, height: 30, child: const _Punto(letra: 'B', color: ColoresApp.rojo)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _Lugar(color: ColoresApp.azul, etiqueta: 'Desde', texto: v.origenDireccion),
              _Lugar(color: ColoresApp.rojo, etiqueta: 'Hasta', texto: v.destinoDireccion),
            ],
          ),
        ),
      ],
    );
  }
}

class _Punto extends StatelessWidget {
  final String letra;
  final Color color;

  const _Punto({required this.letra, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
      child: Text(letra, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }
}

// ---------------------------------------------------------------------------- calificaciones

/// Estrellas de una calificacion (solo lectura).
class Estrellas extends StatelessWidget {
  final double valor;
  final double tamano;

  const Estrellas(this.valor, {super.key, this.tamano = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Icon(
              valor >= i ? Iconos.solidStar : valor >= i - 0.5 ? Iconos.starHalfStroke : Iconos.star,
              color: const Color(0xFFF5A623),
              size: tamano,
            ),
          ),
      ],
    );
  }
}

/// Calificaciones con las acciones del administrador: quitar solo el comentario o eliminar la
/// calificacion completa (el promedio del conductor se recalcula).
class ListaCalificaciones extends StatelessWidget {
  final ExpedienteApi api;
  final List<CalificacionExpediente> calificaciones;
  final VoidCallback recargar;

  /// true: se muestra quien califico (expediente del conductor); false: a quien (del pasajero).
  final bool mostrarEmisor;

  const ListaCalificaciones({
    super.key,
    required this.api,
    required this.calificaciones,
    required this.recargar,
    required this.mostrarEmisor,
  });

  Future<void> _quitarComentario(BuildContext context, CalificacionExpediente c) async {
    final confirmado = await confirmarAccion(
      context,
      mensaje: 'Va a quitar el comentario de ${c.nombreEmisor}. Las estrellas seguirán contando en el promedio.',
      textoConfirmar: 'Sí, quitar',
    );
    if (!confirmado || !context.mounted) return;
    try {
      await api.quitarComentario(c.id);
      recargar();
      if (context.mounted) await mostrarEliminado(context, titulo: 'Comentario eliminado', mensaje: 'El comentario ya no se muestra.');
    } on ApiExcepcion catch (e) {
      if (context.mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    }
  }

  Future<void> _eliminar(BuildContext context, CalificacionExpediente c) async {
    final confirmado = await confirmarAccion(
      context,
      mensaje: 'Va a eliminar la calificación de ${c.puntuacion} estrellas de ${c.nombreEmisor}. '
          'El promedio del conductor se recalculará.',
      textoConfirmar: 'Sí, eliminar',
    );
    if (!confirmado || !context.mounted) return;
    try {
      await api.eliminarCalificacion(c.id);
      recargar();
      if (context.mounted) await mostrarEliminado(context, titulo: 'Calificación eliminada', mensaje: 'La calificación ya no cuenta.');
    } on ApiExcepcion catch (e) {
      if (context.mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (calificaciones.isEmpty) return const Vacio('No hay calificaciones.');
    return Column(
      children: [
        for (final c in calificaciones)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ColoresApp.superficie,
              borderRadius: BorderRadius.circular(RadiosApp.control),
              border: Border.all(color: ColoresApp.borde),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            mostrarEmisor ? c.nombreEmisor : 'A ${c.nombreReceptor}',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azul),
                          ),
                          const SizedBox(width: 10),
                          Estrellas(c.puntuacion.toDouble()),
                          const Spacer(),
                          Text(
                            '${Formato.fechaHora(c.fecha)}${c.idViaje == null ? '' : '   |   viaje #${c.idViaje}'}',
                            style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.comentario ?? 'Sin comentario',
                        style: TextStyle(
                          color: c.comentario == null ? ColoresApp.textoSuave : ColoresApp.texto,
                          fontStyle: c.comentario == null ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                      if (c.etiquetas.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final e in c.etiquetas)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: ColoresApp.azulNeblina,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(e, style: const TextStyle(fontSize: 12, color: ColoresApp.azul)),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (c.comentario != null)
                  IconButton(
                    tooltip: 'Quitar solo el comentario',
                    onPressed: () => _quitarComentario(context, c),
                    icon: const Icon(Iconos.commentSlash, size: 16, color: Color(0xFFFD7E14)),
                  ),
                IconButton(
                  tooltip: 'Eliminar calificación',
                  onPressed: () => _eliminar(context, c),
                  icon: const Icon(Iconos.trashCan, size: 16, color: ColoresApp.rojo),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
