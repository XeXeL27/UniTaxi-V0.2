import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/relieve.dart';
import '../../core/tema.dart';
import '../boton_relieve.dart';
import '../campos_ficha.dart';
import '../insignia_estado.dart';
import '../modal_registro.dart';
import '../notificaciones.dart';
import 'columna_tabla.dart';
import 'exportador.dart';
import 'filtros.dart';
import 'iconos_tabla.dart';

/// Tabla de datos reutilizable del panel: busqueda general, filtros por columna segun el tipo
/// de dato, orden por columna, paginacion y exportacion a Excel, CSV y PDF. Todo se hace sobre
/// la lista ya cargada, sin volver a consultar al backend.
///
/// Las filas van numeradas (N° 1..N sobre la lista filtrada y ordenada) y se ordenan con el menu
/// "Ordenar" (A-Z / Z-A, mas reciente / mas antiguo, menor / mayor) o con clic en el encabezado.
///
/// Es responsive y nunca se desplaza de costado: las columnas se reparten el ancho disponible y, si no
/// entran todas, se ocultan las de la derecha. No hay columna de acciones: la fila entera se levanta al
/// pasar el mouse y un clic (o toque) abre el registro con todos sus datos y sus acciones arriba.
class TablaDatos<T> extends StatefulWidget {
  final String titulo;
  final IconData icono;
  final List<ColumnaTabla<T>> columnas;
  final List<T> filas;
  final bool cargando;
  final String? error;
  final VoidCallback? alRecargar;

  /// Botones de la cabecera de la tarjeta (por ejemplo "Agregar").
  final List<Widget> acciones;

  /// Acciones de cada registro (editar, eliminar, etc.): van arriba, en la cabecera del modal que se
  /// abre al tocar la fila. [hecho] recarga la tabla y cierra ese modal; se llama cuando la accion se
  /// realizo.
  final List<AccionRegistro> Function(T fila, VoidCallback hecho)? accionesFila;

  /// Si se indica, tocar la fila abre esta vista (el registro con edicion, el expediente de un
  /// conductor...) en lugar del modal generico con los datos de la fila.
  final void Function(T fila)? alAbrir;

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
    this.alAbrir,
  });

  @override
  State<TablaDatos<T>> createState() => _TablaDatosState<T>();
}

class _TablaDatosState<T> extends State<TablaDatos<T>> {
  static const _opcionesPorPagina = [10, 25, 50, 100];

  /// Bajo este ancho la tabla usa celdas y botones compactos.
  static const _anchoCompacta = 560.0;

  final _controlBusqueda = TextEditingController();

  String _busqueda = '';
  final Map<int, FiltroColumna> _filtros = {};
  bool _mostrarFiltros = false;

  /// Cambia al limpiar los filtros para reconstruir los campos con sus valores iniciales.
  int _generacionFiltros = 0;

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

  /// Texto de cada sentido de orden segun el tipo de dato de la columna.
  static (String, String) _textosOrden(TipoColumna tipo) => switch (tipo) {
    TipoColumna.fecha || TipoColumna.fechaHora => ('Más antiguo primero', 'Más reciente primero'),
    TipoColumna.numero => ('Menor a mayor', 'Mayor a menor'),
    TipoColumna.texto || TipoColumna.estado => ('De la A a la Z', 'De la Z a la A'),
  };

