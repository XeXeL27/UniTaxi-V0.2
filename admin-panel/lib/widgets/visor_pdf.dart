import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../core/iconos.dart';
import 'package:web/web.dart' as web;

import '../core/tema.dart';
import 'archivos_web.dart';

/// Muestra un PDF dentro de un modal (visor del navegador en un iframe), con botones para
/// descargarlo o abrirlo en otra pestana.
Future<void> mostrarPdf(
  BuildContext context, {
  required String titulo,
  required Future<Uint8List> Function() cargar,
  required String nombreDescarga,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _VisorPdf(titulo: titulo, cargar: cargar, nombreDescarga: nombreDescarga),
  );
}

class _VisorPdf extends StatefulWidget {
  final String titulo;
  final Future<Uint8List> Function() cargar;
  final String nombreDescarga;

  const _VisorPdf({required this.titulo, required this.cargar, required this.nombreDescarga});

  @override
  State<_VisorPdf> createState() => _VisorPdfState();
}

class _VisorPdfState extends State<_VisorPdf> {
  Uint8List? _bytes;
  String? _url;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final bytes = await widget.cargar();
      final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'application/pdf'));
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _url = web.URL.createObjectURL(blob);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    final url = _url;
    if (url != null) web.URL.revokeObjectURL(url);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tamano = MediaQuery.sizeOf(context);
    final url = _url;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiosApp.tarjeta)),
      child: SizedBox(
        width: tamano.width * 0.9 > 1000 ? 1000 : tamano.width * 0.9,
        height: tamano.height * 0.88,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ColoresApp.rojo, width: 3))),
              child: Row(
                children: [
                  const Icon(Iconos.filePdf, color: ColoresApp.rojo, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.titulo,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: ColoresApp.azul),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Descargar',
                    onPressed: _bytes == null
                        ? null
                        : () => descargarArchivo(_bytes!, widget.nombreDescarga, 'application/pdf'),
                    icon: const Icon(Iconos.download, size: 16),
                  ),
                  IconButton(
                    tooltip: 'Abrir en otra pestaña',
                    onPressed: _bytes == null ? null : () => abrirPdf(_bytes!),
                    icon: const Icon(Iconos.upRightFromSquare, size: 16),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Iconos.xmark, size: 18),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: ColoresApp.rojo)))
                  : url == null
                  ? const Center(child: CircularProgressIndicator(color: ColoresApp.azul))
                  : HtmlElementView.fromTagName(
                      tagName: 'iframe',
                      onElementCreated: (elemento) {
                        final iframe = elemento as web.HTMLIFrameElement;
                        iframe.src = url;
                        iframe.style
                          ..border = 'none'
                          ..width = '100%'
                          ..height = '100%';
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
