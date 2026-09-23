import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../insignia_estado.dart';
import '../notificaciones.dart';
import 'columna_tabla.dart';
import 'exportador.dart';
import 'filtros.dart';
import 'iconos_tabla.dart';

/// Tabla de datos reutilizable del panel: busqueda general, filtros por columna segun el tipo
/// de dato, orden por columna, paginacion y exportacion a Excel, CSV y PDF. Todo se hace sobre
/// la lista ya cargada, sin volver a consultar al backend.
///
/// Es responsive, al estilo de DataTables Responsive: las columnas se reparten el ancho disponible
/// y, si no entran todas, se ocultan las de la derecha y cada fila muestra un boton "+" que despliega
/// debajo los datos ocultos. La columna de acciones siempre queda visible.
class TablaDatos<T> extends StatefulWidget {
  final String titulo;
  final FaIconData icono;
  final List<ColumnaTabla<T>> columnas;
  final List<T> filas;
  final bool cargando;
  final String? error;
  final VoidCallback? alRecargar;

  /// Botones de la cabecera de la tarjeta (por ejemplo "Agregar").
  final List<Widget> acciones;

  /// Botones por fila (editar, eliminar, etc.). Si es null no hay columna de acciones.
  final List<Widget> Function(T fila)? accionesFila;

  /// Nombre base de los archivos exportados (sin extension).
  final String nombreArchivo;

  const TablaDatos({
    super.key,
    required this.titulo,
    required this.icono,
    required this.columnas,
    required this.filas,
    required this.nombreArchivo,
    this.cargando = false,
    this.error,
    this.alRecargar,
    this.acciones = const [],
    this.accionesFila,
  });

  @override
  State<TablaDatos<T>> createState() => _TablaDatosState<T>();
}

class _TablaDatosState<T> extends State<TablaDatos<T>> {
  static const _opcionesPorPagina = [10, 25, 50, 100];

  /// Ancho de cada boton de accion por fila (IconButton) mas margen.
  static const _anchoPorAccion = 42.0;

  final _controlBusqueda = TextEditingController();

  String _busqueda = '';
  final Map<int, FiltroColumna> _filtros = {};
  bool _mostrarFiltros = false;

  /// Cambia al limpiar los filtros para reconstruir los campos con sus valores iniciales.
  int _generacionFiltros = 0;

  /// Filas cuyo detalle (columnas ocultas) esta desplegado.
  final Set<T> _desplegadas = {};

  int? _columnaOrden;
  bool _ascendente = true;
  int _pagina = 0;
  int _porPagina = 10;
  bool _exportando = false;

  @override
  void dispose() {
    _controlBusqueda.dispose();
    super.dispose();
  }

  List<T> get _filasVisibles {
    final termino = _busqueda.trim().toLowerCase();
    final filtrosActivos = _filtros.entries.where((e) => !e.value.vacio).toList();

    final resultado = widget.filas.where((fila) {
      if (termino.isNotEmpty && !widget.columnas.any((c) => c.texto(fila).toLowerCase().contains(termino))) {
        return false;
      }
      for (final filtro in filtrosActivos) {
        final columna = widget.columnas[filtro.key];
        if (!filtro.value.cumple(columna.valor(fila), columna.texto(fila))) return false;
      }
      return true;
    }).toList();

    final indiceOrden = _columnaOrden;
    if (indiceOrden != null) {
      final columna = widget.columnas[indiceOrden];
      resultado.sort((a, b) {
        final comparacion = _comparar(columna.valor(a), columna.valor(b));
        return _ascendente ? comparacion : -comparacion;
      });
    }
    return resultado;
  }

  /// Los nulos van siempre al final; texto sin distinguir mayusculas.
  int _comparar(Object? a, Object? b) {
    if (a == null && b == null) return 0;
    if (a == null) return _ascendente ? 1 : -1;
    if (b == null) return _ascendente ? -1 : 1;
    if (a is num && b is num) return a.compareTo(b);
    if (a is DateTime && b is DateTime) return a.compareTo(b);
    return a.toString().toLowerCase().compareTo(b.toString().toLowerCase());
  }

  int get _filtrosActivos => _filtros.values.where((f) => !f.vacio).length;

