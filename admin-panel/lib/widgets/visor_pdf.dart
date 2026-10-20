import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/iconos.dart';

import 'package:web/web.dart' as web;

import '../core/relieve.dart';
import '../core/tema.dart';
import 'boton_relieve.dart';
import 'ventana.dart';
import 'archivos_web.dart';
import 'dialogo_animado.dart';

/// Muestra un PDF dentro de un modal (visor del navegador en un iframe), con botones para
/// descargarlo o abrirlo en otra pestana.
Future<void> mostrarPdf(
  BuildContext context, {
  required String titulo,
  required Future<Uint8List> Function() cargar,
  required String nombreDescarga,
}) {
  return mostrarDialogo<void>(
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
            CabeceraVentana(
              icono: Iconos.filePdf,
              titulo: widget.titulo,
              alCerrar: () => Navigator.of(context).pop(),
              botones: [
                BotonRelieve(
                  texto: 'Descargar',
                  icono: Iconos.download,
                  tono: TonoBoton.celeste,
                  tamano: TamanoBoton.pequeno,
                  alPresionar: _bytes == null
                      ? null
                      : () => descargarArchivo(_bytes!, widget.nombreDescarga, 'application/pdf'),
                ),
                BotonRelieve(
                  texto: 'Abrir en otra pestaña',
                  icono: Iconos.upRightFromSquare,
                  tamano: TamanoBoton.pequeno,
                  alPresionar: _bytes == null ? null : () => abrirPdf(_bytes!),
                ),
              ],
            ),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Text(_error!, style: const TextStyle(color: ColoresApp.rojo)),
                    )
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
