import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// Visor de PDF para Android: paginas con zoom (pdfx usa el renderizador nativo).
class CuerpoPdf extends StatefulWidget {
  final Uint8List bytes;

  const CuerpoPdf({super.key, required this.bytes});

  @override
  State<CuerpoPdf> createState() => _CuerpoPdfState();
}

class _CuerpoPdfState extends State<CuerpoPdf> {
  late final PdfControllerPinch _controlador = PdfControllerPinch(document: PdfDocument.openData(widget.bytes));

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PdfViewPinch(controller: _controlador);
}
