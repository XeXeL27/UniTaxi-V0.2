import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../core/iconos.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/tema.dart';
import '../../widgets/archivos_web.dart';
import '../../widgets/dialogos.dart';
import 'expediente_api.dart';

/// Fotos del carnet (anverso y reverso) de la persona de una cuenta, en un solo modal. Las sube la
/// persona desde la app; solo el administrador puede verlas y cambiarlas.
Future<void> mostrarCarnet(BuildContext context, {required ExpedienteApi api, required int idUsuario, required String nombre}) {
  return mostrarFotosDocumento(
    context,
    titulo: 'Carnet de $nombre',
    icono: Iconos.idCard,
    documento: 'carnet',
    cargar: (lado) => api.carnet(idUsuario, lado),
    cambiar: (lado, archivo) => api.cambiarCarnet(
      idUsuario,
      anverso: lado == 'anverso' ? archivo : null,
      reverso: lado == 'reverso' ? archivo : null,
    ),
  );
}

/// Fotos del anverso y del reverso de un documento (carnet o licencia). Con [cambiar] cada lado
/// tiene el boton "Cambiar foto".
Future<void> mostrarFotosDocumento(
  BuildContext context, {
  required String titulo,
  required IconData icono,
  required String documento,
  required Future<Uint8List> Function(String lado) cargar,
  Future<void> Function(String lado, ArchivoSubida archivo)? cambiar,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ModalCarnet(titulo: titulo, icono: icono, documento: documento, cargar: cargar, cambiar: cambiar),
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
      icon: const Icon(Iconos.idCard, size: 14),
      label: const Text('Ver carnet', style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _ModalCarnet extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final String documento;
  final Future<Uint8List> Function(String lado) cargar;
  final Future<void> Function(String lado, ArchivoSubida archivo)? cambiar;

  const _ModalCarnet({required this.titulo, required this.icono, required this.documento, required this.cargar, this.cambiar});

  @override
  Widget build(BuildContext context) {
    final tamano = MediaQuery.sizeOf(context);
    final angosto = tamano.width < 600;
    final lados = [
      for (final lado in const ['anverso', 'reverso'])
        _Lado(
          titulo: lado == 'anverso' ? 'Anverso' : 'Reverso',
          documento: documento,
          cargar: () => cargar(lado),
          nombreDescarga: '${documento}_$lado.jpg',
          cambiar: cambiar == null ? null : (archivo) => cambiar!(lado, archivo),
        ),
    ];
    final contenido = Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ColoresApp.rojo, width: 3))),
          child: Row(
            children: [
              Icon(icono, color: ColoresApp.rojo, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: ColoresApp.azul),
                ),
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
  final String documento;
  final Future<Uint8List> Function() cargar;
  final String nombreDescarga;
  final Future<void> Function(ArchivoSubida archivo)? cambiar;

  const _Lado({required this.titulo, required this.documento, required this.cargar, required this.nombreDescarga, this.cambiar});

  @override
  State<_Lado> createState() => _LadoState();
}

class _LadoState extends State<_Lado> {
  late Future<Uint8List> _imagen = widget.cargar();
  bool _subiendo = false;

  Future<void> _cambiar() async {
    final archivo = await seleccionarArchivo(aceptar: 'image/jpeg,image/png,.jpg,.jpeg,.png');
    if (archivo == null || !mounted) return;
    final confirmado = await confirmarAccion(
      context,
      mensaje: 'Va a cambiar la foto del ${widget.titulo.toLowerCase()} de${widget.documento == 'carnet' ? 'l carnet' : ' la licencia'} '
          'por "${archivo.nombre}".',
      textoConfirmar: 'Sí, cambiar',
    );
    if (!confirmado || !mounted) return;
    setState(() => _subiendo = true);
    try {
      await widget.cambiar!(archivo);
      if (!mounted) return;
      setState(() => _imagen = widget.cargar());
      await mostrarExito(context, titulo: '¡Foto cambiada!', mensaje: 'La foto del ${widget.titulo.toLowerCase()} se actualizó.');
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

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
                  if (widget.cambiar != null)
                    TextButton.icon(
                      onPressed: _subiendo ? null : _cambiar,
                      icon: _subiendo
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Iconos.camera, size: 14),
                      label: const Text('Cambiar foto'),
                    ),
                  IconButton(
                    tooltip: 'Descargar',
                    onPressed: bytes == null ? null : () => descargarArchivo(bytes, widget.nombreDescarga, 'image/jpeg'),
                    icon: const Icon(Iconos.download, size: 16, color: ColoresApp.azul),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: error != null
                    ? Center(
                        child: Text(
                          error is ApiExcepcion && error.codigo == 404
                              ? 'No registró la foto del ${widget.titulo.toLowerCase()} de su ${widget.documento}'
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

/// Boton "Ver licencia" para la seccion del conductor en el expediente.
class BotonVerLicencia extends StatelessWidget {
  final ExpedienteApi api;
  final int idConductor;
  final String nombre;

  const BotonVerLicencia({super.key, required this.api, required this.idConductor, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => mostrarFotosDocumento(
        context,
        titulo: 'Licencia de $nombre',
        icono: Iconos.solidIdBadge,
        documento: 'licencia',
        cargar: (lado) => api.licencia(idConductor, lado),
        cambiar: (lado, archivo) => api.cambiarFotoLicencia(idConductor, lado, archivo),
      ),
      style: TextButton.styleFrom(foregroundColor: ColoresApp.azul),
      icon: const Icon(Iconos.solidIdBadge, size: 14),
      label: const Text('Ver licencia', style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
