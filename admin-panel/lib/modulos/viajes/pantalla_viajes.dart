import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/formato.dart';
import '../../core/iconos.dart';
import '../../core/tema.dart';
import '../../widgets/listado_remoto.dart';
import '../../widgets/tabla/columna_tabla.dart';
import '../entregas/detalle_entrega.dart';
import '../expediente/modelos.dart';
import '../expediente/vista_expediente.dart';
import 'modelos.dart';
import 'viajes_api.dart';

const _situaciones = [
  'CONFIRMADO',
  'CONDUCTOR_EN_CAMINO',
  'CONDUCTOR_LLEGO',
  'EN_CURSO',
  'COMPLETADO',
  'CANCELADO',
];

/// Todos los viajes de taxi y pedidos de delivery, con filtros que se aplican en el servidor: servicio,
/// tipo de usuario (pasajero: lo que pidio; conductor de taxi: los viajes que hizo; repartidor: los
/// pedidos que entrego), la persona y las fechas (ver todo o de una fecha a otra). El administrador ve
/// siempre todo el detalle y la evidencia de las entregas, sin limite de tiempo.
class PantallaViajes extends StatefulWidget {
  const PantallaViajes({super.key});

  @override
  State<PantallaViajes> createState() => _PantallaViajesState();
}

class _PantallaViajesState extends State<PantallaViajes> {
  late final ViajesApi _api = ViajesApi(context.read<ClienteApi>());

  ServicioViajes _servicio = ServicioViajes.todos;
  TipoUsuarioViajes _tipo = TipoUsuarioViajes.todos;
  PersonaViajes? _persona;
  bool _porFechas = false;
  DateTime? _desde;
  DateTime? _hasta;

  /// Personas con viajes del tipo elegido (para el buscador).
  List<PersonaViajes> _personas = const [];
  bool _cargandoPersonas = false;

  /// Cambia cuando se limpian los filtros, para vaciar el buscador de personas.
  int _version = 0;

  bool get _servicioFijo => _tipo == TipoUsuarioViajes.conductor || _tipo == TipoUsuarioViajes.repartidor;

  bool get _fechasInvertidas => _porFechas && _desde != null && _hasta != null && _desde!.isAfter(_hasta!);

  Future<void> _cambiarTipo(TipoUsuarioViajes tipo) async {
    setState(() {
      _tipo = tipo;
      _persona = null;
      _personas = const [];
      if (tipo == TipoUsuarioViajes.conductor) _servicio = ServicioViajes.taxi;
      if (tipo == TipoUsuarioViajes.repartidor) _servicio = ServicioViajes.delivery;
      if (!_servicioFijo && _servicio != ServicioViajes.todos && tipo == TipoUsuarioViajes.todos) {
        _servicio = ServicioViajes.todos;
      }
    });
    if (tipo == TipoUsuarioViajes.todos) return;
    setState(() => _cargandoPersonas = true);
    try {
      final personas = await _api.personas(tipo);
      if (mounted && _tipo == tipo) setState(() => _personas = personas);
    } on ApiExcepcion {
      // Sin la lista se puede filtrar igual por tipo.
    } finally {
      if (mounted) setState(() => _cargandoPersonas = false);
    }
  }

  void _limpiar() => setState(() {
    _servicio = ServicioViajes.todos;
    _tipo = TipoUsuarioViajes.todos;
    _persona = null;
    _personas = const [];
    _porFechas = false;
    _desde = null;
    _hasta = null;
    _version++;
  });

