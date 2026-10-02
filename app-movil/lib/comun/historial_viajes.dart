import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/api_excepcion.dart';
import '../core/formato.dart';
import '../core/tema.dart';
import '../mapa/controlador_mapa.dart';
import '../mapa/vista_mapa.dart';
import '../widgets/pagina_seccion.dart';
import '../widgets/paneles.dart';
import '../widgets/selector_pestanas.dart';
import 'modelos_viaje.dart';

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

/// Seccion Historial de la barra inferior: solo los viajes completados del conductor (los que
/// acepto) o del pasajero (los que pidio), del mas reciente al mas antiguo. Al entrar se ven los
/// ultimos 10; arriba se puede elegir el mes actual o el anterior, paginados de a 10. Tocar un viaje
/// abre su ruta en el mapa.
///
/// Del pasajero tiene ademas una segunda pestana, Favoritos, con sus lugares guardados y los que se
/// deducen de sus viajes ([cargarTodos], una sola consulta al abrir esa pestana). Sin
/// [pestanaFavoritos] la seccion se queda en una sola lista, que es como la ve el conductor.
class PantallaHistorial extends StatefulWidget {
  final Future<PaginaHistorial> Function(PeriodoHistorial periodo, int pagina) cargarHistorial;
  final Future<List<Viaje>> Function()? cargarTodos;
  final bool esConductor;
  final Widget Function(List<Viaje> viajes, EdgeInsets relleno)? pestanaFavoritos;

  const PantallaHistorial({
    super.key,
    required this.cargarHistorial,
    required this.esConductor,
    this.cargarTodos,
    this.pestanaFavoritos,
  });

  @override
  State<PantallaHistorial> createState() => PantallaHistorialState();
}

class PantallaHistorialState extends State<PantallaHistorial> {
  PeriodoHistorial _periodo = PeriodoHistorial.recientes;
  int _numeroPagina = 0;
  PaginaHistorial? _pagina;
  bool _cargando = false;
  String? _error;

  /// Todos los viajes, solo para los lugares frecuentes de la pestana Favoritos.
  List<Viaje>? _todos;

  /// 0 = Historial, 1 = Favoritos. Se muestra el historial al entrar a la seccion.
  int _pestana = 0;

  /// Descarta respuestas viejas si se cambia de periodo o pagina antes de que lleguen.
  int _consulta = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Vuelve a consultar y regresa a los ultimos 10 viajes, que es lo que se ve al entrar.
  Future<void> recargar() {
    setState(() {
      _pestana = 0;
      _periodo = PeriodoHistorial.recientes;
      _numeroPagina = 0;
      _todos = null;
    });
    return _cargar();
  }

  void _elegirPeriodo(PeriodoHistorial periodo) {
    if (periodo == _periodo && _pagina != null) return;
    setState(() {
      _periodo = periodo;
      _numeroPagina = 0;
    });
    _cargar();
  }

  void _irAPagina(int numero) {
    setState(() => _numeroPagina = numero);
    _cargar();
  }

