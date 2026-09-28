import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_excepcion.dart';
import '../core/tema.dart';
import 'dialogos.dart';

/// Circulo con la foto de perfil, o las iniciales si no hay foto. La foto llega cuadrada del
/// servidor, asi que llena el circulo sin deformarse.
class AvatarFoto extends StatelessWidget {
  final String nombre;
  final Uint8List? foto;
  final double radio;
  final Color color;

  const AvatarFoto({super.key, required this.nombre, this.foto, this.radio = 26, this.color = ColoresApp.rojo});

  @override
  Widget build(BuildContext context) {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final iniciales = partes.take(2).map((p) => p[0].toUpperCase()).join();
    return CircleAvatar(
      radius: radio,
      backgroundColor: color,
      foregroundImage: foto == null ? null : MemoryImage(foto!),
      child: Text(
        iniciales,
        style: TextStyle(color: ColoresApp.blanco, fontSize: radio * 0.65, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Foto de perfil con el boton de la camara para cambiarla (galeria o camara).
class FotoPerfilEditable extends StatefulWidget {
  final String nombre;
  final Uint8List? foto;

  /// Sube los bytes elegidos; al terminar la pantalla vuelve a cargar la foto.
  final Future<void> Function(Uint8List bytes, String nombreArchivo) subir;

  const FotoPerfilEditable({super.key, required this.nombre, required this.foto, required this.subir});

  @override
  State<FotoPerfilEditable> createState() => _FotoPerfilEditableState();
}

class _FotoPerfilEditableState extends State<FotoPerfilEditable> {
  bool _subiendo = false;

  Future<void> _elegir() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: ColoresApp.blanco,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.image, color: ColoresApp.azul),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.camera, color: ColoresApp.azul),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (origen == null) return;
    // Se reduce en el telefono (y se corrige la orientacion) antes de subir; el servidor la recorta.
    final elegida = await ImagePicker().pickImage(source: origen, maxWidth: 1280, maxHeight: 1280, imageQuality: 88);
    if (elegida == null || !mounted) return;
    setState(() => _subiendo = true);
    try {
      await widget.subir(await elegida.readAsBytes(), elegida.name);
      if (!mounted) return;
      setState(() => _subiendo = false);
      await mostrarExito(context, titulo: '¡Foto actualizada!', mensaje: 'Tu nueva foto de perfil ya se ve en la app.');
    } on ApiExcepcion catch (e) {
      if (!mounted) return;
      setState(() => _subiendo = false);
      await mostrarErrorDialogo(context, mensaje: e.mensaje);
    } finally {
      if (mounted && _subiendo) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(color: ColoresApp.blanco, shape: BoxShape.circle),
          child: AvatarFoto(nombre: widget.nombre, foto: widget.foto, radio: 56),
        ),
        if (_subiendo)
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator(color: ColoresApp.blanco)),
          ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Material(
            color: ColoresApp.rojo,
            shape: const CircleBorder(side: BorderSide(color: ColoresApp.blanco, width: 3)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _subiendo ? null : _elegir,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Center(child: FaIcon(FontAwesomeIcons.camera, color: ColoresApp.blanco, size: 16)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
