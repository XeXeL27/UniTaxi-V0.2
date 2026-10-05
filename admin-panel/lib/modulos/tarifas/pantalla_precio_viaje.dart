import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/iconos.dart';
import '../../core/tema.dart';
import '../../widgets/dialogos.dart';
import '../../widgets/flujos_crud.dart';
import 'modelos.dart';
import 'tarifas_api.dart';

/// Tarifas > Precio del viaje: el precio base (hasta ciertos km; se edita pero no se elimina) y una
/// tabla editable de km extra. Cada fila suma sus km y su costo a los anteriores; despues de la ultima
/// se repite la ultima. Eliminar una fila es borrado logico. Vale desde el siguiente viaje que se pida.
class PantallaPrecioViaje extends StatefulWidget {
  const PantallaPrecioViaje({super.key});

  @override
  State<PantallaPrecioViaje> createState() => _PantallaPrecioViajeState();
}

/// Una fila de la tabla: la base (id null, no se elimina), un tramo guardado o uno nuevo sin guardar.
class _Fila {
  final int? id;
  final bool esBase;
  final TextEditingController km;
  final TextEditingController costo;
  double? kmGuardado;
  double? costoGuardado;

  _Fila({this.id, this.esBase = false, double? km, double? costo})
    : km = TextEditingController(text: km == null ? '' : _texto(km)),
      costo = TextEditingController(text: costo == null ? '' : _texto(costo)),
      kmGuardado = km,
      costoGuardado = costo;

  bool get nueva => !esBase && id == null;

  double? get kmEscrito => _decimal(km.text);

  double? get costoEscrito => _decimal(costo.text);

  bool get valida {
    final k = kmEscrito;
    final c = costoEscrito;
    if (k == null || c == null) return false;
    return esBase ? k > 0 && c >= 0.5 : k >= 0.1 && c >= 0;
  }

  bool get cambiada => nueva || kmEscrito != kmGuardado || costoEscrito != costoGuardado;

  void dispose() {
    km.dispose();
    costo.dispose();
  }
}

String _texto(double valor) => valor == valor.roundToDouble() ? valor.toStringAsFixed(0) : valor.toStringAsFixed(2);

double? _decimal(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));

String _bs(double valor) => '${valor.toStringAsFixed(2)} Bs';

