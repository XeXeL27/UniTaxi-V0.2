import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/tema.dart';

/// Circulo con la foto de perfil de una cuenta; mientras carga o si no tiene, muestra las
/// iniciales. La foto ya viene cuadrada del servidor, asi que llena el circulo sin deformarse.
class FotoUsuario extends StatefulWidget {
  final String nombre;
  final double radio;
  final Color color;

  /// Carga los bytes de la foto (null si la cuenta no tiene).
  final Future<Uint8List?> Function()? cargar;

  const FotoUsuario({super.key, required this.nombre, this.radio = 28, this.cargar, this.color = ColoresApp.azul});

  @override
  State<FotoUsuario> createState() => _FotoUsuarioState();
}

class _FotoUsuarioState extends State<FotoUsuario> {
  Uint8List? _foto;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final cargar = widget.cargar;
    if (cargar == null) return;
    try {
      final foto = await cargar();
      if (mounted) setState(() => _foto = foto);
    } catch (_) {
      // Sin foto quedan las iniciales.
    }
  }

  @override
  Widget build(BuildContext context) {
    final partes = widget.nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final iniciales = partes.take(2).map((p) => p[0].toUpperCase()).join();
    final foto = _foto;
    return CircleAvatar(
      radius: widget.radio,
      backgroundColor: widget.color,
      foregroundImage: foto == null ? null : MemoryImage(foto),
      child: Text(
        iniciales,
        style: TextStyle(color: Colors.white, fontSize: widget.radio * 0.65, fontWeight: FontWeight.w700),
      ),
    );
  }
}
