import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../comun/confirmar_identidad.dart';
import '../../../comun/perfil_api.dart';
import '../../../comun/selector_carnet.dart';
import '../../../core/api_excepcion.dart';
import '../../../core/cliente_api.dart';
import '../../../core/formato.dart';
import '../../../core/tema.dart';
import '../../../widgets/dialogos.dart';
import '../../../widgets/visor_pdf.dart';
import 'documentos_api.dart';
import 'fotos_documento.dart';

/// Documentos del conductor: las fotos del carnet y de la licencia y los PDF. Los puede ver siempre
/// y cambiarlos solo si el administrador le dio permiso, confirmando con la huella o la contrasena.
/// El SOAT, si no lo envio al registrarse, lo agrega aqui.
class PantallaDocumentos extends StatefulWidget {
  const PantallaDocumentos({super.key});

  @override
  State<PantallaDocumentos> createState() => _PantallaDocumentosState();
}

class _PantallaDocumentosState extends State<PantallaDocumentos> {
  late final DocumentosApi _api = DocumentosApi(context.read<ClienteApi>());
  late Future<(List<DocumentoPropio>, List<PermisoVigente>, Perfil)> _datos = _cargar();
  int? _subiendo;

  /// Tipo del documento faltante que se esta subiendo.
  String? _agregando;

  Future<(List<DocumentoPropio>, List<PermisoVigente>, Perfil)> _cargar() async {
    final resultados = await Future.wait<Object>([
      _api.documentos(),
      _api.permisos(),
      PerfilApi(context.read<ClienteApi>()).perfil(),
    ]);
    return (resultados[0] as List<DocumentoPropio>, resultados[1] as List<PermisoVigente>, resultados[2] as Perfil);
  }