  Future<void> _elegirFecha({required bool desde}) async {
    final hoy = DateTime.now();
    final actual = desde ? _desde : _hasta;
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual ?? DateTime(hoy.year, hoy.month, hoy.day),
      firstDate: DateTime(2025),
      lastDate: DateTime(hoy.year + 1, 12, 31),
      helpText: desde ? 'Desde' : 'Hasta',
    );
    if (elegida != null) setState(() => desde ? _desde = elegida : _hasta = elegida);
  }

  @override
  Widget build(BuildContext context) {
    final clave = '${_servicio.codigo}|${_tipo.codigo}|${_persona?.idPersona}|$_porFechas|$_desde|$_hasta';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _filtros(),
        const SizedBox(height: 12),
        Expanded(
          child: _fechasInvertidas
              ? const Center(
                  child: Text(
                    'La fecha "Desde" debe ser anterior o igual a "Hasta".',
                    style: TextStyle(color: ColoresApp.rojo),
                  ),
                )
              : ListadoRemoto<ViajeExpediente>(
                  key: ValueKey(clave),
                  titulo: 'Viajes',
                  icono: Iconos.route,
                  nombreArchivo: 'viajes',
                  cargar: () => _api.listar(
                    servicio: _servicio,
                    tipo: _tipo,
                    persona: _persona,
                    desde: _porFechas ? _desde : null,
                    hasta: _porFechas ? _hasta : null,
                  ),
                  columnas: [
                    ColumnaTabla(titulo: 'Viaje', tipo: TipoColumna.numero, valor: (v) => v.id),
                    ColumnaTabla(titulo: 'Pedido', tipo: TipoColumna.fechaHora, valor: (v) => v.fechaSolicitud ?? v.fecha),
                    ColumnaTabla(
                      titulo: 'Servicio',
                      tipo: TipoColumna.estado,
                      opciones: const ['TAXI', 'DELIVERY'],
                      valor: (v) => v.entrega == null ? 'TAXI' : 'DELIVERY',
                    ),
                    ColumnaTabla(
                      titulo: 'Pasajero / cliente',
                      proporcion: 1.6,
                      valor: (v) => v.nombreTercero == null ? v.nombrePasajero : '${v.nombrePasajero} (para ${v.nombreTercero})',
                    ),
                    ColumnaTabla(titulo: 'Conductor / repartidor', proporcion: 1.6, valor: (v) => v.nombreConductor),
                    ColumnaTabla(
                      titulo: 'Situación',
                      tipo: TipoColumna.estado,
                      opciones: _situaciones,
                      valor: (v) => v.situacion,
                    ),
                    ColumnaTabla(titulo: 'Precio (Bs)', tipo: TipoColumna.numero, valor: (v) => v.precioFinal),
                    ColumnaTabla(titulo: 'Km', tipo: TipoColumna.numero, valor: (v) => v.distanciaKm),
                    ColumnaTabla(titulo: 'Inicio', tipo: TipoColumna.fechaHora, valor: (v) => v.fechaInicio),
                    ColumnaTabla(titulo: 'Fin', tipo: TipoColumna.fechaHora, valor: (v) => v.fechaFin),
                    ColumnaTabla(titulo: 'Origen', proporcion: 1.4, valor: (v) => v.origenDireccion),
                    ColumnaTabla(titulo: 'Destino', proporcion: 1.4, valor: (v) => v.destinoDireccion),
                  ],
                  accionesFila: (viaje, _) => [
                    if (viaje.entrega != null)
                      IconButton(
                        tooltip: 'Ver entrega (confirmaciones y fotos)',
                        onPressed: () => mostrarEntrega(context, viaje),
                        icon: const Icon(Iconos.paquete, size: 16, color: ColoresApp.azul),
                      ),
                    IconButton(
                      tooltip: 'Ver ruta',
                      onPressed: viaje.origen == null || viaje.destino == null ? null : () => mostrarRutaViaje(context, viaje),
                      icon: const Icon(Iconos.route, size: 16, color: ColoresApp.azul),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _filtros() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresApp.superficie,
        borderRadius: BorderRadius.circular(RadiosApp.control),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: LayoutBuilder(
        builder: (context, restricciones) {
          // En pantallas angostas cada filtro ocupa todo el ancho.
          final ancho = restricciones.maxWidth < 620 ? restricciones.maxWidth : 260.0;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: ancho,
                child: DropdownButtonFormField<TipoUsuarioViajes>(
                  key: ValueKey('tipo$_version'),
                  initialValue: _tipo,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tipo de usuario', isDense: true),
                  items: [
                    for (final t in TipoUsuarioViajes.values)
                      DropdownMenuItem(value: t, child: Text(t.texto, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (t) => t == null ? null : _cambiarTipo(t),
                ),
              ),
              SizedBox(
                width: ancho,
                child: DropdownButtonFormField<ServicioViajes>(
                  // Conductor de taxi y repartidor fijan el servicio.
                  key: ValueKey('servicio$_version${_tipo.codigo}'),
                  initialValue: _servicio,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Servicio', isDense: true),
                  items: [
                    for (final s in ServicioViajes.values) DropdownMenuItem(value: s, child: Text(s.texto)),
                  ],
                  onChanged: _servicioFijo ? null : (s) => setState(() => _servicio = s ?? _servicio),
                ),
              ),
              if (_tipo != TipoUsuarioViajes.todos)
                SizedBox(
                  width: restricciones.maxWidth < 620 ? restricciones.maxWidth : 340,
                  child: _BuscadorPersona(
                    key: ValueKey('persona${_tipo.codigo}$_version'),
                    personas: _personas,
                    cargando: _cargandoPersonas,
                    etiqueta: switch (_tipo) {
                      TipoUsuarioViajes.pasajero => 'Pasajero (vacío: todos)',
                      TipoUsuarioViajes.conductor => 'Conductor de taxi (vacío: todos)',
                      _ => 'Repartidor (vacío: todos)',
                    },
                    alElegir: (persona) => setState(() => _persona = persona),
                  ),
                ),
              SizedBox(
                width: restricciones.maxWidth < 620 ? restricciones.maxWidth : null,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Ver todo')),
                    ButtonSegment(value: true, label: Text('De fecha a fecha'), icon: Icon(Iconos.calendar, size: 14)),
                  ],
                  selected: {_porFechas},
                  showSelectedIcon: false,
                  onSelectionChanged: (valor) => setState(() => _porFechas = valor.first),
                ),
              ),
              if (_porFechas) ...[
                _botonFecha('Desde', _desde, () => _elegirFecha(desde: true), () => setState(() => _desde = null)),
                _botonFecha('Hasta', _hasta, () => _elegirFecha(desde: false), () => setState(() => _hasta = null)),
              ],
              TextButton.icon(
                onPressed: _limpiar,
                icon: const Icon(Iconos.filterCircleXmark, size: 14),
                label: const Text('Limpiar filtros'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _botonFecha(String etiqueta, DateTime? valor, VoidCallback elegir, VoidCallback quitar) => SizedBox(
    width: 170,
    child: InkWell(
      onTap: elegir,
      child: InputDecorator(
        isEmpty: valor == null,
        decoration: InputDecoration(
          labelText: etiqueta,
          isDense: true,
          suffixIcon: valor == null
              ? const Icon(Iconos.calendar, size: 14)
              : IconButton(tooltip: 'Quitar fecha', onPressed: quitar, icon: const Icon(Iconos.xmark, size: 14)),
        ),
        child: Text(valor == null ? '' : Formato.fecha(valor)),
      ),
    ),
  );
}

/// Buscador de la persona por nombre o CI dentro de las que tienen viajes del tipo elegido. Vacio = todas.
class _BuscadorPersona extends StatelessWidget {
  final List<PersonaViajes> personas;
  final bool cargando;
  final String etiqueta;
  final ValueChanged<PersonaViajes?> alElegir;

  const _BuscadorPersona({
    super.key,
    required this.personas,
    required this.cargando,
    required this.etiqueta,
    required this.alElegir,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) => Autocomplete<PersonaViajes>(
        displayStringForOption: (p) => p.etiqueta,
        optionsBuilder: (texto) {
          final termino = texto.text.trim().toLowerCase();
          if (termino.isEmpty) return personas.take(30);
          return personas.where((p) => p.etiqueta.toLowerCase().contains(termino)).take(30);
        },
        onSelected: alElegir,
        optionsViewBuilder: (context, alSeleccionar, opciones) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            color: Colors.white,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 260, maxWidth: restricciones.maxWidth),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final p in opciones)
                    ListTile(
                      dense: true,
                      title: Text('${p.nombres} ${p.apellidos}'.trim()),
                      subtitle: Text('${(p.ci ?? '').isEmpty ? '' : 'CI ${p.ci} - '}${p.viajes} viajes'),
                      onTap: () => alSeleccionar(p),
                    ),
                ],
              ),
            ),
          ),
        ),
        fieldViewBuilder: (context, control, foco, alEnviar) => TextField(
          controller: control,
          focusNode: foco,
          decoration: InputDecoration(
            labelText: etiqueta,
            hintText: cargando ? 'Cargando...' : 'Buscar por nombre o CI',
            isDense: true,
            prefixIcon: const Padding(padding: EdgeInsets.all(10), child: Icon(Iconos.magnifyingGlass, size: 14)),
            suffixIcon: IconButton(
              tooltip: 'Quitar',
              onPressed: () {
                control.clear();
                alElegir(null);
              },
              icon: const Icon(Iconos.xmark, size: 14),
            ),
          ),
          // Al editar el texto la persona elegida deja de valer (vacio = todas).
          onChanged: (_) => alElegir(null),
        ),
      ),
    );
  }
}
