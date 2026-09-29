import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../widgets/archivos_web.dart';
import '../../widgets/dialogos.dart';
import '../../widgets/flujos_crud.dart';
import '../../widgets/insignia_estado.dart';
import '../../widgets/listado_remoto.dart';
import '../../widgets/modal_formulario.dart';
import '../../widgets/tabla/columna_tabla.dart';
import '../../widgets/visor_pdf.dart';
import '../expediente/expediente_api.dart';
import '../expediente/expediente_conductor.dart';
import '../expediente/vista_expediente.dart';
import 'acciones_cuenta.dart';
import 'formulario_habilitar_usuario.dart';
import 'modelos.dart';
import 'personas_api.dart';

const _situaciones = ['PENDIENTE', 'APROBADO', 'RECHAZADO', 'SUSPENDIDO'];

/// Conductores: alta (con moto y documentos PDF), documentos digitales y situacion de aprobacion.
class PantallaConductores extends StatelessWidget {
  const PantallaConductores({super.key});

  @override
  Widget build(BuildContext context) {
    final api = PersonasApi(context.read<ClienteApi>());
    final expedienteApi = ExpedienteApi(context.read<ClienteApi>());

    void verDocumentos(ConductorAdmin conductor) {
      showDialog<void>(
        context: context,
        builder: (_) => DialogoDocumentos(api: api, conductor: conductor),
      );
    }

    return ListadoRemoto<ConductorAdmin>(
      titulo: 'Conductores',
      icono: FontAwesomeIcons.carSide,
      nombreArchivo: 'conductores',
      cargar: api.listarConductores,
      columnas: [
        ColumnaTabla(titulo: 'Usuario', valor: (c) => c.nombreUsuario),
        ColumnaTabla(titulo: 'Conductor', valor: (c) => c.nombreCompleto, ancho: 150, proporcion: 2.5),
        ColumnaTabla(titulo: 'CI', valor: (c) => c.ci, ancho: 80, proporcion: 1.1),
        ColumnaTabla(titulo: 'Teléfono', valor: (c) => c.telefono, ancho: 100, proporcion: 1.4),
        ColumnaTabla(titulo: 'Licencia', valor: (c) => c.numeroLicencia, ancho: 95, proporcion: 1.4),
        ColumnaTabla(titulo: 'Placa', valor: (c) => c.placa, ancho: 85, proporcion: 1.2),
        ColumnaTabla(
          titulo: 'Situación',
          tipo: TipoColumna.estado,
          opciones: _situaciones,
          valor: (c) => c.situacionAprobacion,
        ),
        ColumnaTabla(
          titulo: 'Documentos',
          tipo: TipoColumna.numero,
          valor: (c) => c.cantidadDocumentos,
          ancho: 130,
          proporcion: 1.4,
          celda: (c) => Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: c.cantidadDocumentos == 0 ? null : () => verDocumentos(c),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
              icon: FaIcon(
                FontAwesomeIcons.filePdf,
                size: 16,
                color: c.cantidadDocumentos == 0 ? Colors.black26 : ColoresApp.rojo,
              ),
              label: Text(c.cantidadDocumentos == 0 ? 'Sin PDF' : 'Ver (${c.cantidadDocumentos})'),
            ),
          ),
        ),
      ],
      alVer: (conductor, recargar) => abrirExpediente(
        context,
        ExpedienteConductor(api: expedienteApi, personasApi: api, conductor: conductor, alCambiar: recargar),
      ),
      acciones: (recargar) => [
        FilledButton.icon(
          onPressed: () => flujoCrear(
            context,
            formulario: FormularioHabilitarUsuario(
              api: api,
              titulo: 'Agregar conductor',
              tiposPermitidos: const [TipoRegistro.conductor, TipoRegistro.ambos],
            ),
            tituloExito: '¡Conductor registrado!',
            mensajeExito: (resultado) => '${(resultado as UsuarioHabilitado).mensaje} Queda pendiente de aprobación.',
            alTerminar: recargar,
          ),
          icon: const FaIcon(FontAwesomeIcons.motorcycle, size: 14),
          label: const Text('Agregar conductor'),
        ),
      ],
      accionesFila: (conductor, recargar) => [
        IconButton(
          tooltip: 'Cambiar situación',
          onPressed: () => flujoEditar(
            context,
            descripcion: 'la situación de ${conductor.nombreCompleto}',
            formulario: FormularioSituacionConductor(api: api, conductor: conductor),
            mensajeExito: 'Se actualizó la situación de ${conductor.nombreCompleto}.',
            alTerminar: recargar,
          ),
          icon: const FaIcon(FontAwesomeIcons.userCheck, size: 16, color: Color(0xFF198754)),
        ),
        // La suspension del conductor es su situacion (arriba); eliminar da de baja su cuenta.
        if (conductor.idUsuario != null)
          botonEliminarCuenta(
            context,
            api: api,
            idUsuario: conductor.idUsuario!,
            cuenta: 'la cuenta de conductor de ${conductor.nombreCompleto}',
            recargar: recargar,
          ),
      ],
    );
  }
}

class FormularioSituacionConductor extends StatefulWidget {
  final PersonasApi api;
  final ConductorAdmin conductor;

  const FormularioSituacionConductor({super.key, required this.api, required this.conductor});

