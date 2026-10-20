import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_excepcion.dart';
import '../core/carnet/lector_documentos.dart';
import '../core/iconos.dart';
import '../core/tema.dart';
import 'selector_carnet.dart';

/// Foto de la persona con su carnet y, si la cuenta quedara en revision por ella, el motivo.
class SeleccionSelfie {
  final Uint8List? foto;
  final String? observacion;

  const SeleccionSelfie({this.foto, this.observacion});
}

/// Recuadro para la foto de la persona sosteniendo su carnet (lado de la foto) junto a su cara. Se toma
/// solo con la camara frontal (no de la galeria) y, con [revisarAlTomar], el servidor la revisa enseguida
/// comparandola con [anverso]: si no sirve (no se ve la cara, el reverso, otro carnet) se pide otra; si la
/// cara no se parece o el servidor no la pudo revisar, se acepta y la cuenta queda en revision.
class SelectorSelfieCarnet extends StatefulWidget {
  final ValueChanged<SeleccionSelfie> onCambio;

  /// Foto del anverso del carnet ya tomada; si cambia, la foto con el carnet se vuelve a revisar.
  final Uint8List? anverso;

  /// Sin [anverso] todavia no se puede tomar (registro: primero las fotos del carnet).
  final bool necesitaAnverso;
  final bool revisarAlTomar;

  /// Otra forma de revisar la foto (por ejemplo, contra el anverso ya guardado de la cuenta). Devuelve null
  /// si el servidor no pudo revisarla; lanza [ApiExcepcion] si la rechaza. Sin ella se usa
  /// LectorDocumentos.leerSelfie con [anverso].
  final Future<LecturaSelfie?> Function(Uint8List foto)? revisarCon;

  const SelectorSelfieCarnet({
    super.key,
    required this.onCambio,
    this.anverso,
    this.necesitaAnverso = true,
    this.revisarAlTomar = true,
    this.revisarCon,
  });

  @override
  State<SelectorSelfieCarnet> createState() => _SelectorSelfieCarnetState();
}

class _SelectorSelfieCarnetState extends State<SelectorSelfieCarnet> {
  Uint8List? _foto;
  String? _observacion;
  String? _error;
  bool _leyendo = false;

  @override
  void didUpdateWidget(covariant SelectorSelfieCarnet anterior) {
    super.didUpdateWidget(anterior);
    // Con otro anverso la revision anterior ya no vale (el servidor compara las dos fotos).
    if (!identical(anterior.anverso, widget.anverso) && _foto != null && widget.revisarAlTomar) {
      if (widget.anverso == null && widget.necesitaAnverso) {
        setState(() {
          _foto = null;
          _observacion = null;
        });
        _avisar();
      } else {
        _revisar(_foto!);
      }
    }
  }

  void _avisar() => widget.onCambio(SeleccionSelfie(foto: _foto, observacion: _observacion));

  Future<void> _elegir() async {
    if (_leyendo) return;
    if (widget.necesitaAnverso && widget.anverso == null) {
      setState(() => _error = 'Primero toma la foto del anverso de tu carnet.');
      return;
    }
    if (_foto != null) {
      final accion = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Iconos.magnifyingGlassPlus, color: ColoresApp.tinta),
                title: const Text('Ver la foto'),
                onTap: () => Navigator.of(context).pop(false),
              ),
              ListTile(
                leading: const Icon(Iconos.camera, color: ColoresApp.tinta),
                title: const Text('Tomar otra foto'),
                onTap: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (accion == null || !mounted) return;
      if (!accion) {
        await verFoto(context, _foto!, titulo: 'Tu foto con el carnet');
        return;
      }
    }
    final elegida = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 92,
    );
    if (elegida == null || !mounted) return;
    final bytes = await elegida.readAsBytes();
    if (!mounted) return;
    if (!widget.revisarAlTomar) {
      setState(() {
        _foto = bytes;
        _observacion = null;
        _error = null;
      });
      _avisar();
      return;
    }
    await _revisar(bytes);
  }

  Future<void> _revisar(Uint8List bytes) async {
    setState(() {
      _leyendo = true;
      _error = null;
    });
    LecturaSelfie? lectura;
    String? fallo;
    try {
      final revisarCon = widget.revisarCon;
      lectura = revisarCon != null
          ? await revisarCon(bytes)
          : await LectorDocumentos.leerSelfie(bytes, anverso: widget.anverso);
    } on ApiExcepcion catch (e) {
      fallo = e.mensaje;
    }
    if (!mounted) return;
    setState(() {
      _leyendo = false;
      if (fallo != null || (lectura != null && !lectura.aceptada)) {
        _foto = null;
        _observacion = null;
        _error = fallo ?? lectura?.motivo ?? 'Esta foto no sirve. Vuelve a tomarla.';
      } else {
        _foto = bytes;
        // Sin lectura del servidor la revisa un administrador.
        _observacion = lectura == null
            ? 'No pudimos revisar tu foto ahora: un administrador la revisará.'
            : lectura.observacion;
      }
    });
    _avisar();
  }

  @override
  Widget build(BuildContext context) {
    final foto = _foto;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: ColoresApp.gris,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _leyendo ? null : _elegir,
            child: AspectRatio(
              aspectRatio: 1.9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (foto != null)
                    Image.memory(foto, fit: BoxFit.cover, gaplessPlayback: true)
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Iconos.userCheck, color: ColoresApp.tinta, size: 26),
                          SizedBox(height: 8),
                          Text(
                            'Tu foto con el carnet',
                            style: TextStyle(color: ColoresApp.tinta, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Sostén tu carnet (el lado con tu foto) junto a tu cara. Deben verse tu cara y el '
                            'número del carnet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: ColoresApp.grisTexto, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  if (foto != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: ColoresApp.tinta, borderRadius: BorderRadius.circular(10)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Iconos.check, color: ColoresApp.blanco, size: 11),
                            SizedBox(width: 5),
                            Text(
                              'Foto con el carnet',
                              style: TextStyle(color: ColoresApp.blanco, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_leyendo)
                    Container(
                      color: const Color(0xAA000000),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(color: ColoresApp.blanco, strokeWidth: 2.5),
                          ),
                          SizedBox(height: 8),
                          Text('Revisando la foto...', style: TextStyle(color: ColoresApp.blanco, fontSize: 12.5)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_error != null) _aviso(_error!, ColoresApp.rojo),
        if (_error == null && _observacion != null)
          _aviso(
            'Tu cuenta quedará en revisión. ${_observacion!.endsWith('.') ? _observacion : '$_observacion.'} '
            'Si quieres, toma otra foto.',
            ColoresApp.rutaSecundariaBorde,
          ),
      ],
    );
  }

  Widget _aviso(String texto, Color color) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Iconos.circleExclamation, color: color, size: 14),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, style: TextStyle(color: color, fontSize: 13))),
      ],
    ),
  );
}