  void _ordenarPor(int indice) {
    setState(() {
      if (_columnaOrden == indice) {
        _ascendente = !_ascendente;
      } else {
        _columnaOrden = indice;
        _ascendente = true;
      }
    });
  }

  void _cambiarFiltro(int indice, FiltroColumna? filtro) {
    setState(() {
      if (filtro == null || filtro.vacio) {
        _filtros.remove(indice);
      } else {
        _filtros[indice] = filtro;
      }
      _pagina = 0;
    });
  }

  void _limpiarFiltros() {
    setState(() {
      _filtros.clear();
      _busqueda = '';
      _controlBusqueda.clear();
      _generacionFiltros++;
      _pagina = 0;
    });
  }

  Future<void> _exportar(FormatoExportacion formato, List<T> filas) async {
    if (filas.isEmpty) {
      mostrarMensaje(context, 'No hay registros para exportar', error: true);
      return;
    }
    setState(() => _exportando = true);
    try {
      await Exportador.exportar<T>(
        formato: formato,
        titulo: widget.titulo,
        nombreArchivo: widget.nombreArchivo,
        columnas: widget.columnas,
        filas: filas,
      );
    } catch (e) {
      if (mounted) mostrarMensaje(context, 'No se pudo exportar: $e', error: true);
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  /// Ancho de la columna de acciones segun cuantos botones tiene la primera fila.
  double _anchoAcciones(List<T> filas) {
    final accionesFila = widget.accionesFila;
    if (accionesFila == null) return 0;
    final cantidad = filas.isEmpty ? 1 : accionesFila(filas.first).length;
    // Nunca mas angosta que el titulo "Acciones".
    final ancho = cantidad * _anchoPorAccion + 24;
    return ancho < 100 ? 100 : ancho;
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _filasVisibles;
    final totalPaginas = visibles.isEmpty ? 1 : (visibles.length / _porPagina).ceil();
    final pagina = _pagina.clamp(0, totalPaginas - 1);
    final inicio = pagina * _porPagina;
    final filasPagina = visibles.skip(inicio).take(_porPagina).toList();
    final movil = Pantalla.esMovil(context);

    return Container(
      padding: EdgeInsets.all(movil ? 14 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: LayoutBuilder(
        builder: (context, restricciones) {
          final diseno = _DisenoTabla.calcular<T>(
            columnas: widget.columnas,
            // Se descuenta el borde exterior de la tabla (1 px por lado).
            anchoDisponible: restricciones.maxWidth - 2,
            anchoAcciones: _anchoAcciones(widget.filas),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cabecera(),
              const SizedBox(height: 16),
              _barraHerramientas(visibles, movil),
              if (_mostrarFiltros) ...[const SizedBox(height: 12), _panelFiltros(movil)],
              const SizedBox(height: 12),
              if (widget.cargando) const LinearProgressIndicator(color: ColoresApp.rojo, minHeight: 3),
              if (widget.error != null)
                _mensajeError(widget.error!)
              else if (filasPagina.isEmpty)
                _sinRegistros()
              else
                _tabla(filasPagina, diseno),
              const SizedBox(height: 12),
              _paginacion(visibles.length, inicio, filasPagina.length, pagina, totalPaginas, movil),
            ],
          );
        },
      ),
    );
  }

  Widget _cabecera() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(widget.icono, color: ColoresApp.azul, size: 20),
            const SizedBox(width: 10),
            Text(
              widget.titulo,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: ColoresApp.azul),
            ),
          ],
        ),
        if (widget.acciones.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: widget.acciones),
      ],
    );
  }

  Widget _barraHerramientas(List<T> visibles, bool movil) {
    final filtrosActivos = _filtrosActivos;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: movil ? double.infinity : 320,
          child: TextField(
            controller: _controlBusqueda,
            decoration: InputDecoration(
              hintText: 'Buscar en todas las columnas',
              prefixIcon: const Padding(padding: EdgeInsets.all(12), child: IconosTabla.buscar),
              suffixIcon: _busqueda.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar busqueda',
                      icon: IconosTabla.limpiar,
                      onPressed: () => setState(() {
                        _controlBusqueda.clear();
                        _busqueda = '';
                        _pagina = 0;
                      }),
                    ),
            ),
            onChanged: (valor) => setState(() {
              _busqueda = valor;
              _pagina = 0;
            }),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _mostrarFiltros = !_mostrarFiltros),
          icon: IconosTabla.filtro,
          label: Text(filtrosActivos == 0 ? 'Filtros' : 'Filtros ($filtrosActivos)'),
        ),
        if (widget.alRecargar != null)
          IconButton(
            tooltip: 'Recargar',
            onPressed: widget.cargando ? null : widget.alRecargar,
            icon: IconosTabla.recargar,
          ),
        _grupoExportar(visibles),
      ],
    );
  }

  /// Botones de exportacion agrupados (Excel | CSV | PDF), fondo azul marino y texto blanco.
  Widget _grupoExportar(List<T> visibles) {
    Widget boton(String texto, Widget icono, FormatoExportacion formato, BorderRadius radio) {
      return Tooltip(
        message: 'Exportar lo que se ve en la tabla a $texto',
        child: FilledButton.icon(
          onPressed: _exportando ? null : () => _exportar(formato, visibles),
          style: FilledButton.styleFrom(
            backgroundColor: ColoresApp.azul,
            foregroundColor: Colors.white,
            disabledBackgroundColor: ColoresApp.azul.withValues(alpha: 0.5),
            disabledForegroundColor: Colors.white70,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: radio),
          ),
          icon: icono,
          label: Text(texto),
        ),
      );
    }

    const radio = Radius.circular(6);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        boton('Excel', IconosTabla.excel, FormatoExportacion.excel, const BorderRadius.horizontal(left: radio)),
        Container(width: 1, height: 36, color: Colors.white),
        boton('CSV', IconosTabla.csv, FormatoExportacion.csv, BorderRadius.zero),
        Container(width: 1, height: 36, color: Colors.white),
        boton('PDF', IconosTabla.pdf, FormatoExportacion.pdf, const BorderRadius.horizontal(right: radio)),
        if (_exportando)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }

  Widget _panelFiltros(bool movil) {
    return Container(
      key: ValueKey(_generacionFiltros),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresApp.fondo,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              for (var i = 0; i < widget.columnas.length; i++)
                SizedBox(width: movil ? double.infinity : 240, child: _campoFiltro(i, widget.columnas[i])),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _limpiarFiltros,
            icon: IconosTabla.limpiarFiltros,
            label: const Text('Limpiar filtros', style: TextStyle(color: ColoresApp.rojo)),
          ),
        ],
      ),
    );
  }

  Widget _campoFiltro(int indice, ColumnaTabla<T> columna) {
    final actual = _filtros[indice];
    switch (columna.tipo) {
      case TipoColumna.texto:
        return TextFormField(
          initialValue: actual is FiltroTexto ? actual.contiene : '',
          decoration: InputDecoration(labelText: columna.titulo, hintText: 'Contiene...'),
          onChanged: (valor) => _cambiarFiltro(indice, FiltroTexto(valor)),
        );
      case TipoColumna.numero:
        final filtro = actual is FiltroNumero ? actual : const FiltroNumero();
        double? leer(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));
        FiltroNumero? previo() => _filtros[indice] is FiltroNumero ? _filtros[indice] as FiltroNumero : null;
        return _rango(columna.titulo, [
          Expanded(
            child: TextFormField(
              initialValue: filtro.minimo == null ? '' : Formato.numero(filtro.minimo),
              decoration: const InputDecoration(labelText: 'Mín.'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (valor) => _cambiarFiltro(indice, FiltroNumero(minimo: leer(valor), maximo: previo()?.maximo)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextFormField(
              initialValue: filtro.maximo == null ? '' : Formato.numero(filtro.maximo),
              decoration: const InputDecoration(labelText: 'Máx.'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (valor) => _cambiarFiltro(indice, FiltroNumero(minimo: previo()?.minimo, maximo: leer(valor))),
            ),
          ),
        ]);
      case TipoColumna.fecha:
      case TipoColumna.fechaHora:
        final filtro = actual is FiltroFecha ? actual : const FiltroFecha();
        return _rango(columna.titulo, [
          Expanded(
            child: _botonFecha(
              etiqueta: 'Desde',
              valor: filtro.desde,
              alCambiar: (fecha) => _cambiarFiltro(indice, FiltroFecha(desde: fecha, hasta: filtro.hasta)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _botonFecha(
              etiqueta: 'Hasta',
              valor: filtro.hasta,
              alCambiar: (fecha) => _cambiarFiltro(indice, FiltroFecha(desde: filtro.desde, hasta: fecha)),
            ),
          ),
        ]);
      case TipoColumna.estado:
        final opciones =
            columna.opciones ??
            (widget.filas.map((f) => columna.valor(f)?.toString()).whereType<String>().toSet().toList()..sort());
        return DropdownButtonFormField<String?>(
          initialValue: actual is FiltroEstado ? actual.seleccionado : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: columna.titulo),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
            for (final opcion in opciones)
              DropdownMenuItem<String?>(value: opcion, child: Text(Formato.enumTexto(opcion))),
          ],
          onChanged: (valor) => _cambiarFiltro(indice, FiltroEstado(valor)),
        );
    }
  }

  /// Filtro de rango: titulo de la columna arriba y los dos campos (desde / hasta) debajo.
  Widget _rango(String titulo, List<Widget> campos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        Row(children: campos),
      ],
    );
  }

  Widget _botonFecha({required String etiqueta, required DateTime? valor, required ValueChanged<DateTime?> alCambiar}) {
    return InkWell(
      onTap: () async {
        final elegida = await showDatePicker(
          context: context,
          initialDate: valor ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (elegida != null) alCambiar(elegida);
      },
      child: InputDecorator(
        isEmpty: valor == null,
        decoration: InputDecoration(
          labelText: etiqueta,
          suffixIcon: valor == null
              ? const Padding(padding: EdgeInsets.all(10), child: IconosTabla.calendario)
              : IconButton(tooltip: 'Quitar fecha', icon: IconosTabla.quitar, onPressed: () => alCambiar(null)),
        ),
        child: Text(valor == null ? '' : Formato.fecha(valor), overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _mensajeError(String mensaje) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF8D7DA), borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          IconosTabla.error,
          const SizedBox(width: 12),
          Expanded(
            child: Text(mensaje, style: const TextStyle(color: Color(0xFF842029))),
          ),
          if (widget.alRecargar != null) TextButton(onPressed: widget.alRecargar, child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _sinRegistros() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: ColoresApp.borde),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(widget.cargando ? 'Cargando...' : 'No hay registros', style: const TextStyle(color: Colors.black54)),
    );
  }

  /// Tabla con bordes entre celdas. Las columnas que no entran se muestran al desplegar la fila.
  Widget _tabla(List<T> filasPagina, _DisenoTabla diseno) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: ColoresApp.borde),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _filaEncabezado(diseno),
          for (var f = 0; f < filasPagina.length; f++) ..._filaDatos(filasPagina[f], f, diseno),
        ],
      ),
    );
  }

  Widget _filaEncabezado(_DisenoTabla diseno) {
    final columnas = widget.columnas;
    return Container(
      color: ColoresApp.azul,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var v = 0; v < diseno.visibles.length; v++)
              _contenedorCelda(
                ancho: diseno.anchos[v],
                bordeDerecho: v < diseno.visibles.length - 1 || diseno.anchoAcciones > 0,
                colorBorde: const Color(0x33FFFFFF),
                child: _encabezado(diseno.visibles[v], columnas[diseno.visibles[v]]),
              ),
            if (diseno.anchoAcciones > 0)
              _contenedorCelda(
                ancho: diseno.anchoAcciones,
                bordeDerecho: false,
                child: const Text(
                  'Acciones',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _encabezado(int indice, ColumnaTabla<T> columna) {
    final activa = _columnaOrden == indice;
    final icono = !activa
        ? IconosTabla.ordenInactivo
        : (_ascendente ? IconosTabla.ordenAscendente : IconosTabla.ordenDescendente);
    return InkWell(
      onTap: () => _ordenarPor(indice),
      child: Row(
        children: [
          Flexible(
            child: Text(
              columna.titulo,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 6),
          icono,
        ],
      ),
    );
  }

  /// Fila de datos y, si esta desplegada, su detalle con las columnas ocultas.
  List<Widget> _filaDatos(T fila, int posicion, _DisenoTabla diseno) {
    final accionesFila = widget.accionesFila;
    final desplegada = _desplegadas.contains(fila);
    final fondo = posicion.isOdd ? ColoresApp.filaAlterna : Colors.white;

    return [
      Container(
        decoration: BoxDecoration(
          color: fondo,
          border: const Border(top: BorderSide(color: ColoresApp.borde)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var v = 0; v < diseno.visibles.length; v++)
                _contenedorCelda(
                  ancho: diseno.anchos[v],
                  bordeDerecho: v < diseno.visibles.length - 1 || diseno.anchoAcciones > 0,
                  child: v == 0 && diseno.hayOcultas
                      ? Row(
                          children: [
                            _botonDesplegar(fila, desplegada),
                            const SizedBox(width: 8),
                            Expanded(child: _celda(widget.columnas[diseno.visibles[v]], fila)),
                          ],
                        )
                      : _celda(widget.columnas[diseno.visibles[v]], fila),
                ),
              if (accionesFila != null)
                _contenedorCelda(
                  ancho: diseno.anchoAcciones,
                  bordeDerecho: false,
                  relleno: const EdgeInsets.symmetric(horizontal: 4),
                  child: Wrap(children: accionesFila(fila)),
                ),
            ],
          ),
        ),
      ),
      if (desplegada && diseno.hayOcultas)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Color(0xFFEEF2F8),
            border: Border(
              top: BorderSide(color: ColoresApp.borde),
              left: BorderSide(color: ColoresApp.rojo, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final indice in diseno.ocultas)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          widget.columnas[indice].titulo,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azul),
                        ),
                      ),
                      Expanded(child: _celda(widget.columnas[indice], fila, vacio: '-')),
                    ],
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  /// Boton circular rojo con "+" (o azul con "-" cuando esta desplegada), como DataTables.
  Widget _botonDesplegar(T fila, bool desplegada) {
    return Tooltip(
      message: desplegada ? 'Ocultar detalle' : 'Ver más datos',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => setState(() => desplegada ? _desplegadas.remove(fila) : _desplegadas.add(fila)),
        child: Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: desplegada ? ColoresApp.azul : ColoresApp.rojo, shape: BoxShape.circle),
          child: desplegada ? IconosTabla.contraer : IconosTabla.expandir,
        ),
      ),
    );
  }

  Widget _contenedorCelda({
    required double ancho,
    required bool bordeDerecho,
    required Widget child,
    Color colorBorde = ColoresApp.borde,
    EdgeInsets relleno = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  }) {
    return Container(
      width: ancho,
      padding: relleno,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: bordeDerecho ? Border(right: BorderSide(color: colorBorde)) : null,
      ),
      child: child,
    );
  }

  Widget _celda(ColumnaTabla<T> columna, T fila, {String vacio = ''}) {
    final propia = columna.celda;
    if (propia != null) return propia(fila);
    if (columna.tipo == TipoColumna.estado) {
      final valor = columna.valor(fila)?.toString();
      return valor == null ? Text(vacio) : Align(alignment: Alignment.centerLeft, child: InsigniaEstado(valor));
    }
    final texto = columna.texto(fila);
    return Text(texto.isEmpty ? vacio : texto);
  }

  Widget _paginacion(int total, int inicio, int enPagina, int pagina, int totalPaginas, bool movil) {
    final resumen = total == 0
        ? 'Sin resultados'
        : 'Mostrando ${inicio + 1}-${inicio + enPagina} de $total'
              '${total != widget.filas.length ? ' (filtrados de ${widget.filas.length})' : ''}';

    // Ventana de hasta 5 numeros de pagina alrededor de la actual.
    final desde = (pagina - 2).clamp(0, (totalPaginas - 5).clamp(0, totalPaginas));
    final hasta = (desde + 5).clamp(0, totalPaginas);

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          children: [
            Text(resumen, style: const TextStyle(color: Colors.black54)),
            DropdownButton<int>(
              value: _porPagina,
              underline: const SizedBox.shrink(),
              items: [for (final n in _opcionesPorPagina) DropdownMenuItem(value: n, child: Text('$n por página'))],
              onChanged: (valor) => setState(() {
                _porPagina = valor ?? _porPagina;
                _pagina = 0;
              }),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _botonPagina(
              hijo: movil ? IconosTabla.anterior : const Text('Anterior'),
              alPresionar: pagina > 0 ? () => setState(() => _pagina = pagina - 1) : null,
            ),
            if (!movil)
              for (var p = desde; p < hasta; p++)
                _botonPagina(
                  hijo: Text('${p + 1}'),
                  activo: p == pagina,
                  alPresionar: () => setState(() => _pagina = p),
                ),
            if (movil)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('${pagina + 1} / $totalPaginas')),
            _botonPagina(
              hijo: movil ? IconosTabla.siguiente : const Text('Siguiente'),
              alPresionar: pagina < totalPaginas - 1 ? () => setState(() => _pagina = pagina + 1) : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _botonPagina({required Widget hijo, VoidCallback? alPresionar, bool activo = false}) {
    const tamano = Size(40, 38);
    const relleno = EdgeInsets.symmetric(horizontal: 12);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: activo
          ? FilledButton(
              onPressed: alPresionar,
              style: FilledButton.styleFrom(minimumSize: tamano, padding: relleno),
              child: hijo,
            )
          : OutlinedButton(
              onPressed: alPresionar,
              style: OutlinedButton.styleFrom(minimumSize: tamano, padding: relleno),
              child: hijo,
            ),
    );
  }
}

/// Que columnas entran en pantalla y con que ancho. Si no entran todas se ocultan las de la
/// derecha (la primera siempre queda) y la primera columna reserva lugar para el boton "+".
class _DisenoTabla {
  static const _anchoBoton = 28.0;

  final List<int> visibles;
  final List<int> ocultas;
  final List<double> anchos;
  final double anchoAcciones;

  const _DisenoTabla(this.visibles, this.ocultas, this.anchos, this.anchoAcciones);

  bool get hayOcultas => ocultas.isNotEmpty;

  static _DisenoTabla calcular<T>({
    required List<ColumnaTabla<T>> columnas,
    required double anchoDisponible,
    required double anchoAcciones,
  }) {
    final total = columnas.fold<double>(0, (suma, c) => suma + c.anchoMinimo) + anchoAcciones;
    final visibles = <int>[];
    if (total <= anchoDisponible) {
      visibles.addAll(List.generate(columnas.length, (i) => i));
    } else {
      var usado = anchoAcciones + _anchoBoton;
      for (var i = 0; i < columnas.length; i++) {
        if (visibles.isNotEmpty && usado + columnas[i].anchoMinimo > anchoDisponible) break;
        visibles.add(i);
        usado += columnas[i].anchoMinimo;
      }
    }
    final ocultas = [
      for (var i = 0; i < columnas.length; i++)
        if (!visibles.contains(i)) i,
    ];

    // El espacio sobrante se reparte segun la proporcion de cada columna.
    final extraBoton = ocultas.isEmpty ? 0.0 : _anchoBoton;
    final minimos = [for (final i in visibles) columnas[i].anchoMinimo];
    final sumaMinimos = minimos.fold<double>(0, (a, b) => a + b);
    final sumaProporciones = visibles.fold<double>(0, (a, i) => a + columnas[i].flex);
    final sobrante = (anchoDisponible - sumaMinimos - anchoAcciones - extraBoton).clamp(0.0, double.infinity);
    final anchos = [
      for (var v = 0; v < visibles.length; v++)
        minimos[v] + sobrante * columnas[visibles[v]].flex / sumaProporciones + (v == 0 ? extraBoton : 0),
    ];
    // Si ni la primera columna entra completa, se ajusta al espacio real para no desbordar.
    final sumaAnchos = anchos.fold<double>(0, (a, b) => a + b) + anchoAcciones;
    if (sumaAnchos > anchoDisponible && anchos.isNotEmpty) {
      anchos[0] = (anchos[0] - (sumaAnchos - anchoDisponible)).clamp(60.0, double.infinity);
    }
    return _DisenoTabla(visibles, ocultas, anchos, anchoAcciones);
  }
}
