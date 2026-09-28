import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/api_excepcion.dart';
import '../../../core/cliente_api.dart';
import '../../../core/formato.dart';
import '../../../core/tema.dart';
import '../../../widgets/dialogos.dart';
import '../../../widgets/visor_pdf.dart';
import 'documentos_api.dart';

/// Documentos del conductor: los puede ver siempre (en un modal) y reemplazar el PDF solo si el
/// administrador le dio permiso para ese documento.
class PantallaDocumentos extends StatefulWidget {
  const PantallaDocumentos({super.key});

  @override
  State<PantallaDocumentos> createState() => _PantallaDocumentosState();
}

class _PantallaDocumentosState extends State<PantallaDocumentos> {
  late final DocumentosApi _api = DocumentosApi(context.read<ClienteApi>());
  late Future<(List<DocumentoPropio>, List<PermisoVigente>)> _datos = _cargar();
  int? _subiendo;

  Future<(List<DocumentoPropio>, List<PermisoVigente>)> _cargar() async {
    final resultados = await Future.wait([_api.documentos(), _api.permisos()]);
    return (resultados[0] as List<DocumentoPropio>, resultados[1] as List<PermisoVigente>);
  }

  Future<void> _reemplazar(DocumentoPropio documento) async {
    final archivo = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);
    if (archivo == null || !mounted) return;
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Enviar el nuevo PDF?',
      mensaje: 'Vas a reemplazar tu ${documento.nombre} por "${archivo.name}". Quedará pendiente de revisión.',
      textoConfirmar: 'Sí, enviar',
    );
    if (!confirmado || !mounted) return;
    setState(() => _subiendo = documento.id);
    try {
      await _api.reemplazarPdf(documento.id, await archivo.readAsBytes(), archivo.name);
      if (!mounted) return;
      setState(() => _datos = _cargar());
      await mostrarExito(
        context,
        titulo: '¡Documento enviado!',
        mensaje: 'Tu ${documento.nombre} quedó pendiente de revisión por la administración.',
      );
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    } finally {
      if (mounted) setState(() => _subiendo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColoresApp.azul,
        foregroundColor: ColoresApp.blanco,
        title: const Text('Mis documentos', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: FutureBuilder<(List<DocumentoPropio>, List<PermisoVigente>)>(
        future: _datos,
        builder: (context, instantanea) {
          if (instantanea.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => setState(() => _datos = _cargar()),
                child: Text('${instantanea.error}. Toca para reintentar'),
              ),
            );
          }
          final datos = instantanea.data;
          if (datos == null) return const Center(child: CircularProgressIndicator(color: ColoresApp.azul));
          final (documentos, permisos) = datos;
          final permitidos = {for (final p in permisos) if (!p.esDatos && p.idDocumento != null) p.idDocumento!: p};
          return RefreshIndicator(
            onRefresh: () async => setState(() => _datos = _cargar()),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  permitidos.isEmpty
                      ? 'Puedes ver tus documentos. Para cambiar alguno, pide permiso a la administración.'
                      : 'Tienes permiso para reemplazar ${permitidos.length == 1 ? 'un documento' : '${permitidos.length} documentos'}.',
                  style: const TextStyle(color: ColoresApp.textoSuave),
                ),
                const SizedBox(height: 12),
                if (documentos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Text('No tienes documentos registrados.', textAlign: TextAlign.center),
                  ),
                for (final d in documentos)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ColoresApp.blanco,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: permitidos.containsKey(d.id) ? ColoresApp.exito : ColoresApp.borde),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const FaIcon(FontAwesomeIcons.filePdf, color: ColoresApp.rojo, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d.nombre, style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700)),
                                  Text(
                                    d.vencimiento == null
                                        ? 'Sin vencimiento'
                                        : 'Vence el ${formatoFechaHora(d.vencimiento).split(' ').first}',
                                    style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            _Situacion(d.situacion),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => mostrarPdf(context, titulo: d.nombre, cargar: () => _api.pdf(d.id)),
                                icon: const FaIcon(FontAwesomeIcons.eye, size: 14),
                                label: const Text('Ver'),
                              ),
                            ),
                            if (permitidos.containsKey(d.id)) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _subiendo == null ? () => _reemplazar(d) : null,
                                  style: FilledButton.styleFrom(backgroundColor: ColoresApp.exito),
                                  icon: _subiendo == d.id
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: ColoresApp.blanco),
                                        )
                                      : const FaIcon(FontAwesomeIcons.fileArrowUp, size: 14),
                                  label: const Text('Reemplazar'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Situacion extends StatelessWidget {
  final String situacion;

  const _Situacion(this.situacion);

  @override
  Widget build(BuildContext context) {
    final (texto, color) = switch (situacion) {
      'APROBADO' => ('Aprobado', ColoresApp.exito),
      'RECHAZADO' => ('Rechazado', ColoresApp.rojo),
      _ => ('Pendiente', const Color(0xFFFD7E14)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
