import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/tema.dart';
import '../../widgets/dialogos.dart';
import 'sistema_api.dart';

/// Carpeta raiz donde se guardan los archivos subidos (PDF de conductores y fotos de perfil).
/// Cada persona tiene su carpeta dentro (personas/&lt;id&gt;_&lt;ci&gt;, con general/ y conductor/).
class PantallaCarpeta extends StatefulWidget {
  const PantallaCarpeta({super.key});

  @override
  State<PantallaCarpeta> createState() => _PantallaCarpetaState();
}

class _PantallaCarpetaState extends State<PantallaCarpeta> {
  late final SistemaApi _api = SistemaApi(context.read<ClienteApi>());
  late Future<CarpetaArchivos> _carpeta = _api.carpeta();
  bool _moviendo = false;

  Future<void> _cambiar(CarpetaArchivos actual) async {
    final elegida = await showDialog<String>(
      context: context,
      builder: (_) => _ExploradorCarpetas(api: _api, inicial: actual.ruta),
    );
    if (elegida == null || elegida == actual.ruta || !mounted) return;
    final confirmado = await confirmarAccion(
      context,
      mensaje: 'Va a usar "$elegida" como carpeta de archivos. Se moverán ahí los ${actual.cantidadArchivos} '
          'archivos (${actual.tamanoLegible}) que hoy están en "${actual.ruta}".',
      textoConfirmar: 'Sí, mover',
    );
    if (!confirmado || !mounted) return;
    setState(() => _moviendo = true);
    try {
      final nueva = await _api.cambiarCarpeta(elegida);
      if (!mounted) return;
      setState(() => _carpeta = Future.value(nueva));
      await mostrarExito(
        context,
        titulo: '¡Carpeta cambiada!',
        mensaje: 'Los archivos ahora se guardan en "${nueva.ruta}" (${nueva.cantidadArchivos} archivos).',
      );
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, titulo: 'No se pudo cambiar la carpeta', mensaje: e.mensaje);
    } finally {
      if (mounted) setState(() => _moviendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CarpetaArchivos>(
      future: _carpeta,
      builder: (context, instantanea) {
        final carpeta = instantanea.data;
        return Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ColoresApp.superficie,
                borderRadius: BorderRadius.circular(RadiosApp.tarjeta),
                border: Border.all(color: ColoresApp.borde),
              ),
              child: carpeta == null
                  ? (instantanea.hasError
                        ? Text('${instantanea.error}', style: const TextStyle(color: ColoresApp.rojo))
                        : const Center(child: CircularProgressIndicator()))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            FaIcon(FontAwesomeIcons.folderOpen, color: ColoresApp.rojo, size: 20),
                            SizedBox(width: 12),
                            Text(
                              'Carpeta de archivos',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ColoresApp.azul),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Aquí se guardan los PDF de los conductores y las fotos de perfil. En la base de datos solo '
                          'queda la ruta de cada archivo. Cada persona tiene su carpeta, con sus datos generales '
                          'separados de los del conductor.',
                          style: TextStyle(color: ColoresApp.textoSuave),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: ColoresApp.entrada,
                            borderRadius: BorderRadius.circular(RadiosApp.control),
                            border: Border.all(color: ColoresApp.borde),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                carpeta.ruta,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ColoresApp.texto),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${carpeta.cantidadArchivos} archivos, ${carpeta.tamanoLegible}',
                                style: const TextStyle(color: ColoresApp.textoSuave),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Estructura:  personas / <id>_<CI> / general  (foto de perfil)   y   '
                          'personas / <id>_<CI> / conductor / documentos  (PDF)',
                          style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _moviendo ? null : () => _cambiar(carpeta),
                          icon: _moviendo
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const FaIcon(FontAwesomeIcons.folderTree, size: 14),
                          label: Text(_moviendo ? 'Moviendo archivos...' : 'Cambiar carpeta'),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Explorador de las carpetas del servidor. Devuelve la ruta elegida.
class _ExploradorCarpetas extends StatefulWidget {
  final SistemaApi api;
  final String inicial;

  const _ExploradorCarpetas({required this.api, required this.inicial});

  @override
  State<_ExploradorCarpetas> createState() => _ExploradorCarpetasState();
}

class _ExploradorCarpetasState extends State<_ExploradorCarpetas> {
  ListadoCarpetas? _listado;
  String? _error;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _ir(widget.inicial);
  }

  Future<void> _ir(String? ruta, {Future<ListadoCarpetas> Function()? accion}) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final listado = await (accion?.call() ?? widget.api.listar(ruta));
      if (mounted) setState(() => _listado = listado);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _nuevaCarpeta() async {
    final actual = _listado;
    if (actual == null) return;
    final nombre = TextEditingController();
    final creado = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva carpeta'),
        content: TextField(
          controller: nombre,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre de la carpeta'),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(nombre.text.trim()), child: const Text('Crear')),
        ],
      ),
    );
    if (creado == null || creado.isEmpty) return;
    await _ir(null, accion: () => widget.api.crear(actual.ruta, creado));
  }

  @override
  Widget build(BuildContext context) {
    final listado = _listado;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiosApp.tarjeta)),
      child: SizedBox(
        width: 620,
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ColoresApp.rojo, width: 3))),
              child: Row(
                children: [
                  const FaIcon(FontAwesomeIcons.folderTree, color: ColoresApp.azul, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Elegir carpeta del servidor',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ColoresApp.azul),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Subir un nivel',
                    onPressed: listado?.padre == null || _cargando ? null : () => _ir(listado!.padre),
                    icon: const FaIcon(FontAwesomeIcons.arrowUp, size: 16),
                  ),
                  Expanded(
                    child: Text(
                      listado?.ruta ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: ColoresApp.texto),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: listado == null || _cargando ? null : _nuevaCarpeta,
                    icon: const FaIcon(FontAwesomeIcons.folderPlus, size: 14),
                    label: const Text('Nueva carpeta'),
                  ),
                ],
              ),
            ),
            if (_cargando) const LinearProgressIndicator(minHeight: 2, color: ColoresApp.rojo),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(_error!, style: const TextStyle(color: ColoresApp.rojo)),
              ),
            Expanded(
              child: listado == null
                  ? const SizedBox.shrink()
                  : listado.carpetas.isEmpty
                  ? const Center(child: Text('Esta carpeta no tiene subcarpetas.', style: TextStyle(color: ColoresApp.textoSuave)))
                  : ListView(
                      children: [
                        for (final (nombre, ruta) in listado.carpetas)
                          ListTile(
                            leading: const FaIcon(FontAwesomeIcons.solidFolder, color: Color(0xFFF5A623), size: 20),
                            title: Text(nombre),
                            onTap: _cargando ? null : () => _ir(ruta),
                          ),
                      ],
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: ColoresApp.borde))),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      listado == null
                          ? ''
                          : listado.escribible
                          ? 'Se usará la carpeta que está abierta.'
                          : 'No se puede escribir en esta carpeta.',
                      style: TextStyle(color: listado?.escribible == false ? ColoresApp.rojo : ColoresApp.textoSuave),
                    ),
                  ),
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: listado == null || !listado.escribible || _cargando
                        ? null
                        : () => Navigator.of(context).pop(listado.ruta),
                    icon: const FaIcon(FontAwesomeIcons.check, size: 14),
                    label: const Text('Usar esta carpeta'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
