import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/iconos.dart';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/api_excepcion.dart';
import '../../core/formato.dart';
import '../../core/relieve.dart';
import '../../core/tema.dart';
import '../../widgets/boton_relieve.dart';
import '../../widgets/dialogos.dart';
import '../../widgets/insignia_estado.dart';
import '../../widgets/modal_registro.dart';
import '../../widgets/ventana.dart';
import '../entregas/detalle_entrega.dart';
import 'expediente_api.dart';
import 'modelos.dart';
import '../../widgets/dialogo_animado.dart';

/// Abre un expediente (conductor o pasajero) en un modal grande; en pantallas angostas ocupa todo.
/// Con la edicion abierta no se cierra al tocar fuera (se cierra con la X, que avisa si hay cambios).
Future<void> abrirExpediente(BuildContext context, Widget expediente) {
  return mostrarDialogo<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0x661F2733),
    builder: (context) {
      if (Pantalla.esMovil(context)) return Dialog.fullscreen(child: expediente);
      final tamano = MediaQuery.sizeOf(context);
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        backgroundColor: Relieve.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Relieve.linea),
        ),
        child: SizedBox(
          width: tamano.width > 1180 ? 1100 : tamano.width - 48,
          height: tamano.height * 0.9,
          child: expediente,
        ),
      );
    },
  );
}

/// Cabecera con la foto, el nombre, las acciones (arriba, como en el modal de cada registro) y las
/// pestanas del expediente. Con [edicion], el boton Editar pasa a la primera pestana (los datos) y
/// los vuelve editables ahi mismo.
class MarcoExpediente extends StatelessWidget {
  final Widget foto;
  final String titulo;
  final String subtitulo;
  final String? situacion;
  final List<(IconData, String)> pestanas;
  final List<Widget> vistas;
  final ControlEdicion? edicion;
  final List<AccionRegistro> acciones;
  final CierreModal? cierre;

  const MarcoExpediente({
    super.key,
    required this.foto,
    required this.titulo,
    required this.subtitulo,
    this.situacion,
    required this.pestanas,
    required this.vistas,
    this.edicion,
    this.acciones = const [],
    this.cierre,
  });

  Future<void> _cerrar(BuildContext context) async {
    if (await puedeCerrarEdicion(context, edicion) && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    cierre?.recordar(context);
    final movil = Pantalla.esMovil(context);
    final conBotones = edicion != null || acciones.isNotEmpty;
    final marco = DefaultTabController(
      length: pestanas.length,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF203E70), ColoresApp.azul],
                ),
                boxShadow: [BoxShadow(color: Relieve.sombra, offset: Offset(0, 3), blurRadius: 8)],
              ),
              padding: EdgeInsets.fromLTRB(movil ? 14 : 20, 14, 8, 0),
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                      if (situacion != null && !movil) InsigniaEstado(situacion!),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => _cerrar(context),
                        icon: const Icon(Iconos.xmark, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                  if (conBotones) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: BotonesRegistro(
                        edicion: edicion,
                        acciones: acciones,
                        antesDeEditar: () => DefaultTabController.of(context).animateTo(0),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
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
                            children: [
                              Icon(icono, size: 14, color: Colors.white70),
                              const SizedBox(width: 8),
                              Text(texto),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: ColoresApp.fondo,
                // Cada pestana se conserva al cambiar de pestana: no vuelve a cargar y no se pierde lo que
                // se estaba editando en los datos.
                child: TabBarView(children: [for (final vista in vistas) _MantenerVivo(child: vista)]),
              ),
            ),
          ],
        ),
      ),
    );
    final control = edicion;
    if (control == null) return marco;
    return ListenableBuilder(
      listenable: control,
      builder: (context, hijo) => PopScope(
        canPop: !control.hayCambios && !control.guardando,
        onPopInvokedWithResult: (cerrado, _) {
          if (!cerrado) _cerrar(context);
        },
        child: hijo!,
      ),
      child: marco,
    );
  }
}

class _MantenerVivo extends StatefulWidget {
  final Widget child;

  const _MantenerVivo({required this.child});

  @override
  State<_MantenerVivo> createState() => _MantenerVivoState();
}