  Future<void> _cambiarFotos(DocumentoFoto documento, Perfil perfil) async {
    final cambiado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PantallaCambiarFotos(documento: documento, perfil: perfil)),
    );
    if (cambiado == true && mounted) setState(() => _datos = _cargar());
  }

  Future<void> _reemplazar(DocumentoPropio documento) async {
    final archivo = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);
    if (archivo == null || !mounted) return;
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Enviar el nuevo PDF?',
      mensaje: 'Vas a reemplazar tu ${_enFrase(documento.nombre)} por "${archivo.name}". Quedará pendiente de revisión.',
      textoConfirmar: 'Sí, enviar',
    );
    if (!confirmado || !mounted) return;
    final contrasena = await confirmarIdentidad(context, accion: 'reemplazar el documento');
    if (contrasena == null || !mounted) return;
    setState(() => _subiendo = documento.id);
    try {
      await _api.reemplazarPdf(documento.id, await archivo.readAsBytes(), archivo.name, contrasena);
      if (!mounted) return;
      setState(() => _datos = _cargar());
      await mostrarExito(
        context,
        titulo: '¡Documento enviado!',
        mensaje: 'Tu ${_enFrase(documento.nombre)} quedó pendiente de revisión por la administración.',
      );
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    } finally {
      if (mounted) setState(() => _subiendo = null);
    }
  }

  Future<void> _agregar(({String tipo, String nombre, bool obligatorio}) pedido) async {
    final archivo = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);
    if (archivo == null || !mounted) return;
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Enviar el documento?',
      mensaje: 'Vas a enviar "${archivo.name}" como tu ${_enFrase(pedido.nombre)}. Quedará pendiente de revisión.',
      textoConfirmar: 'Sí, enviar',
    );
    if (!confirmado || !mounted) return;
    setState(() => _agregando = pedido.tipo);
    try {
      await _api.agregar(pedido.tipo, await archivo.readAsBytes(), archivo.name);
      if (!mounted) return;
      setState(() => _datos = _cargar());
      await mostrarExito(
        context,
        titulo: '¡Documento enviado!',
        mensaje: 'Tu ${_enFrase(pedido.nombre)} quedó pendiente de revisión por la administración.',
      );
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    } finally {
      if (mounted) setState(() => _agregando = null);
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
      body: FutureBuilder<(List<DocumentoPropio>, List<PermisoVigente>, Perfil)>(
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
          final (documentos, permisos, perfil) = datos;
          final permitidos = {
            for (final p in permisos)
              if (!p.esDatos && p.idDocumento != null) p.idDocumento!: p,
          };
          final permisoCarnet = permisos.any((p) => p.esCarnet);
          final permisoLicencia = permisos.any((p) => p.esLicencia);
          final vence = perfil.licenciaVencimiento;
          final enviados = {for (final d in documentos) d.tipo};
          final faltan = documentosPedidos.where((p) => !enviados.contains(p.tipo)).toList();
          final obligatoriosFaltantes = faltan.where((p) => p.obligatorio).map((p) => p.nombre.toLowerCase()).toList();
          return RefreshIndicator(
            onRefresh: () async => setState(() => _datos = _cargar()),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TarjetaFotosDocumento(
                  documento: DocumentoFoto.carnet,
                  detalle: 'N° ${perfil.ciCompleto}',
                  tieneFotos: perfil.tieneFotosCarnet,
                  permitido: permisoCarnet,
                  alCambiar: () => _cambiarFotos(DocumentoFoto.carnet, perfil),
                ),
                TarjetaFotosDocumento(
                  documento: DocumentoFoto.licencia,
                  detalle: [
                    'N° ${perfil.numeroLicencia ?? ''}',
                    if ((perfil.categoriaLicencia ?? '').isNotEmpty) 'categoría ${perfil.categoriaLicencia}',
                    if (vence != null) 'vence el ${formatoFecha(vence)}',
                  ].join(', '),
                  tieneFotos: perfil.tieneFotosLicencia,
                  permitido: permisoLicencia,
                  alCambiar: () => _cambiarFotos(DocumentoFoto.licencia, perfil),
                ),
                if (!permisoCarnet && !permisoLicencia)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Text(
                      'Para cambiar las fotos de tu carnet o de tu licencia, pide permiso a la administración.',
                      style: TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
                    ),
                  ),
                if (documentos.isNotEmpty) ...[
                  Text(
                    permitidos.isEmpty
                        ? 'Puedes ver tus documentos. Para cambiar alguno, pide permiso a la administración.'
                        : 'Tienes permiso para reemplazar ${permitidos.length == 1 ? 'un documento' : '${permitidos.length} documentos'}.',
                    style: const TextStyle(color: ColoresApp.textoSuave),
                  ),
                  const SizedBox(height: 12),
                ],
                if (obligatoriosFaltantes.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ColoresApp.rojoSuave,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ColoresApp.rojo.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: FaIcon(FontAwesomeIcons.lock, color: ColoresApp.rojo, size: 15),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tu cuenta está bloqueada hasta que subas el PDF de: ${obligatoriosFaltantes.join(' y ')}.',
                            style: const TextStyle(
                              color: ColoresApp.rojoOscuro,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                for (final pedido in faltan)
                  _DocumentoFaltante(
                    nombre: pedido.nombre,
                    obligatorio: pedido.obligatorio,
                    subiendo: _agregando == pedido.tipo,
                    onAgregar: _agregando == null && _subiendo == null ? () => _agregar(pedido) : null,
                  ),
                if (documentos.isEmpty && faltan.isEmpty)
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
                                  Text(
                                    d.nombre,
                                    style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700),
                                  ),
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

/// Nombre del documento dentro de una frase: "tu carnet de identidad" (las siglas como SOAT quedan).
String _enFrase(String nombre) =>
    nombre.length > 1 && nombre[1] == nombre[1].toLowerCase() ? nombre[0].toLowerCase() + nombre.substring(1) : nombre;

/// Documento que pide el registro y el conductor todavia no envio: solo se puede agregar.
class _DocumentoFaltante extends StatelessWidget {
  final String nombre;
  final bool obligatorio;
  final bool subiendo;
  final VoidCallback? onAgregar;

  const _DocumentoFaltante({
    required this.nombre,
    required this.obligatorio,
    required this.subiendo,
    required this.onAgregar,
  });

  @override
  Widget build(BuildContext context) {
    final color = obligatorio ? ColoresApp.rojo : ColoresApp.textoSuave;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: obligatorio ? ColoresApp.rojo.withValues(alpha: 0.45) : ColoresApp.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FaIcon(FontAwesomeIcons.fileCircleExclamation, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700),
                    ),
                    const Text(
                      'Todavía no lo enviaste',
                      style: TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  obligatorio ? 'Obligatorio' : 'Opcional',
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onAgregar,
            style: FilledButton.styleFrom(backgroundColor: obligatorio ? ColoresApp.rojo : ColoresApp.azul),
            icon: subiendo
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: ColoresApp.blanco),
                  )
                : const FaIcon(FontAwesomeIcons.fileArrowUp, size: 14),
            label: const Text('Agregar PDF'),
          ),
        ],
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
      child: Text(
        texto,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
