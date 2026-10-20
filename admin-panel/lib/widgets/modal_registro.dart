import 'package:flutter/material.dart';

import '../core/api_excepcion.dart';
import '../core/iconos.dart';
import '../core/relieve.dart';
import '../core/tema.dart';
import 'boton_relieve.dart';
import 'dialogos.dart';
import 'ventana.dart';

/// Boton de una accion sobre un registro (va arriba, en la cabecera del modal del registro).
class AccionRegistro {
  final String texto;
  final IconData icono;
  final TonoBoton tono;

  /// null = se ve deshabilitado (con [motivo] como ayuda, si hay).
  final VoidCallback? alPresionar;
  final String? motivo;

  const AccionRegistro({
    required this.texto,
    required this.icono,
    required this.tono,
    required this.alPresionar,
    this.motivo,
  });
}

/// Cierra el modal en el que se construyo (aunque haya otra ventana encima). Las acciones de un
/// registro lo usan cuando ya no tiene sentido seguir viendolo (por ejemplo despues de eliminarlo).
class CierreModal {
  Route<dynamic>? _ruta;

  /// Lo llama el modal al construirse.
  void recordar(BuildContext contexto) => _ruta ??= ModalRoute.of(contexto);

  void cerrar() {
    final ruta = _ruta;
    if (ruta != null && ruta.isActive) ruta.navigator?.removeRoute(ruta);
  }
}

/// Estado de la edicion en el mismo lugar de un registro: el boton Editar de la cabecera lo pone en
/// modo edicion (los datos pasan de texto plano a campos hundidos) y Guardar cambios llama a lo que
/// vinculo la ficha del registro con [vincular].
class ControlEdicion extends ChangeNotifier {
  bool _editando = false;
  bool _guardando = false;
  String? _error;
  Map<String, String> _erroresCampos = const {};

  Future<bool> Function()? _guardar;
  VoidCallback? _descartar;
  bool Function()? _hayCambios;

  bool get editando => _editando;
  bool get guardando => _guardando;
  String? get error => _error;
  Map<String, String> get erroresCampos => _erroresCampos;

  /// Hasta que la ficha cargue sus datos no se puede editar.
  bool get disponible => _guardar != null;

  /// [guardar] valida, confirma y envia; devuelve true si se guardo. [descartar] vuelve los campos a
  /// los datos de antes. [hayCambios] dice si se escribio algo (para avisar al cerrar).
  void vincular({
    required Future<bool> Function() guardar,
    required VoidCallback descartar,
    bool Function()? hayCambios,
  }) {
    _guardar = guardar;
    _descartar = descartar;
    _hayCambios = hayCambios;
    notifyListeners();
  }

  void desvincular() {
    _guardar = null;
    _descartar = null;
    _hayCambios = null;
  }

  bool get hayCambios => _editando && (_hayCambios?.call() ?? true);

  void editar() {
    if (!disponible || _editando) return;
    _editando = true;
    _error = null;
    _erroresCampos = const {};
    notifyListeners();
  }

  void cancelar() {
    _descartar?.call();
    _editando = false;
    _error = null;
    _erroresCampos = const {};
    notifyListeners();
  }

  Future<void> guardar() async {
    final guardar = _guardar;
    if (guardar == null || _guardando) return;
    _guardando = true;
    _error = null;
    _erroresCampos = const {};
    notifyListeners();
    try {
      if (await guardar()) _editando = false;
    } on ApiExcepcion catch (e) {
      _error = e.mensaje;
      _erroresCampos = e.errores;
    } catch (e) {
      _error = '$e';
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }
}

/// Abre el modal de un registro y, al cerrarse, libera su [ModalRegistro.edicion].
Future<void> abrirRegistro(BuildContext context, ModalRegistro modal, {double anchoMaximo = 820}) async {
  await mostrarVentana<void>(
    context,
    anchoMaximo: anchoMaximo,
    altoMaximo: 0.92,
    // Con la edicion abierta un toque fuera no debe perder lo escrito: se cierra con la X.
    cierraAlTocarFuera: modal.edicion == null,
    builder: (_) => modal,
  );
  modal.edicion?.dispose();
}

/// Modal de un registro: todos sus datos y, arriba, sus acciones. Con [edicion] aparece Editar: los
/// datos de [contenido] se vuelven editables ahi mismo y Editar pasa a Guardar cambios / Cancelar.
class ModalRegistro extends StatefulWidget {
  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final Widget? insignia;
  final List<AccionRegistro> acciones;
  final ControlEdicion? edicion;
  final CierreModal? cierre;
  final Widget Function(BuildContext context, bool editando) contenido;

  /// Pie opcional (debajo del contenido). Normalmente vacio: los botones van arriba.
  final List<Widget> pie;

  const ModalRegistro({
    super.key,
    required this.icono,
    required this.titulo,
    this.subtitulo,
    this.insignia,
    this.acciones = const [],
    this.edicion,
    this.cierre,
    required this.contenido,
    this.pie = const [],
  });

  @override
  State<ModalRegistro> createState() => _ModalRegistroState();
}

class _ModalRegistroState extends State<ModalRegistro> {
  final _desplazamiento = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.edicion?.addListener(_alCambiar);
  }

  @override
  void dispose() {
    widget.edicion?.removeListener(_alCambiar);
    _desplazamiento.dispose();
    super.dispose();
  }