class _MantenerVivoState extends State<_MantenerVivo> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
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
      decoration: Relieve.tarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icono, size: 15, color: ColoresApp.rojo),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: Relieve.tenue,
                  ),
                ),
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
        final columnas = restricciones.maxWidth > 700
            ? 3
            : restricciones.maxWidth > 420
            ? 2
            : 1;
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
                    Text(
                      etiqueta,
                      style: const TextStyle(fontSize: 12, color: ColoresApp.textoSuave, fontWeight: FontWeight.w600),
                    ),
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
      child: Center(
        child: Text(texto, style: const TextStyle(color: ColoresApp.textoSuave)),
      ),
    );
  }
}

String monedaBs(double? monto) {
  if (monto == null) return 'Sin dato';
  final entero = monto == monto.truncateToDouble();
  return '${entero ? monto.toStringAsFixed(0) : monto.toStringAsFixed(2).replaceAll('.', ',')} Bs';
}

// ---------------------------------------------------------------------------- viajes

/// Historial de viajes con su ruta en el mapa: una tarjeta en relieve por viaje (numero, estado, fecha,
/// partida y destino, datos en pastillas) con "Ver ruta" y "Ver entrega". Bajo 640 px los botones van abajo.
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Resumen(icono: Iconos.route, texto: '${viajes.length} viajes'),
            _Resumen(icono: Iconos.circleCheck, texto: '${completados.length} completados'),
            _Resumen(icono: Iconos.moneda, texto: '${monedaBs(total)} en viajes completados'),
          ],
        ),
        const SizedBox(height: 16),
        for (final viaje in ordenados) _TarjetaViaje(viaje: viaje, mostrarPasajero: mostrarPasajero),
      ],
    );
  }
}

/// Pastilla del resumen de arriba (total de viajes, completados, monto).
class _Resumen extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Resumen({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: Relieve.panelHundido(radio: 999),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 14, color: ColoresApp.azul),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColoresApp.azul),
        ),
      ],
    ),
  );
}

class _TarjetaViaje extends StatelessWidget {
  final ViajeExpediente viaje;
  final bool mostrarPasajero;

  const _TarjetaViaje({required this.viaje, required this.mostrarPasajero});

  @override
  Widget build(BuildContext context) {
    final datos = <(String, String)>[
      mostrarPasajero ? ('Pasajero', viaje.nombrePasajero) : ('Conductor', viaje.nombreConductor),
      if (!mostrarPasajero && viaje.placa != null) ('Placa', viaje.placa!),
      ('Precio', monedaBs(viaje.precioFinal)),
      if (viaje.nombreTercero != null)
        ('Para', '${viaje.nombreTercero}${viaje.telefonoTercero == null ? '' : ' (${viaje.telefonoTercero})'}'),
      if (viaje.nombreTercero != null) ('Pagó', viaje.pagaSolicitante ? 'Quien lo pidió' : 'Quien viajó'),
      if (viaje.canceladoPor != null) ('Cancelado por', Formato.enumTexto(viaje.canceladoPor)),
    ];
    final botones = [
      BotonRelieve(
        texto: 'Ver ruta',
        icono: Iconos.route,
        tono: TonoBoton.azul,
        tamano: TamanoBoton.pequeno,
        ayuda: viaje.origen == null || viaje.destino == null ? 'El viaje no tiene los puntos guardados' : null,
        alPresionar: viaje.origen == null || viaje.destino == null ? null : () => mostrarRutaViaje(context, viaje),
      ),
      if (viaje.entrega != null)
        BotonRelieve(
          texto: 'Ver entrega',
          icono: Iconos.paquete,
          tono: TonoBoton.turquesa,
          tamano: TamanoBoton.pequeno,
          alPresionar: () => mostrarEntrega(context, viaje),
        ),
    ];
    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Viaje #${viaje.id}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ColoresApp.azul),
            ),
            InsigniaEstado(viaje.situacion),
            if (viaje.entrega != null) const InsigniaEstado('ENTREGA', texto: 'Entrega'),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Iconos.clock, size: 13, color: Relieve.tenue),
                const SizedBox(width: 4),
                Text(Formato.fechaHora(viaje.fecha), style: const TextStyle(color: Relieve.tenue, fontSize: 13)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: Relieve.panelHundido(radio: 12),
          child: Column(
            children: [
              _Lugar(color: ColoresApp.azul, etiqueta: 'Desde', texto: viaje.origenDireccion),
              _Lugar(color: ColoresApp.rojo, etiqueta: 'Hasta', texto: viaje.destinoDireccion),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [for (final (etiqueta, valor) in datos) _Dato(etiqueta: etiqueta, valor: valor)],
        ),
      ],
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: Relieve.tarjeta(),
      child: LayoutBuilder(
        builder: (context, restricciones) {
          if (restricciones.maxWidth < 640) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                contenido,
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: botones),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: contenido),
              const SizedBox(width: 16),
              SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, boton) in botones.indexed) ...[if (i > 0) const SizedBox(height: 8), boton],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Dato del viaje como pastilla: etiqueta en gris y valor en negrita.
