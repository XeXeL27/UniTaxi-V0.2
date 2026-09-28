import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Visor de PDF en el navegador (solo para probar la app en Chrome): el visor propio del
/// navegador dentro de un iframe.
class CuerpoPdf extends StatefulWidget {
  final Uint8List bytes;

  const CuerpoPdf({super.key, required this.bytes});

  @override
  State<CuerpoPdf> createState() => _CuerpoPdfState();
}

class _CuerpoPdfState extends State<CuerpoPdf> {
  late final String _url = web.URL.createObjectURL(
    web.Blob([widget.bytes.toJS].toJS, web.BlobPropertyBag(type: 'application/pdf')),
  );

  @override
  void dispose() {
    web.URL.revokeObjectURL(_url);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: (elemento) {
        final iframe = elemento as web.HTMLIFrameElement;
        iframe.src = _url;
        iframe.style
          ..border = 'none'
          ..width = '100%'
          ..height = '100%';
      },
    );
  }
}