class _PantallaPrecioViajeState extends State<PantallaPrecioViaje> {
  late final TarifasApi _api = TarifasApi(context.read<ClienteApi>());
  List<_Fila> _filas = [];
  bool _cargando = true;
  bool _ocupado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final f in _filas) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      _mostrar(await _api.precioViaje());
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  /// Rearma la tabla con lo que respondio el servidor (se pierde una fila nueva sin guardar).
  void _mostrar(ParametrosPrecio p) {
    if (!mounted) return;
    for (final f in _filas) {
      f.dispose();
    }
    setState(() {
      _cargando = false;
      _filas = [
        _Fila(esBase: true, km: p.kmBase, costo: p.precioBase),
        for (final t in p.tramos) _Fila(id: t.id, km: t.kmAdicional, costo: t.costoAdicional),
      ];
    });
  }

  void _agregar() {
    if (_filas.any((f) => f.nueva)) return;
    final ultimo = _filas.length > 1 ? _filas.last : null;
    setState(() => _filas.add(_Fila(km: ultimo?.kmGuardado ?? 3, costo: ultimo?.costoGuardado ?? 2)));
  }

  /// N.° visible de un tramo (la base no cuenta).
  int _numero(_Fila fila) => _filas.indexOf(fila);

  Future<void> _guardar(_Fila fila) async {
    final km = fila.kmEscrito;
    final costo = fila.costoEscrito;
    if (!fila.valida || km == null || costo == null) return;
    if (!fila.nueva) {
      final descripcion = fila.esBase ? 'el precio base' : 'el tramo ${_numero(fila)}';
      final confirmado = await confirmarAccion(
        context,
        mensaje: 'Va a editar $descripcion: ${fila.esBase ? 'hasta' : 'más'} ${_texto(km)} km por '
            '${fila.esBase ? '' : 'más '}${_bs(costo)}. Vale desde el próximo viaje que se pida.',
        textoConfirmar: 'Sí, editar',
      );
      if (!confirmado || !mounted) return;
    }
    setState(() => _ocupado = true);
    try {
      final ParametrosPrecio p;
      if (fila.esBase) {
        p = await _api.guardarBase(costo, km);
      } else if (fila.nueva) {
        p = await _api.crearTramo(km, costo);
      } else {
        p = await _api.editarTramo(fila.id!, km, costo);
      }
      _mostrar(p);
      if (!mounted) return;
      await mostrarExito(
        context,
        titulo: fila.nueva ? '¡Km extra agregados!' : '¡Cambios guardados!',
        mensaje: fila.esBase
            ? 'El precio base es ${_bs(costo)} hasta ${_texto(km)} km.'
            : 'El tramo suma ${_texto(km)} km por ${_bs(costo)} más.',
      );
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, titulo: 'No se pudo guardar', mensaje: e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _cancelar(_Fila fila) {
    setState(() => _filas.remove(fila));
    fila.dispose();
  }

  Future<void> _eliminar(_Fila fila) {
    ParametrosPrecio? respuesta;
    return flujoEliminar(
      context,
      descripcion: 'el tramo ${_numero(fila)} (más ${_texto(fila.kmGuardado!)} km por ${_bs(fila.costoGuardado!)})',
      eliminar: () async => respuesta = await _api.eliminarTramo(fila.id!),
      mensajeEliminado: 'Se eliminó el tramo. Los siguientes se recalcularon.',
      alTerminar: () {
        if (respuesta != null) _mostrar(respuesta!);
      },
    );
  }

  /// Recorrido y precio total de cada fila con lo escrito (antes de guardar).
  List<(double desde, double hasta, double total)?> _acumulados() {
    double hasta = 0;
    double total = 0;
    final resultado = <(double, double, double)?>[];
    for (final f in _filas) {
      final km = f.kmEscrito;
      final costo = f.costoEscrito;
      if (km == null || costo == null) {
        resultado.add(null);
        continue;
      }
      final desde = hasta;
      hasta += km;
      total += costo;
      resultado.add((desde, hasta, total));
    }
    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ColoresApp.superficie,
            borderRadius: BorderRadius.circular(RadiosApp.tarjeta),
            border: Border.all(color: ColoresApp.borde),
          ),
          child: _error != null
              ? Text(_error!, style: const TextStyle(color: ColoresApp.rojo))
              : _cargando
              ? const Center(child: CircularProgressIndicator())
              : _contenido(),
        ),
      ),
    );
  }

  Widget _contenido() {
    final acumulados = _acumulados();
    final ultimo = _filas.length > 1 ? _filas.last : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Iconos.route, color: ColoresApp.rojo, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Precio del viaje en mototaxi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ColoresApp.azul),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'El servidor mide el viaje por calles. El precio base cubre los primeros km; cada fila de km extra suma '
          'sus km y su costo a los anteriores. Edita los números en la tabla y guarda la fila.',
          style: TextStyle(color: ColoresApp.textoSuave),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, restricciones) => restricciones.maxWidth >= 760
              ? _tabla(acumulados)
              : Column(
                  children: [
                    for (var i = 0; i < _filas.length; i++) _tarjeta(_filas[i], acumulados[i]),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        if (ultimo != null && ultimo.kmGuardado != null && acumulados.last != null)
          Text(
            'Más de ${_texto(acumulados.last!.$2)} km: se repite el último tramo '
            '(${_texto(ultimo.kmGuardado!)} km más por ${_bs(ultimo.costoGuardado!)} más).',
            style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _ocupado || _filas.any((f) => f.nueva) ? null : _agregar,
          icon: const Icon(Iconos.plus, size: 14),
          label: const Text('Agregar km extra'),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ tabla (escritorio)

  static const _anchos = {
    0: FixedColumnWidth(70),
    1: FlexColumnWidth(1.1),
    2: FlexColumnWidth(1.1),
    3: FlexColumnWidth(1.2),
    4: FlexColumnWidth(1),
    5: FixedColumnWidth(150),
  };

  Widget _tabla(List<(double, double, double)?> acumulados) {
    const encabezado = TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5);
    Widget celdaTitulo(String t) => Padding(padding: const EdgeInsets.all(12), child: Text(t, style: encabezado));
    return ClipRRect(
      borderRadius: BorderRadius.circular(RadiosApp.control),
      child: Table(
        columnWidths: _anchos,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: const TableBorder(
          horizontalInside: BorderSide(color: ColoresApp.borde),
          verticalInside: BorderSide(color: ColoresApp.borde),
          left: BorderSide(color: ColoresApp.borde),
          right: BorderSide(color: ColoresApp.borde),
          bottom: BorderSide(color: ColoresApp.borde),
        ),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: ColoresApp.azul),
            children: [
              celdaTitulo('N°'),
              celdaTitulo('Km'),
              celdaTitulo('Costo (Bs)'),
              celdaTitulo('Recorrido'),
              celdaTitulo('Precio total'),
              celdaTitulo('Acciones'),
            ],
          ),
          for (var i = 0; i < _filas.length; i++)
            TableRow(
              decoration: BoxDecoration(
                color: _filas[i].esBase
                    ? ColoresApp.azulNeblina
                    : (i.isOdd ? ColoresApp.superficie : ColoresApp.filaAlterna),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _filas[i].esBase ? 'Base' : '$i',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.texto),
                  ),
                ),
                Padding(padding: const EdgeInsets.all(8), child: _campo(_filas[i], _filas[i].km, 'km')),
                Padding(padding: const EdgeInsets.all(8), child: _campo(_filas[i], _filas[i].costo, 'Bs')),
                Padding(padding: const EdgeInsets.all(12), child: Text(_recorrido(_filas[i], acumulados[i]))),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    acumulados[i] == null ? '-' : _bs(acumulados[i]!.$3),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azul),
                  ),
                ),
                Padding(padding: const EdgeInsets.all(6), child: _acciones(_filas[i])),
              ],
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ tarjetas (pantallas angostas)

  Widget _tarjeta(_Fila fila, (double, double, double)? acumulado) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fila.esBase ? ColoresApp.azulNeblina : ColoresApp.superficie,
        borderRadius: BorderRadius.circular(RadiosApp.control),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fila.esBase ? 'Precio base' : 'Km extra ${_numero(fila)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azul),
                ),
              ),
              _acciones(fila),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _campo(fila, fila.km, 'km')),
              const SizedBox(width: 10),
              Expanded(child: _campo(fila, fila.costo, 'Bs')),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_recorrido(fila, acumulado)}  ·  Total ${acumulado == null ? '-' : _bs(acumulado.$3)}',
            style: const TextStyle(color: ColoresApp.textoSuave),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ partes

  String _recorrido(_Fila fila, (double, double, double)? acumulado) {
    if (acumulado == null) return '-';
    return fila.esBase ? 'Hasta ${_texto(acumulado.$2)} km' : 'De ${_texto(acumulado.$1)} a ${_texto(acumulado.$2)} km';
  }

  Widget _campo(_Fila fila, TextEditingController controlador, String sufijo) {
    return TextField(
      controller: controlador,
      enabled: !_ocupado,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        isDense: true,
        suffixText: sufijo,
        prefixText: !fila.esBase && sufijo == 'km' ? '+ ' : null,
      ),
    );
  }

  Widget _acciones(_Fila fila) {
    final puedeGuardar = !_ocupado && fila.cambiada && fila.valida;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: fila.nueva ? 'Guardar km extra' : 'Guardar cambios',
          onPressed: puedeGuardar ? () => _guardar(fila) : null,
          icon: Icon(Iconos.floppyDisk, size: 17, color: puedeGuardar ? ColoresApp.exito : ColoresApp.textoSuave),
        ),
        if (fila.nueva)
          IconButton(
            tooltip: 'Cancelar',
            onPressed: _ocupado ? null : () => _cancelar(fila),
            icon: const Icon(Iconos.xmark, size: 17, color: ColoresApp.textoSuave),
          )
        else if (!fila.esBase)
          IconButton(
            tooltip: 'Eliminar',
            onPressed: _ocupado ? null : () => _eliminar(fila),
            icon: const Icon(Iconos.trashCan, size: 17, color: ColoresApp.rojo),
          ),
      ],
    );
  }
}