  @override
  State<FormularioSituacionConductor> createState() => _FormularioSituacionConductorState();
}

class _FormularioSituacionConductorState extends State<FormularioSituacionConductor> {
  final _claveFormulario = GlobalKey<FormState>();
  final _motivo = TextEditingController();
  late String _situacion = widget.conductor.situacionAprobacion;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.conductor;
    return ModalFormulario(
      titulo: 'Situación del conductor',
      icono: FontAwesomeIcons.userCheck,
      claveFormulario: _claveFormulario,
      textoGuardar: 'Realizar cambios',
      alGuardar: () async {
        await widget.api.cambiarSituacionConductor(c.idConductor, _situacion, _motivo.text.trim());
        return true;
      },
      campos: [
        Row(
          children: [
            Expanded(
              child: Text(
                c.nombreCompleto,
                style: const TextStyle(fontWeight: FontWeight.w600, color: ColoresApp.azul),
              ),
            ),
            InsigniaEstado(c.situacionAprobacion),
          ],
        ),
        DropdownButtonFormField<String>(
          initialValue: _situacion,
          decoration: const InputDecoration(labelText: 'Nueva situación *'),
          items: [for (final s in _situaciones) DropdownMenuItem(value: s, child: Text(Formato.enumTexto(s)))],
          onChanged: (valor) => setState(() => _situacion = valor ?? _situacion),
        ),
        TextFormField(
          controller: _motivo,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Motivo', hintText: 'Obligatorio si se rechaza o suspende'),
          validator: (v) => (_situacion == 'RECHAZADO' || _situacion == 'SUSPENDIDO') && (v == null || v.trim().isEmpty)
              ? 'Indique el motivo'
              : null,
        ),
      ],
    );
  }
}

/// Documentos digitales (PDF) de un conductor: ver en una pestana nueva o descargar.
class DialogoDocumentos extends StatefulWidget {
  final PersonasApi api;
  final ConductorAdmin conductor;

  const DialogoDocumentos({super.key, required this.api, required this.conductor});

  @override
  State<DialogoDocumentos> createState() => _DialogoDocumentosState();
}

class _DialogoDocumentosState extends State<DialogoDocumentos> {
  late final Future<List<DocumentoConductor>> _documentos = widget.api.documentosConductor(
    widget.conductor.idConductor,
  );
  int? _abriendo;

  Future<void> _abrir(DocumentoConductor documento, {required bool descargar}) async {
    setState(() => _abriendo = documento.id);
    try {
      final nombre = '${documento.tipoDocumento.toLowerCase()}_${widget.conductor.nombreUsuario}.pdf';
      if (descargar) {
        descargarArchivo(await widget.api.archivoDocumento(documento.id), nombre, 'application/pdf');
      } else {
        await mostrarPdf(
          context,
          titulo: '${Formato.enumTexto(documento.tipoDocumento)} de ${widget.conductor.nombreCompleto}',
          cargar: () => widget.api.archivoDocumento(documento.id),
          nombreDescarga: nombre,
        );
      }
    } on ApiExcepcion catch (e) {
      if (mounted) {
        await mostrarErrorDialogo(
          context,
          titulo: descargar ? 'No se pudo descargar' : 'No se pudo abrir el documento',
          mensaje: e.mensaje,
        );
      }
    } finally {
      if (mounted) setState(() => _abriendo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final movil = Pantalla.esMovil(context);
    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: ColoresApp.rojo, width: 3)),
          ),
          child: Row(
            children: [
              const FaIcon(FontAwesomeIcons.folderOpen, color: ColoresApp.azul, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Documentos de ${widget.conductor.nombreCompleto}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ColoresApp.azul),
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
        Flexible(
          child: FutureBuilder<List<DocumentoConductor>>(
            future: _documentos,
            builder: (context, instantanea) {
              if (instantanea.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('${instantanea.error}', style: const TextStyle(color: ColoresApp.rojo)),
                );
              }
              final documentos = instantanea.data;
              if (documentos == null) {
                return const Padding(padding: EdgeInsets.all(20), child: LinearProgressIndicator());
              }
              return ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(12),
                itemCount: documentos.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _filaDocumento(documentos[i]),
              );
            },
          ),
        ),
      ],
    );

    if (movil) {
      return Dialog.fullscreen(
        backgroundColor: Colors.white,
        child: SafeArea(child: contenido),
      );
    }
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: contenido),
    );
  }

  Widget _filaDocumento(DocumentoConductor documento) {
    final cargando = _abriendo == documento.id;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FaIcon(FontAwesomeIcons.filePdf, color: ColoresApp.rojo, size: 22),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombreTipoDocumento(documento.tipoDocumento),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InsigniaEstado(documento.situacionRevision),
                      if (documento.fechaVencimiento != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Vence: ${Formato.fecha(documento.fechaVencimiento)}',
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cargando) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              TextButton.icon(
                onPressed: cargando ? null : () => _abrir(documento, descargar: false),
                icon: const FaIcon(FontAwesomeIcons.eye, size: 14),
                label: const Text('Ver'),
              ),
              TextButton.icon(
                onPressed: cargando ? null : () => _abrir(documento, descargar: true),
                icon: const FaIcon(FontAwesomeIcons.download, size: 14),
                label: const Text('Descargar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