class _Dato extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _Dato({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Relieve.lineaSuave),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$etiqueta: ',
            style: const TextStyle(color: Relieve.tenue),
          ),
          TextSpan(
            text: valor,
            style: const TextStyle(fontWeight: FontWeight.w600, color: ColoresApp.texto),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 13),
    ),
  );
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
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(etiqueta, style: const TextStyle(fontSize: 12.5, color: ColoresApp.textoSuave)),
          ),
          Expanded(
            child: Text(texto, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}

/// Mapa del viaje: punto de partida (azul), destino (rojo) y la ruta por calles (OSRM); si el
/// servicio de rutas no responde se dibuja la linea recta punteada.
Future<void> mostrarRutaViaje(BuildContext context, ViajeExpediente viaje) {
  return mostrarDialogo<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiosApp.tarjeta)),
      child: SizedBox(
        width: 820,
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: _MapaViaje(viaje: viaje),
      ),
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
          .get(
            Uri.parse(
              'https://router.project-osrm.org/route/v1/driving/'
              '${a.longitude},${a.latitude};${b.longitude},${b.latitude}?overview=full&geometries=geojson',
            ),
          )
          .timeout(const Duration(seconds: 10));
      final json = jsonDecode(respuesta.body) as Map<String, dynamic>;
      final coordenadas = ((json['routes'] as List).first['geometry']['coordinates'] as List);
      if (mounted) {
        setState(
          () => _ruta = [for (final c in coordenadas) LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())],
        );
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
        CabeceraVentana(
          icono: Iconos.route,
          titulo: 'Ruta del viaje #${v.id}${_aproximada ? ' (aproximada)' : ''}',
          alCerrar: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: FlutterMap(
            mapController: _mapa,
            options: MapOptions(
              initialCameraFit: CameraFit.coordinates(coordinates: [a, b], padding: const EdgeInsets.all(60)),
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'taxiuap.admin',
              ),
              if (_ruta != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _ruta!,
                      strokeWidth: 5,
                      color: const Color(0xFF1A73E8),
                      pattern: _aproximada
                          ? StrokePattern.dashed(segments: const [12, 8])
                          : const StrokePattern.solid(),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: a,
                    width: 30,
                    height: 30,
                    child: const _Punto(letra: 'A', color: ColoresApp.azul),
                  ),
                  Marker(
                    point: b,
                    width: 30,
                    height: 30,
                    child: const _Punto(letra: 'B', color: ColoresApp.rojo),
                  ),
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
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Text(
        letra,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
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
              valor >= i
                  ? Iconos.solidStar
                  : valor >= i - 0.5
                  ? Iconos.starHalfStroke
                  : Iconos.star,
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
      if (context.mounted) {
        await mostrarEliminado(context, titulo: 'Comentario eliminado', mensaje: 'El comentario ya no se muestra.');
      }
    } on ApiExcepcion catch (e) {
      if (context.mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    }
  }

  Future<void> _eliminar(BuildContext context, CalificacionExpediente c) async {
    final confirmado = await confirmarAccion(
      context,
      mensaje:
          'Va a eliminar la calificación de ${c.puntuacion} estrellas de ${c.nombreEmisor}. '
          'El promedio del conductor se recalculará.',
      textoConfirmar: 'Sí, eliminar',
    );
    if (!confirmado || !context.mounted) return;
    try {
      await api.eliminarCalificacion(c.id);
      recargar();
      if (context.mounted) {
        await mostrarEliminado(context, titulo: 'Calificación eliminada', mensaje: 'La calificación ya no cuenta.');
      }
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
