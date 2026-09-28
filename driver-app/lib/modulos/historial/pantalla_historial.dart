import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../mapa/controlador_mapa.dart';
import '../../mapa/vista_mapa.dart';
import '../../widgets/paneles.dart';
import '../viaje/conductor_api.dart';
import '../viaje/modelos.dart';

/// Barra superior azul de las pantallas secundarias.
PreferredSizeWidget barraSecundaria(String titulo) => AppBar(
  backgroundColor: ColoresApp.azul,
  foregroundColor: ColoresApp.blanco,
  title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
);

Color colorSituacion(String situacion) => switch (situacion) {
  SituacionViaje.completado => ColoresApp.exito,
  SituacionViaje.cancelado => ColoresApp.rojo,
  _ => ColoresApp.ruta,
};

/// Historial de los viajes que acepto el conductor, del mas reciente al mas antiguo.
class PantallaHistorial extends StatefulWidget {
  const PantallaHistorial({super.key});

  @override
  State<PantallaHistorial> createState() => _PantallaHistorialState();
}

class _PantallaHistorialState extends State<PantallaHistorial> {
  late final ConductorApi _api = ConductorApi(context.read<ClienteApi>());
  List<Viaje>? _viajes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final lista = await _api.misViajes();
      // Primero el viaje activo (si hay); despues los terminados del mas reciente al mas antiguo.
      // Un viaje cancelado antes de iniciar no tiene fechas: va al final.
      lista.sort((a, b) {
        if (a.terminado != b.terminado) return a.terminado ? 1 : -1;
        final fa = a.fechaInicio ?? a.fechaFin;
        final fb = b.fechaInicio ?? b.fechaFin;
        if (fa == null && fb == null) return b.id.compareTo(a.id);
        if (fa == null) return 1;
        if (fb == null) return -1;
        return fb.compareTo(fa);
      });
      if (mounted) setState(() => _viajes = lista);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viajes = _viajes;
    final completados = viajes?.where((v) => v.situacion == SituacionViaje.completado).toList() ?? const [];
    final ganado = completados.fold<double>(0, (suma, v) => suma + (v.precioFinal ?? 0));
    return Scaffold(
      appBar: barraSecundaria('Historial de viajes'),
      body: _error != null
          ? _ErrorCarga(mensaje: _error!, onReintentar: _cargar)
          : viajes == null
          ? const Center(child: CircularProgressIndicator(color: ColoresApp.azul))
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Resumen(titulo: 'Viajes completados', valor: '${completados.length}'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _Resumen(titulo: 'Cobrado', valor: formatoBs(ganado))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (viajes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text(
                        'Todavía no aceptaste viajes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ColoresApp.textoSuave),
                      ),
                    ),
                  for (final viaje in viajes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TarjetaViaje(
                        viaje: viaje,
                        onTap: () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute<void>(builder: (_) => PantallaDetalleViaje(viaje: viaje))),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _Resumen extends StatelessWidget {
  final String titulo;
  final String valor;

  const _Resumen({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5)),
          const SizedBox(height: 4),
          Text(valor, style: const TextStyle(color: ColoresApp.azul, fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _TarjetaViaje extends StatelessWidget {
  final Viaje viaje;
  final VoidCallback onTap;

  const _TarjetaViaje({required this.viaje, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = colorSituacion(viaje.situacion);
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
                  const FaIcon(FontAwesomeIcons.calendar, color: ColoresApp.textoSuave, size: 13),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      viaje.fechaInicio == null ? 'Sin iniciar' : formatoFechaHora(viaje.fechaInicio),
                      style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      SituacionViaje.nombre(viaje.situacion),
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FilaLugar.partida(texto: viaje.origenDireccion),
              FilaLugar.destino(texto: viaje.destinoDireccion),
              const SizedBox(height: 4),
              Row(
                children: [
                  const FaIcon(FontAwesomeIcons.solidUser, color: ColoresApp.textoSuave, size: 12),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(viaje.nombrePasajero, style: const TextStyle(color: ColoresApp.texto, fontSize: 13)),
                  ),
                  Text(
                    formatoBs(viaje.precioFinal),
                    style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detalle de un viaje del historial con su ruta dibujada en el mapa.
class PantallaDetalleViaje extends StatefulWidget {
  final Viaje viaje;

  const PantallaDetalleViaje({super.key, required this.viaje});

  @override
  State<PantallaDetalleViaje> createState() => _PantallaDetalleViajeState();
}

class _PantallaDetalleViajeState extends State<PantallaDetalleViaje> {
  final _mapa = ControladorMapa();

  @override
  void initState() {
    super.initState();
    _mapa.margenesVista = const EdgeInsets.all(40);
    final viaje = widget.viaje;
    if (viaje.tieneRuta) _mapa.ponerRuta(viaje.puntoA, viaje.puntoB);
  }

  @override
  void dispose() {
    _mapa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viaje = widget.viaje;
    final color = colorSituacion(viaje.situacion);
    return Scaffold(
      appBar: barraSecundaria('Viaje #${viaje.id}'),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.42,
            child: MapaBase(controlador: _mapa),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        viaje.nombrePasajero,
                        style: const TextStyle(color: ColoresApp.azul, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      SituacionViaje.nombre(viaje.situacion),
                      style: TextStyle(color: color, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilaLugar.partida(texto: viaje.origenDireccion),
                FilaLugar.destino(texto: viaje.destinoDireccion),
                const SizedBox(height: 10),
                ListenableBuilder(
                  listenable: _mapa,
                  builder: (context, _) => _mapa.ruta == null
                      ? const SizedBox.shrink()
                      : DatoRuta(
                          icono: FontAwesomeIcons.route,
                          texto: 'Recorrido: ${_mapa.ruta!.distanciaTexto}, ${_mapa.ruta!.duracionTexto}',
                        ),
                ),
                const SizedBox(height: 8),
                _Linea(etiqueta: 'Inicio', valor: formatoFechaHora(viaje.fechaInicio)),
                _Linea(etiqueta: 'Fin', valor: formatoFechaHora(viaje.fechaFin)),
                if (viaje.canceladoPor != null)
                  _Linea(etiqueta: 'Cancelado por', valor: viaje.canceladoPor == 'PASAJERO' ? 'Pasajero' : 'Conductor'),
                const SizedBox(height: 12),
                RecuadroPrecio(etiqueta: 'Precio del viaje', monto: formatoBs(viaje.precioFinal)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _Linea({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(etiqueta, style: const TextStyle(color: ColoresApp.textoSuave)),
          ),
          Expanded(child: Text(valor, style: const TextStyle(color: ColoresApp.texto))),
        ],
      ),
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;

  const _ErrorCarga({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(color: ColoresApp.rojo)),
            const SizedBox(height: 12),
            TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
