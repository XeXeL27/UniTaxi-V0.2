import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/iconos.dart';
import '../core/tema.dart';

/// Foto que tomo el repartidor al entregar el paquete (la persona con su paquete). Se carga del
/// servidor y, al tocarla, se ve en grande.
class FotoEntrega extends StatefulWidget {
  final Future<Uint8List?> Function() cargar;
  final double alto;

  const FotoEntrega({super.key, required this.cargar, this.alto = 180});

  @override
  State<FotoEntrega> createState() => _FotoEntregaState();
}

class _FotoEntregaState extends State<FotoEntrega> {
  late final Future<Uint8List?> _foto = widget.cargar();

  void _verGrande(Uint8List foto) {
    showDialog<void>(
      context: context,
      builder: (contexto) => Dialog(
        backgroundColor: ColoresApp.tinta,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(maxScale: 5, child: Center(child: Image.memory(foto))),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                onPressed: () => Navigator.of(contexto).pop(),
                tooltip: 'Cerrar',
                icon: const Icon(Iconos.xmark, color: ColoresApp.blanco),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
        future: _foto,
        builder: (context, estado) {
          if (estado.connectionState != ConnectionState.done) {
            return SizedBox(height: widget.alto, child: const Center(child: CircularProgressIndicator()));
          }
          final foto = estado.data;
          if (estado.hasError || foto == null) {
            return const Text('No se pudo cargar la foto de la entrega.', style: TextStyle(color: ColoresApp.textoSuave));
          }
          return GestureDetector(
            onTap: () => _verGrande(foto),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(foto, height: widget.alto, width: double.infinity, fit: BoxFit.cover),
            ),
          );
        },
      );
}
