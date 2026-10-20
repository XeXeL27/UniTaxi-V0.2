import 'package:flutter/material.dart';

import '../core/api_excepcion.dart';
import 'modal_registro.dart';
import 'tabla/columna_tabla.dart';
import 'tabla/tabla_datos.dart';

/// [TablaDatos] que carga sus filas desde el backend y se puede recargar despues de guardar.
class ListadoRemoto<T> extends StatefulWidget {
  final String titulo;
  final IconData icono;
  final String nombreArchivo;
  final Future<List<T>> Function() cargar;
  final List<ColumnaTabla<T>> columnas;

  /// Botones de la cabecera; reciben la funcion para recargar la tabla.
  final List<Widget> Function(VoidCallback recargar)? acciones;

  /// Acciones de cada registro, arriba en el modal que abre la fila (ver [TablaDatos.accionesFila]).
  /// [hecho] recarga la tabla y cierra el modal.
  final List<AccionRegistro> Function(T fila, VoidCallback hecho)? accionesFila;

  /// Vista propia al tocar la fila; recibe la fila y la funcion para recargar la tabla.
  final void Function(T fila, VoidCallback recargar)? alAbrir;

  const ListadoRemoto({
    super.key,
    required this.titulo,
    required this.icono,
    required this.nombreArchivo,
    required this.cargar,
    required this.columnas,
    this.acciones,
    this.accionesFila,
    this.alAbrir,
  });

  @override
  State<ListadoRemoto<T>> createState() => _ListadoRemotoState<T>();
}

class _ListadoRemotoState<T> extends State<ListadoRemoto<T>> {
  List<T> _filas = const [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  Future<void> _recargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final filas = await widget.cargar();
      if (mounted) setState(() => _filas = filas);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (e) {
      if (mounted) setState(() => _error = 'Error al cargar los datos: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TablaDatos<T>(
      titulo: widget.titulo,
      icono: widget.icono,
      nombreArchivo: widget.nombreArchivo,
      columnas: widget.columnas,
      filas: _filas,
      cargando: _cargando,
      error: _error,
      alRecargar: _recargar,
      acciones: widget.acciones?.call(_recargar) ?? const [],
      accionesFila: widget.accionesFila,
      alAbrir: widget.alAbrir == null ? null : (fila) => widget.alAbrir!(fila, _recargar),
    );
  }
}
