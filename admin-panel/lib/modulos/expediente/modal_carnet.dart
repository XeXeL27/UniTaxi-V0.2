import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/api_excepcion.dart';
import '../../core/tema.dart';
import '../../widgets/archivos_web.dart';
import 'expediente_api.dart';

/// Fotos del carnet (anverso y reverso) de la persona de una cuenta, en un solo modal. Las sube la
/// persona desde la app al entrar con Google; solo el administrador puede verlas.
Future<void> mostrarCarnet(BuildContext context, {required ExpedienteApi api, required int idUsuario, required String nombre}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ModalCarnet(api: api, idUsuario: idUsuario, nombre: nombre),
  );
}

/// Boton "Ver carnet" para la cabecera de la seccion de datos personales del expediente.
class BotonVerCarnet extends StatelessWidget {
  final ExpedienteApi api;
  final int idUsuario;
  final String nombre;

  const BotonVerCarnet({super.key, required this.api, required this.idUsuario, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => mostrarCarnet(context, api: api, idUsuario: idUsuario, nombre: nombre),
      style: TextButton.styleFrom(foregroundColor: ColoresApp.azul),
      icon: const FaIcon(FontAwesomeIcons.idCard, size: 14),
      label: const Text('Ver carnet', style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _ModalCarnet extends StatelessWidget {
  final ExpedienteApi api;
  final int idUsuario;
  final String nombre;

  const _ModalCarnet({required this.api, required this.idUsuario, required this.nombre});

  @override
  Widget build(BuildContext context) {
    final tamano = MediaQuery.sizeOf(context);
    final angosto = tamano.width < 600;
    final lados = [
      _Lado(titulo: 'Anverso', cargar: () => api.carnet(idUsuario, 'anverso'), nombreDescarga: 'carnet_anverso.jpg'),
      _Lado(titulo: 'Reverso', cargar: () => api.carnet(idUsuario, 'reverso'), nombreDescarga: 'carnet_reverso.jpg'),
    ];
    final contenido = Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ColoresApp.rojo, width: 3))),
          child: Row(
            children: [
              const FaIcon(FontAwesomeIcons.idCard, color: ColoresApp.rojo, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Carnet de $nombre',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: ColoresApp.azul),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            // Lado a lado en pantallas anchas; uno debajo del otro en el celular.
            child: angosto
                ? ListView(children: [for (final l in lados) SizedBox(height: 300, child: l)])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: lados[0]),
                      const SizedBox(width: 16),
                      Expanded(child: lados[1]),
                    ],
                  ),
          ),
        ),
      ],
    );
    if (angosto) return Dialog.fullscreen(child: contenido);
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiosApp.tarjeta)),
      child: SizedBox(
        width: tamano.width * 0.9 > 1100 ? 1100 : tamano.width * 0.9,
        height: tamano.height * 0.8 > 560 ? 560 : tamano.height * 0.8,
        child: contenido,
      ),
    );
  }
}

class _Lado extends StatefulWidget {
  final String titulo;
  final Future<Uint8List> Function() cargar;
  final String nombreDescarga;

  const _Lado({required this.titulo, required this.cargar, required this.nombreDescarga});

  @override
  State<_Lado> createState() => _LadoState();
}

class _LadoState extends State<_Lado> {
  late final Future<Uint8List> _imagen = widget.cargar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ColoresApp.superficie,
        borderRadius: BorderRadius.circular(RadiosApp.control),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: FutureBuilder<Uint8List>(
        future: _imagen,
        builder: (context, instantanea) {
          final bytes = instantanea.data;
          final error = instantanea.error;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.titulo, style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azul)),
                  ),
                  IconButton(
                    tooltip: 'Descargar',
                    onPressed: bytes == null ? null : () => descargarArchivo(bytes, widget.nombreDescarga, 'image/jpeg'),
                    icon: const FaIcon(FontAwesomeIcons.download, size: 16, color: ColoresApp.azul),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: error != null
                    ? Center(
                        child: Text(
                          error is ApiExcepcion && error.codigo == 404
                              ? 'No registró la foto del ${widget.titulo.toLowerCase()} de su carnet'
                              : 'No se pudo cargar la imagen',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: ColoresApp.textoSuave),
                        ),
                      )
                    : bytes == null
                    ? const Center(child: CircularProgressIndicator(color: ColoresApp.azul))
                    : InteractiveViewer(maxScale: 4, child: Image.memory(bytes, fit: BoxFit.contain)),
              ),
            ],
          );
        },
      ),
    );
  }
}
