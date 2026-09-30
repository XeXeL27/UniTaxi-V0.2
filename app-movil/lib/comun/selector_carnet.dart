import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../core/carnet/lectura_carnet.dart';
import '../core/carnet/ocr_carnet.dart';
import '../core/tema.dart';

/// Fotos del carnet elegidas y lo que se leyo de ellas.
class SeleccionCarnet {
  final Uint8List? anverso;
  final Uint8List? reverso;

  /// Datos leidos de las dos fotos; null mientras falte una o si no hay lector (web).
  final DatosCarnet? datos;

  const SeleccionCarnet({this.anverso, this.reverso, this.datos});

  bool get completa => anverso != null && reverso != null;
}

enum _Lado { anverso, reverso }

/// Dos recuadros (anverso y reverso) para tomar con la camara o cargar de la galeria la foto del
/// carnet. En el APK cada foto se lee en el telefono en cualquier posicion (derecha, de cabeza o de
/// costado) y solo se acepta si es un carnet boliviano del lado que corresponde; con las dos se
/// sacan el CI, el complemento y la fecha de nacimiento.
class SelectorCarnet extends StatefulWidget {
  final ValueChanged<SeleccionCarnet> onCambio;

  const SelectorCarnet({super.key, required this.onCambio});

  @override
  State<SelectorCarnet> createState() => _SelectorCarnetState();
}

class _SelectorCarnetState extends State<SelectorCarnet> {
  final Map<_Lado, Uint8List> _fotos = {};
  final Map<_Lado, String> _textos = {};
  final Map<_Lado, String> _errores = {};
  _Lado? _leyendo;

  Future<void> _elegir(_Lado lado) async {
    if (_leyendo != null) return;
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.camera, color: ColoresApp.tinta),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.image, color: ColoresApp.tinta),
              title: const Text('Cargar de la galería'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (origen == null) return;
    final elegida = await ImagePicker().pickImage(source: origen, maxWidth: 2000, maxHeight: 2000, imageQuality: 92);
    if (elegida == null || !mounted) return;
    final bytes = await elegida.readAsBytes();
    if (!mounted) return;

    if (!OcrCarnet.disponible) {
      // Web: no se puede leer la foto; los datos se escriben a mano.
      setState(() {
        _fotos[lado] = bytes;
        _errores.remove(lado);
      });
      _avisar();
      return;
    }

    setState(() {
      _leyendo = lado;
      _errores.remove(lado);
    });
    String? texto;
    String? fallo;
    try {
      texto = await OcrCarnet.leer(bytes, lado == _Lado.anverso ? pareceAnverso : pareceReverso);
    } catch (e) {
      // Un error del lector no es lo mismo que una foto que no es un carnet: se dice aparte.
      fallo = 'No se pudo leer la foto en este teléfono. Intenta de nuevo o con otra foto.';
    }
    if (!mounted) return;
    setState(() {
      _leyendo = null;
      if (fallo != null) {
        _fotos.remove(lado);
        _textos.remove(lado);
        _errores[lado] = fallo;
      } else if (texto == null) {
        _fotos.remove(lado);
        _textos.remove(lado);
        _errores[lado] = lado == _Lado.anverso
            ? 'Esta foto no es el anverso de un carnet de identidad (el lado con tu foto y el número). '
                  'Tómala de frente, con buena luz y que se lea todo el carnet.'
            : 'Esta foto no es el reverso de un carnet de identidad. Tómala de frente, con buena luz y que '
                  'se lea todo el carnet.';
      } else {
        _fotos[lado] = bytes;
        _textos[lado] = texto;
      }
    });
    _avisar();
  }

  void _avisar() {
    final anverso = _textos[_Lado.anverso];
    final reverso = _textos[_Lado.reverso];
    widget.onCambio(SeleccionCarnet(
      anverso: _fotos[_Lado.anverso],
      reverso: _fotos[_Lado.reverso],
      datos: anverso != null && reverso != null ? extraerDatosCarnet(anverso, reverso) : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _ranura(_Lado.anverso, 'Anverso', 'Lado con tu foto')),
            const SizedBox(width: 12),
            Expanded(child: _ranura(_Lado.reverso, 'Reverso', 'Lado de atrás')),
          ],
        ),
        for (final lado in _Lado.values)
          if (_errores[lado] != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: FaIcon(FontAwesomeIcons.circleExclamation, color: ColoresApp.rojo, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errores[lado]!, style: const TextStyle(color: ColoresApp.rojo, fontSize: 13)),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _ranura(_Lado lado, String titulo, String ayuda) {
    final foto = _fotos[lado];
    final leyendo = _leyendo == lado;
    return Material(
      color: ColoresApp.gris,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: leyendo ? null : () => _elegir(lado),
        child: AspectRatio(
          aspectRatio: 1.45,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (foto != null)
                Image.memory(foto, fit: BoxFit.cover, gaplessPlayback: true)
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const FaIcon(FontAwesomeIcons.idCard, color: ColoresApp.tinta, size: 26),
                    const SizedBox(height: 8),
                    Text(titulo, style: const TextStyle(color: ColoresApp.tinta, fontWeight: FontWeight.w700)),
                    Text(ayuda, style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 12)),
                  ],
                ),
              if (foto != null)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: ColoresApp.tinta, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(FontAwesomeIcons.check, color: ColoresApp.blanco, size: 11),
                        const SizedBox(width: 5),
                        Text(titulo, style: const TextStyle(color: ColoresApp.blanco, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              if (leyendo)
                Container(
                  color: const Color(0xAA000000),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: ColoresApp.blanco, strokeWidth: 2.5)),
                      SizedBox(height: 8),
                      Text('Leyendo el carnet...', style: TextStyle(color: ColoresApp.blanco, fontSize: 12.5)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