  void _alCambiar() {
    if (!mounted) return;
    setState(() {});
    // Un error del servidor al guardar se muestra arriba del contenido: se sube para verlo.
    if (widget.edicion?.error != null && _desplazamiento.hasClients) {
      _desplazamiento.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Future<void> _cerrar() async {
    if (await puedeCerrarEdicion(context, widget.edicion) && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final movil = Pantalla.esMovil(context);
    final edicion = widget.edicion;
    final editando = edicion?.editando ?? false;
    widget.cierre?.recordar(context);
    return PopScope(
      canPop: !(edicion?.hayCambios ?? false) && !(edicion?.guardando ?? false),
      onPopInvokedWithResult: (cerrado, _) {
        if (!cerrado) _cerrar();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CabeceraVentana(
            icono: widget.icono,
            titulo: widget.titulo,
            subtitulo: editando ? 'Modo edición' : widget.subtitulo,
            insignia: widget.insignia,
            botones: [BotonesRegistro(edicion: edicion, acciones: widget.acciones)],
            alCerrar: _cerrar,
          ),
          Flexible(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  // Fondo gris claro: las secciones blancas resaltan levantadas sobre el.
                  colors: [Color(0xFFEDF0F4), Color(0xFFE5E9EF)],
                ),
              ),
              child: SingleChildScrollView(
                controller: _desplazamiento,
                padding: EdgeInsets.all(movil ? 14 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (edicion?.error != null) ...[
                      AlertaRelieve.error(
                        titulo: edicion!.error!,
                        texto: edicion.erroresCampos.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    widget.contenido(context, editando),
                  ],
                ),
              ),
            ),
          ),
          if (widget.pie.isNotEmpty) PieVentana(children: widget.pie),
        ],
      ),
    );
  }
}

/// Antes de cerrar un registro en edicion: si se escribio algo pregunta si se descarta. Devuelve si
/// se puede cerrar.
Future<bool> puedeCerrarEdicion(BuildContext context, ControlEdicion? edicion) async {
  if (edicion == null) return true;
  if (edicion.guardando) return false;
  if (!edicion.hayCambios) {
    if (edicion.editando) edicion.cancelar();
    return true;
  }
  final descartar = await confirmarAccion(
    context,
    titulo: '¿Descartar los cambios?',
    mensaje: 'Todavía no guardó lo que editó. Si cierra, se pierde.',
    textoConfirmar: 'Sí, descartar',
    tono: TonoBoton.rojo,
  );
  if (descartar) edicion.cancelar();
  return descartar;
}

/// Botones de la cabecera de un registro: Editar (si hay [edicion]) y las [acciones]; en edicion,
/// Guardar cambios y Cancelar. [antesDeEditar] se llama al tocar Editar (por ejemplo para pasar a la
/// pestana de los datos).
class BotonesRegistro extends StatelessWidget {
  final ControlEdicion? edicion;
  final List<AccionRegistro> acciones;
  final VoidCallback? antesDeEditar;

  const BotonesRegistro({super.key, this.edicion, this.acciones = const [], this.antesDeEditar});

  @override
  Widget build(BuildContext context) {
    final edicion = this.edicion;
    if (edicion == null) return _fila(context, null);
    return ListenableBuilder(listenable: edicion, builder: (context, _) => _fila(context, edicion));
  }

  Widget _fila(BuildContext context, ControlEdicion? edicion) {
    final tamano = Pantalla.esMovil(context) ? TamanoBoton.pequeno : TamanoBoton.normal;
    final List<Widget> botones;
    if (edicion != null && edicion.editando) {
      botones = [
        BotonRelieve(
          texto: 'Guardar cambios',
          icono: Iconos.floppyDisk,
          tono: TonoBoton.verde,
          tamano: tamano,
          cargando: edicion.guardando,
          alPresionar: edicion.guardar,
        ),
        BotonRelieve(
          texto: 'Cancelar',
          icono: Iconos.xmark,
          tamano: tamano,
          alPresionar: edicion.guardando ? null : edicion.cancelar,
        ),
      ];
    } else {
      botones = [
        if (edicion != null)
          BotonRelieve(
            texto: 'Editar',
            icono: Iconos.penToSquare,
            tono: TonoBoton.azul,
            tamano: tamano,
            alPresionar: edicion.disponible
                ? () {
                    antesDeEditar?.call();
                    edicion.editar();
                  }
                : null,
          ),
        for (final accion in acciones)
          BotonRelieve(
            texto: accion.texto,
            icono: accion.icono,
            tono: accion.tono,
            tamano: tamano,
            ayuda: accion.alPresionar == null ? accion.motivo : null,
            alPresionar: accion.alPresionar,
          ),
      ];
    }
    return Wrap(spacing: 8, runSpacing: 8, children: botones);
  }
}

/// Seccion con titulo dentro del modal de un registro (Datos personales, Cuenta, Licencia...).
class SeccionRegistro extends StatelessWidget {
  final String titulo;
  final IconData? icono;
  final Widget child;
  final Widget? accion;

  const SeccionRegistro({super.key, required this.titulo, this.icono, required this.child, this.accion});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: Relieve.tarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icono != null) ...[Icon(icono, size: 15, color: ColoresApp.rojo), const SizedBox(width: 8)],
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