  @override
  Widget build(BuildContext context) {
    final visibles = _filasVisibles;
    final totalPaginas = visibles.isEmpty ? 1 : (visibles.length / _porPagina).ceil();
    final pagina = _pagina.clamp(0, totalPaginas - 1);
    final inicio = pagina * _porPagina;
    final filasPagina = visibles.skip(inicio).take(_porPagina).toList();
    final movil = Pantalla.esMovil(context);

    return Container(
      padding: EdgeInsets.all(movil ? 14 : 22),
      decoration: Relieve.tarjeta(radio: 16),
      child: LayoutBuilder(
        builder: (context, restricciones) {
          final compacta = restricciones.maxWidth < _anchoCompacta;
          final diseno = _DisenoTabla.calcular<T>(
            columnas: widget.columnas,
            // Se descuenta el borde exterior de la tabla (1 px por lado).
            anchoDisponible: restricciones.maxWidth - 2,
            compacta: compacta,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cabecera(),
              const SizedBox(height: 16),
              _barraHerramientas(visibles, movil),
              // El panel de filtros se despliega y se recoge con animacion.
              AnimatedSize(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (hijo, animacion) => FadeTransition(
                    opacity: animacion,
                    child: SlideTransition(
                      position: animacion.drive(Tween(begin: const Offset(0, -0.06), end: Offset.zero)),
                      child: hijo,
                    ),
                  ),
                  child: _mostrarFiltros
                      ? Padding(
                          key: const ValueKey('filtros'),
                          padding: const EdgeInsets.only(top: 12),
                          child: _panelFiltros(movil),
                        )
                      : const SizedBox(key: ValueKey('sin-filtros'), width: double.infinity),
                ),
              ),
              const SizedBox(height: 12),
              if (widget.cargando)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: LinearProgressIndicator(
                    color: ColoresApp.rojo,
                    minHeight: 3,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              if (widget.error != null)
                _mensajeError(widget.error!)
              else if (filasPagina.isEmpty)
                _sinRegistros()
              else
                _tabla(filasPagina, inicio, diseno),
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
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: Relieve.levantado,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Relieve.linea),
                boxShadow: Relieve.sombraLevantado,
              ),
              child: Icon(widget.icono, color: ColoresApp.azul, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              widget.titulo,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ColoresApp.azul),
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
        _menuOrden(),
        if (widget.alRecargar != null)
          BotonRelieve(
            icono: IconosTabla.recargar.icon,
            ayuda: 'Recargar',
            alPresionar: widget.cargando ? null : widget.alRecargar,
          ),
        _grupoExportar(visibles),
      ],
    );
  }