  Future<void> _cargar() async {
    final consulta = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final pagina = await widget.cargarHistorial(_periodo, _numeroPagina);
      if (mounted && consulta == _consulta) setState(() => _pagina = pagina);
    } on ApiExcepcion catch (e) {
      if (mounted && consulta == _consulta) setState(() => _error = e.mensaje);
    } finally {
      if (mounted && consulta == _consulta) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarTodos() async {
    final cargar = widget.cargarTodos;
    if (cargar == null || _todos != null) return;
    try {
      final lista = await cargar();
      if (mounted) setState(() => _todos = lista);
    } catch (_) {
      // Sin viajes los lugares frecuentes quedan vacios; los favoritos se ven igual.
    }
  }

  @override
  Widget build(BuildContext context) {
    final conPestanas = widget.pestanaFavoritos != null;
    return PaginaSeccion(
      titulo: 'Actividad',
      subtitulo: conPestanas
          ? 'Tus viajes y tus lugares'
          : widget.esConductor
          ? 'Los viajes que completaste'
          : 'Los viajes que realizaste',
      constructor: (context, relleno) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (conPestanas) ...[
            SelectorPestanas(
              titulos: const ['Viajes', 'Favoritos'],
              indice: _pestana,
              onCambiar: (i) {
                setState(() => _pestana = i);
                if (i == 1) _cargarTodos();
              },
            ),
            const SizedBox(height: 6),
          ],
          Expanded(
            child: _pestana == 0 || !conPestanas
                ? _listaHistorial(relleno)
                : widget.pestanaFavoritos!(_todos ?? const [], relleno),
          ),
        ],
      ),
    );
  }

  /// "Septiembre 2026" del mes que se esta viendo.
  String _nombreMes(PeriodoHistorial periodo) {
    const meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    final hoy = DateTime.now();
    final mes = periodo == PeriodoHistorial.mesAnterior ? DateTime(hoy.year, hoy.month - 1) : hoy;
    return '${meses[mes.month - 1]} ${mes.year}';
  }

  Widget _listaHistorial(EdgeInsets relleno) {
    final pagina = _pagina;
    final recientes = _periodo == PeriodoHistorial.recientes;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: relleno,
        children: [
          _SelectorPeriodo(periodo: _periodo, onElegir: _elegirPeriodo),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Resumen(
                  titulo: recientes
                      ? 'Viajes completados'
                      : 'Viajes en ${_nombreMes(_periodo).split(' ').first.toLowerCase()}',
                  valor: pagina == null ? '-' : '${pagina.totalViajes}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Resumen(
                  titulo: widget.esConductor ? 'Cobrado' : 'Pagado',
                  valor: pagina == null ? '-' : formatoBs(pagina.totalMonto),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            recientes ? 'Tus últimos viajes completados' : _nombreMes(_periodo),
            style: const TextStyle(color: ColoresApp.azul, fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (_error != null)
            _ErrorCarga(mensaje: _error!, onReintentar: _cargar)
          else if (pagina == null || (_cargando && pagina.viajes.isEmpty))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: ColoresApp.azul)),
            )
          else if (pagina.viajes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Text(
                recientes
                    ? (widget.esConductor ? 'Todavía no completaste viajes.' : 'Todavía no realizaste viajes.')
                    : 'No hay viajes completados en ${_nombreMes(_periodo).toLowerCase()}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: ColoresApp.textoSuave),
              ),
            )
          else ...[
            AnimatedOpacity(
              opacity: _cargando ? 0.45 : 1,
              duration: const Duration(milliseconds: 150),
              child: Column(
                children: [
                  for (final viaje in pagina.viajes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TarjetaViaje(
                        viaje: viaje,
                        esConductor: widget.esConductor,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PantallaDetalleViaje(viaje: viaje, esConductor: widget.esConductor),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!recientes && pagina.totalPaginas > 1)
              _Paginador(
                pagina: pagina.pagina,
                totalPaginas: pagina.totalPaginas,
                cargando: _cargando,
                onIr: _irAPagina,
              ),
            if (recientes && pagina.totalViajes > pagina.viajes.length)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Para ver más viajes elige "Este mes" o "Mes anterior".',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Chips para elegir que parte del historial se ve.
class _SelectorPeriodo extends StatelessWidget {
  final PeriodoHistorial periodo;
  final ValueChanged<PeriodoHistorial> onElegir;

  const _SelectorPeriodo({required this.periodo, required this.onElegir});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final opcion in PeriodoHistorial.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: opcion == PeriodoHistorial.values.last ? 0 : 8),
              child: Material(
                color: opcion == periodo ? ColoresApp.azul : ColoresApp.blanco,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: opcion == periodo ? ColoresApp.azul : ColoresApp.borde),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onElegir(opcion),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Text(
                      opcion.titulo,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: opcion == periodo ? ColoresApp.blanco : ColoresApp.texto,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Anterior / "Pagina 2 de 5" / Siguiente.
class _Paginador extends StatelessWidget {
  final int pagina;
  final int totalPaginas;
  final bool cargando;
  final ValueChanged<int> onIr;

  const _Paginador({required this.pagina, required this.totalPaginas, required this.cargando, required this.onIr});

  @override
  Widget build(BuildContext context) {
    final hayAnterior = pagina > 0 && !cargando;
    final haySiguiente = pagina < totalPaginas - 1 && !cargando;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          IconButton.outlined(
            tooltip: 'Página anterior',
            onPressed: hayAnterior ? () => onIr(pagina - 1) : null,
            icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 14),
          ),
          Expanded(
            child: Text(
              'Página ${pagina + 1} de $totalPaginas',
              textAlign: TextAlign.center,
              style: const TextStyle(color: ColoresApp.texto, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton.outlined(
            tooltip: 'Página siguiente',
            onPressed: haySiguiente ? () => onIr(pagina + 1) : null,
            icon: const FaIcon(FontAwesomeIcons.chevronRight, size: 14),
          ),
        ],
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
          Text(
            valor,
            style: const TextStyle(color: ColoresApp.azul, fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _TarjetaViaje extends StatelessWidget {
  final Viaje viaje;
  final bool esConductor;
  final VoidCallback onTap;

  const _TarjetaViaje({required this.viaje, required this.esConductor, required this.onTap});

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
              FilaLugar.destino(texto: viaje.destinoTexto),
              const SizedBox(height: 4),
              Row(
                children: [
                  FaIcon(
                    esConductor ? FontAwesomeIcons.solidUser : FontAwesomeIcons.motorcycle,
                    color: ColoresApp.textoSuave,
                    size: 12,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      esConductor ? viaje.nombrePasajero : _conductorYPlaca(viaje),
                      style: const TextStyle(color: ColoresApp.texto, fontSize: 13),
                    ),
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

String _conductorYPlaca(Viaje viaje) =>
    [viaje.nombreConductor, if (viaje.placa != null && viaje.placa!.isNotEmpty) viaje.placa!].join(' - ');

/// Detalle de un viaje del historial con su ruta dibujada en el mapa.
class PantallaDetalleViaje extends StatefulWidget {
  final Viaje viaje;
  final bool esConductor;

  const PantallaDetalleViaje({super.key, required this.viaje, required this.esConductor});

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
                        widget.esConductor ? viaje.nombrePasajero : _conductorYPlaca(viaje),
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
                FilaLugar.destino(texto: viaje.destinoTexto),
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
          Expanded(
            child: Text(valor, style: const TextStyle(color: ColoresApp.texto)),
          ),
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
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ColoresApp.rojo),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
