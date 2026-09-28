import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/tema.dart';
import 'cuerpo_pdf_movil.dart' if (dart.library.js_interop) 'cuerpo_pdf_web.dart';

/// Muestra un PDF en un cuadro modal sobre la pantalla.
Future<void> mostrarPdf(BuildContext context, {required String titulo, required Future<Uint8List?> Function() cargar}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _VisorPdf(titulo: titulo, cargar: cargar),
  );
}

class _VisorPdf extends StatefulWidget {
  final String titulo;
  final Future<Uint8List?> Function() cargar;

  const _VisorPdf({required this.titulo, required this.cargar});

  @override
  State<_VisorPdf> createState() => _VisorPdfState();
}

class _VisorPdfState extends State<_VisorPdf> {
  late final Future<Uint8List?> _bytes = widget.cargar();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: [
            Container(
              color: ColoresApp.azul,
              padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
              child: Row(
                children: [
                  const FaIcon(FontAwesomeIcons.filePdf, color: ColoresApp.blanco, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.titulo,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColoresApp.blanco, fontWeight: FontWeight.w600, fontSize: 15.5),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const FaIcon(FontAwesomeIcons.xmark, color: ColoresApp.blanco, size: 18),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<Uint8List?>(
                future: _bytes,
                builder: (context, instantanea) {
                  if (instantanea.hasError) {
                    return Center(child: Text('${instantanea.error}', style: const TextStyle(color: ColoresApp.rojo)));
                  }
                  if (instantanea.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(color: ColoresApp.azul));
                  }
                  final bytes = instantanea.data;
                  if (bytes == null) {
                    return const Center(child: Text('El archivo no está disponible.'));
                  }
                  return CuerpoPdf(bytes: bytes);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