  /// Menu de orden: para cada columna, sus dos sentidos con texto segun el tipo de dato.
  Widget _menuOrden() {
    final actual = _columnaOrden;
    String etiqueta() {
      if (actual == null) return 'Ordenar';
      final (asc, desc) = _textosOrden(widget.columnas[actual].tipo);
      return '${widget.columnas[actual].titulo}: ${_ascendente ? asc : desc}';
    }

    return PopupMenuButton<(int, bool)?>(
      tooltip: 'Ordenar los registros',
      popUpAnimationStyle: const AnimationStyle(
        curve: Curves.easeOutBack,
        duration: Duration(milliseconds: 380),
        reverseCurve: Curves.easeIn,
        reverseDuration: Duration(milliseconds: 160),
      ),
      onSelected: (opcion) => setState(() {
        if (opcion == null) {
          _columnaOrden = null;
          _ascendente = true;
        } else {
          _columnaOrden = opcion.$1;
          _ascendente = opcion.$2;
        }
        _pagina = 0;
      }),
      itemBuilder: (_) => [
        const PopupMenuItem<(int, bool)?>(value: null, child: Text('Orden original')),
        for (var i = 0; i < widget.columnas.length; i++) ...[
          const PopupMenuDivider(),
          PopupMenuItem<(int, bool)?>(
            enabled: false,
            height: 30,
            child: Text(
              widget.columnas[i].titulo,
              style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azul),
            ),
          ),
          for (final ascendente in [true, false])
            PopupMenuItem<(int, bool)?>(
              value: (i, ascendente),
              height: 36,
              child: Row(
                children: [
                  SizedBox(width: 22, child: actual == i && _ascendente == ascendente ? IconosTabla.marcado : null),
                  Text(
                    ascendente ? _textosOrden(widget.columnas[i].tipo).$1 : _textosOrden(widget.columnas[i].tipo).$2,
                  ),
                ],
              ),
            ),
        ],
      ],
      child: IgnorePointer(
        child: OutlinedButton.icon(onPressed: () {}, icon: IconosTabla.ordenar, label: Text(etiqueta())),
      ),
    );
  }

  /// Botones de exportacion: Excel en verde, CSV en turquesa y PDF en rojo (el color de cada formato).
  Widget _grupoExportar(List<T> visibles) {
    Widget boton(String texto, IconData? icono, FormatoExportacion formato, TonoBoton tono) => BotonRelieve(
      texto: texto,
      icono: icono,
      tono: tono,
      ayuda: 'Exportar lo que se ve en la tabla a $texto',
      alPresionar: _exportando ? null : () => _exportar(formato, visibles),
    );

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        boton('Excel', IconosTabla.excel.icon, FormatoExportacion.excel, TonoBoton.excel),
        boton('CSV', IconosTabla.csv.icon, FormatoExportacion.csv, TonoBoton.turquesa),
        boton('PDF', IconosTabla.pdf.icon, FormatoExportacion.pdf, TonoBoton.pdf),
        if (_exportando)
          const Padding(
            padding: EdgeInsets.only(left: 4, top: 12),
            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }

  Widget _panelFiltros(bool movil) {
    return Container(
      key: ValueKey(_generacionFiltros),
      padding: const EdgeInsets.all(14),
      decoration: Relieve.panelHundido(radio: 12),
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
          borderRadius: BorderRadius.circular(14),
          dropdownColor: Colors.white,
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
      decoration: Relieve.panelHundido(radio: 12),
      child: Text(
        widget.cargando
            ? 'Cargando...'
            : (_busqueda.isNotEmpty || _filtrosActivos > 0
                  ? 'Ningún registro coincide con la búsqueda o los filtros'
                  : 'No hay registros'),
        style: const TextStyle(color: Relieve.tenue),
      ),
    );
  }

  /// Tabla con bordes entre celdas: N° y las columnas visibles. Cada fila se puede tocar.
  ///
  /// Rendimiento: las filas no se miden con IntrinsicHeight; las lineas verticales del cuerpo se
  /// dibujan una sola vez encima de todas las filas.
  Widget _tabla(List<T> filasPagina, int inicio, _DisenoTabla diseno) {
    final separadores = <double>[];
    var x = diseno.anchoNumero;
    separadores.add(x);
    for (final ancho in diseno.anchos) {
      x += ancho;
      separadores.add(x);
    }
    // Sin linea despues de la ultima columna: llega hasta el borde derecho.
    if (separadores.isNotEmpty) separadores.removeLast();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Relieve.linea),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Relieve.sombraSuave, offset: Offset(0, 1), blurRadius: 2),
          BoxShadow(color: Relieve.sombra, offset: Offset(0, 10), blurRadius: 24, spreadRadius: -14),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _filaEncabezado(diseno),
          Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var f = 0; f < filasPagina.length; f++)
                    _FilaTabla(
                      // Clave por pagina: al cambiar de pagina las filas vuelven a entrar.
                      key: ValueKey('${inicio + f}'),
                      indice: f,
                      alterna: f.isOdd,
                      alTocar: () => _abrir(filasPagina[f], inicio + f + 1),
                      child: _filaDatos(filasPagina[f], inicio + f + 1, diseno),
                    ),
                ],
              ),
              for (final posicion in separadores)
                Positioned(
                  left: posicion - 1,
                  top: 0,
                  bottom: 0,
                  child: const IgnorePointer(
                    child: SizedBox(width: 1, child: ColoredBox(color: ColoresApp.borde)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filaEncabezado(_DisenoTabla diseno) {
    final columnas = widget.columnas;
    const borde = Color(0x33FFFFFF);
    const estilo = TextStyle(color: Colors.white, fontWeight: FontWeight.w700);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF213F72), ColoresApp.azul],
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _contenedorCelda(
              ancho: diseno.anchoNumero,
              bordeDerecho: true,
              colorBorde: borde,
              alineacion: Alignment.center,
              compacta: diseno.compacta,
              child: const Text('N°', style: estilo),
            ),
            for (var v = 0; v < diseno.visibles.length; v++)
              _contenedorCelda(
                ancho: diseno.anchos[v],
                bordeDerecho: v < diseno.visibles.length - 1,
                colorBorde: borde,
                compacta: diseno.compacta,
                child: _encabezado(diseno.visibles[v], columnas[diseno.visibles[v]]),
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
    final (asc, desc) = _textosOrden(columna.tipo);
    return Tooltip(
      message: 'Ordenar: ${activa && _ascendente ? desc : asc}',
      child: InkWell(
        onTap: () => _ordenarPor(indice),
        child: Row(
          children: [
            Flexible(
              child: Text(
                columna.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
            icono,
          ],
        ),
      ),
    );
  }

  Widget _filaDatos(T fila, int numero, _DisenoTabla diseno) {
    return Row(
      children: [
        _contenedorCelda(
          ancho: diseno.anchoNumero,
          bordeDerecho: false,
          alineacion: Alignment.center,
          compacta: diseno.compacta,
          child: Text(
            '$numero',
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azul),
          ),
        ),
        for (var v = 0; v < diseno.visibles.length; v++)
          _contenedorCelda(
            ancho: diseno.anchos[v],
            bordeDerecho: false,
            compacta: diseno.compacta,
            child: _celda(widget.columnas[diseno.visibles[v]], fila, unaLinea: true),
          ),
      ],
    );
  }

  void _abrir(T fila, int numero) {
    final alAbrir = widget.alAbrir;
    if (alAbrir != null) {
      alAbrir(fila);
    } else {
      _mostrarDetalle(fila, numero);
    }
  }

  /// Modal con todos los datos del registro y, arriba, sus acciones.
  Future<void> _mostrarDetalle(T fila, int numero) {
    final cierre = CierreModal();
    void hecho() {
      widget.alRecargar?.call();
      cierre.cerrar();
    }

    return abrirRegistro(
      context,
      ModalRegistro(
        icono: widget.icono,
        titulo: widget.titulo,
        subtitulo: 'Registro N° $numero',
        acciones: widget.accionesFila?.call(fila, hecho) ?? const [],
        cierre: cierre,
        contenido: (contexto, _) {
          return GrillaFicha(
            children: [
              for (final columna in widget.columnas)
                columna.celda != null || columna.tipo == TipoColumna.estado
                    ? DatoFicha.widget(columna.titulo, contenido: _celda(columna, fila, vacio: 'Sin dato'))
                    : DatoFicha(columna.titulo, columna.texto(fila)),
            ],
          );
        },
      ),
      anchoMaximo: 720,
    );
  }

  Widget _contenedorCelda({
    required double ancho,
    required bool bordeDerecho,
    required Widget child,
    Color colorBorde = ColoresApp.borde,
    EdgeInsets? relleno,
    Alignment alineacion = Alignment.centerLeft,
    bool compacta = false,
  }) {
    return Container(
      width: ancho,
      padding:
          relleno ??
          (compacta
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 11)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
      alignment: alineacion,
      decoration: BoxDecoration(
        border: bordeDerecho ? Border(right: BorderSide(color: colorBorde)) : null,
      ),
      child: child,
    );
  }

  /// [unaLinea]: en la tabla el texto no baja a otra linea (todas las filas miden lo mismo); si no
  /// entra termina en "..." y se ve completo al pasar el mouse o mantener presionado, ademas del ojo.
  Widget _celda(ColumnaTabla<T> columna, T fila, {String vacio = '', bool unaLinea = false}) {
    final propia = columna.celda;
    if (propia != null) return propia(fila);
    if (columna.tipo == TipoColumna.estado) {
      final valor = columna.valor(fila)?.toString();
      if (valor == null) return Text(vacio);
      final insignia = Align(alignment: Alignment.centerLeft, child: InsigniaEstado(valor));
      return unaLinea ? FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: insignia) : insignia;
    }
    final texto = columna.texto(fila);
    if (!unaLinea || texto.isEmpty) return Text(texto.isEmpty ? vacio : texto);
    return Tooltip(
      message: texto,
      waitDuration: const Duration(milliseconds: 400),
      child: Text(texto, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
    );
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

/// Fila de datos que se puede tocar: con el mouse encima se levanta (sube 1 px, toma el degradado de
/// lo levantado, una barra azul a la izquierda y su sombra) y el cursor pasa a ser la mano.
class _FilaTabla extends StatefulWidget {
  final int indice;
  final bool alterna;
  final VoidCallback alTocar;
  final Widget child;

  const _FilaTabla({
    super.key,
    required this.indice,
    required this.alterna,
    required this.alTocar,
    required this.child,
  });

  @override
  State<_FilaTabla> createState() => _FilaTablaState();
}

class _FilaTablaState extends State<_FilaTabla> with SingleTickerProviderStateMixin {
  bool _encima = false;
  bool _presionada = false;

  /// Entrada de la fila: aparece subiendo 8 px, cada una 30 ms despues de la anterior.
  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 30 * widget.indice), () {
      if (mounted) _entrada.forward();
    });
  }

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final levantada = _encima && !_presionada;
    final entrada = CurvedAnimation(parent: _entrada, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: entrada,
      child: SlideTransition(
        position: entrada.drive(Tween(begin: const Offset(0, 0.18), end: Offset.zero)),
        child: _fila(levantada),
      ),
    );
  }

  Widget _fila(bool levantada) {
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _encima = true),
        onExit: (_) => setState(() {
          _encima = false;
          _presionada = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _presionada = true),
          onTapCancel: () => setState(() => _presionada = false),
          onTapUp: (_) => setState(() => _presionada = false),
          onTap: widget.alTocar,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, levantada ? -1 : 0, 0),
            decoration: BoxDecoration(
              gradient: levantada
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFFFFF), Color(0xFFEAF0FB)],
                    )
                  : null,
              color: levantada
                  ? null
                  : _presionada
                  ? const Color(0xFFE3E9F4)
                  : (widget.alterna ? ColoresApp.filaAlterna : Colors.white),
              border: Border(
                top: BorderSide(color: levantada ? Colors.white : Relieve.lineaSuave),
                left: BorderSide(color: levantada ? TonoBoton.azul.color! : Colors.transparent, width: 3),
              ),
              boxShadow: levantada
                  ? const [
                      BoxShadow(color: Relieve.sombra, offset: Offset(0, 3), blurRadius: 8, spreadRadius: -2),
                      BoxShadow(color: Relieve.sombraSuave, offset: Offset(0, -1), blurRadius: 3),
                    ]
                  : const [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Que columnas entran en pantalla y con que ancho. Si no entran todas se ocultan las de la
/// derecha (la primera siempre queda). La columna N° tiene ancho fijo.
class _DisenoTabla {
  final List<int> visibles;
  final List<int> ocultas;
  final List<double> anchos;

  /// Ancho de la columna N°: mas angosta en tablas compactas (celular).
  final double anchoNumero;

  /// Tabla angosta: celdas con menos relleno y botones de acciones compactos.
  final bool compacta;

  const _DisenoTabla(this.visibles, this.ocultas, this.anchos, this.anchoNumero, this.compacta);

  static _DisenoTabla calcular<T>({
    required List<ColumnaTabla<T>> columnas,
    required double anchoDisponible,
    required bool compacta,
  }) {
    final anchoNumero = compacta ? 42.0 : 56.0;
    final fijo = anchoNumero;
    final visibles = <int>[];
    var usado = fijo;
    for (var i = 0; i < columnas.length; i++) {
      if (visibles.isNotEmpty && usado + columnas[i].anchoMinimo > anchoDisponible) break;
      visibles.add(i);
      usado += columnas[i].anchoMinimo;
    }
    final ocultas = [
      for (var i = 0; i < columnas.length; i++)
        if (!visibles.contains(i)) i,
    ];

    // El espacio sobrante se reparte segun la proporcion de cada columna.
    final minimos = [for (final i in visibles) columnas[i].anchoMinimo];
    final sumaMinimos = minimos.fold<double>(0, (a, b) => a + b);
    final sumaProporciones = visibles.fold<double>(0, (a, i) => a + columnas[i].flex);
    final sobrante = (anchoDisponible - sumaMinimos - fijo).clamp(0.0, double.infinity);
    final anchos = [
      for (var v = 0; v < visibles.length; v++) minimos[v] + sobrante * columnas[visibles[v]].flex / sumaProporciones,
    ];
    // Si ni la primera columna entra completa, se ajusta al espacio real para no desbordar.
    final sumaAnchos = anchos.fold<double>(0, (a, b) => a + b) + fijo;
    if (sumaAnchos > anchoDisponible && anchos.isNotEmpty) {
      anchos[0] = (anchos[0] - (sumaAnchos - anchoDisponible)).clamp(60.0, double.infinity);
    }
    return _DisenoTabla(visibles, ocultas, anchos, anchoNumero, compacta);
  }
}
