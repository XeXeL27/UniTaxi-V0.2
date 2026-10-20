import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/cliente_api.dart';
import '../../core/formato.dart';
import '../../core/iconos.dart';
import '../../core/relieve.dart';
import '../../core/tema.dart';
import '../../widgets/flujos_crud.dart';
import '../../widgets/listado_remoto.dart';
import '../../widgets/modal_registro.dart';
import '../../widgets/modal_formulario.dart';
import '../../widgets/tabla/columna_tabla.dart';
import '../expediente/vista_expediente.dart';
import '../personas/personas_api.dart';
import 'modelos.dart';
import 'reportes_api.dart';
import '../../widgets/dialogo_animado.dart';

const _situaciones = ['PENDIENTE', 'EN_REVISION', 'RESUELTO', 'CERRADO'];
const _resoluciones = [
  'DEVOLUCION_AL_REMITENTE',
  'CLIENTE_PAGO_DIRECTO',
  'REPARTIDOR_ASUME_PERDIDA',
  'CLIENTE_NO_RESPONDIO',
  'OTRO',
];

/// Resoluciones del reporte "Pasajero no se presento".
const _resolucionesAusente = ['ADVERTENCIA_AL_PASAJERO', 'CUENTA_SUSPENDIDA', 'DESESTIMADO', 'OTRO'];

class PantallaReportesEntrega extends StatelessWidget {
  const PantallaReportesEntrega({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ReportesApi(context.read<ClienteApi>());
    return ListadoRemoto<ReporteEntrega>(
      titulo: 'Reportes',
      icono: Iconos.triangleExclamation,
      nombreArchivo: 'reportes-entrega',
      cargar: api.listar,
      columnas: [
        ColumnaTabla(titulo: 'Reporte', tipo: TipoColumna.numero, valor: (r) => r.id),
        ColumnaTabla(titulo: 'Viaje', tipo: TipoColumna.numero, valor: (r) => r.idViaje),
        ColumnaTabla(titulo: 'Incidente', valor: (r) => Formato.enumTexto(r.motivo)),
        ColumnaTabla(titulo: 'Pasajero', valor: (r) => r.nombrePasajero ?? ''),
        ColumnaTabla(titulo: 'Tipo', valor: (r) => r.tipoEnvio ?? ''),
        ColumnaTabla(titulo: 'Situación', tipo: TipoColumna.estado, opciones: _situaciones, valor: (r) => r.situacion),
        ColumnaTabla(titulo: 'Fecha', tipo: TipoColumna.fechaHora, valor: (r) => r.fecha),
        ColumnaTabla(
          titulo: 'Evidencia',
          valor: (r) => r.fotoFallaUrl == null ? 'Sin foto' : 'Foto',
          celda: (r) => Text(r.fotoFallaUrl == null ? 'Sin foto' : 'Ver foto'),
        ),
      ],
      accionesFila: (reporte, recargar) => [
        AccionRegistro(
          texto: 'Ver reporte completo',
          icono: Iconos.eye,
          tono: TonoBoton.turquesa,
          alPresionar: () => _verReporte(context, api, reporte, recargar),
        ),
        if (reporte.situacion == 'PENDIENTE' || reporte.situacion == 'EN_REVISION')
          AccionRegistro(
            texto: 'Resolver',
            icono: Iconos.clipboardCheck,
            tono: TonoBoton.verde,
            alPresionar: () => flujoEditar(
              context,
              descripcion: 'el reporte #${reporte.id}',
              formulario: _FormularioResolucion(api: api, reporte: reporte),
              mensajeExito: 'Se registró la resolución sin mover dinero.',
              alTerminar: recargar,
            ),
          ),
      ],
    );
  }

  Future<void> _verReporte(BuildContext context, ReportesApi api, ReporteEntrega reporte, VoidCallback recargar) {
    return mostrarDialogo<void>(
      context: context,
      builder: (_) => _DetalleReporte(api: api, reporte: reporte, recargar: recargar),
    );
  }
}

class _DetalleReporte extends StatefulWidget {
  final ReportesApi api;
  final ReporteEntrega reporte;
  final VoidCallback recargar;

  const _DetalleReporte({required this.api, required this.reporte, required this.recargar});

  @override
  State<_DetalleReporte> createState() => _DetalleReporteState();
}

class _DetalleReporteState extends State<_DetalleReporte> {
  late final Future<Uint8List>? _foto = widget.reporte.fotoFallaUrl == null ? null : widget.api.foto(widget.reporte.id);

  @override
  Widget build(BuildContext context) {
    final r = widget.reporte;
    final contenido = ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Icon(Iconos.triangleExclamation, color: ColoresApp.rojo),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reporte #${r.id}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ColoresApp.azul),
              ),
            ),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Iconos.xmark)),
          ],
        ),
        const Divider(),
        DatosEnGrilla([
          ('Viaje', '#${r.idViaje}'),
          ('Situación', Formato.enumTexto(r.situacion)),
          ('Tipo de envío', r.tipoEnvio),
          ('Motivo', r.motivo),
          ('Contacto', r.telefonoContacto),
          ('Destino', r.destinoDireccion),
          ('Costo producto real', monedaBs(r.costoProductoReal)),
          ('Detalle', r.descripcionEntrega),
          ('Comercio', r.detalleCompra),
        ]),
        const SizedBox(height: 14),
        Text(r.descripcion, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (r.esPasajeroAusente) ...[
          const SizedBox(height: 14),
          const Text(
            'Pasajero reportado',
            style: TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azul),
          ),
          const SizedBox(height: 6),
          DatosEnGrilla([
            ('Pasajero', r.nombrePasajero),
            ('Celular', r.telefonoPasajero),
            ('Veces que no se presentó', '${r.vecesNoSePresento}'),
            ('Cuenta', r.pasajeroSuspendido ? 'Suspendida' : 'Activa'),
          ]),
          if (r.idUsuarioPasajero != null && !r.pasajeroSuspendido) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: ColoresApp.rojo),
                onPressed: () => flujoAccion(
                  context,
                  mensajeConfirmacion:
                      'Va a suspender la cuenta de pasajero de ${r.nombrePasajero ?? 'esta persona'}. '
                      'No podrá ingresar y, si tiene la sesión abierta, se cerrará.',
                  textoConfirmar: 'Sí, suspender',
                  accion: () =>
                      PersonasApi(context.read<ClienteApi>())
                          .cambiarEstadoUsuario(r.idUsuarioPasajero!, suspender: true),
                  tituloExito: '¡Cuenta suspendida!',
                  mensajeExito: 'Se suspendió la cuenta de pasajero. Registra la resolución del reporte.',
                  alTerminar: () {
                    Navigator.of(context).pop();
                    widget.recargar();
                  },
                ),
                icon: const Icon(Iconos.userSlash, size: 16),
                label: const Text('Suspender cuenta del pasajero'),
              ),
            ),
          ],
        ],
        if (r.motivoFalla != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('Motivo registrado: ${r.motivoFalla}')),
        if (r.observacionCompra != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('Observación de compra: ${r.observacionCompra}')),
        if (_foto != null) ...[
          const SizedBox(height: 16),
          const Text(
            'Evidencia de incidente',
            style: TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azul),
          ),
          const SizedBox(height: 8),
          FutureBuilder<Uint8List>(
            future: _foto,
            builder: (_, estado) => estado.hasError
                ? const Text('No se pudo cargar la evidencia')
                : estado.data == null
                ? const LinearProgressIndicator()
                : Image.memory(estado.data!, height: 260, fit: BoxFit.contain),
          ),
        ],
        if (r.tipoResolucion != null) ...[
          const SizedBox(height: 14),
          Text('Resolución: ${Formato.enumTexto(r.tipoResolucion)}'),
          if (r.fechaResolucion != null) Text('Registrada: ${Formato.fechaHora(r.fechaResolucion)}'),
          if (r.observacionAdmin != null) Text('Observación administrativa: ${r.observacionAdmin}'),
        ],
      ],
    );
    return Dialog(
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680), child: contenido),
    );
  }
}

class _FormularioResolucion extends StatefulWidget {
  final ReportesApi api;
  final ReporteEntrega reporte;

  const _FormularioResolucion({required this.api, required this.reporte});

  @override
  State<_FormularioResolucion> createState() => _FormularioResolucionState();
}

class _FormularioResolucionState extends State<_FormularioResolucion> {
  final _clave = GlobalKey<FormState>();
  late final List<String> _opciones = widget.reporte.esPasajeroAusente ? _resolucionesAusente : _resoluciones;
  late String _tipo = widget.reporte.tipoResolucion ?? _opciones.first;
  final _observacion = TextEditingController();

  @override
  void dispose() {
    _observacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ModalFormulario(
    titulo: widget.reporte.esPasajeroAusente ? 'Resolver reporte del pasajero' : 'Resolver reporte de entrega',
    icono: Iconos.clipboardCheck,
    claveFormulario: _clave,
    textoGuardar: 'Registrar resolución',
    alGuardar: () async {
      await widget.api.resolver(
        widget.reporte.id,
        tipoResolucion: _tipo,
        situacion: 'RESUELTO',
        observacion: _observacion.text.trim(),
      );
      return true;
    },
    campos: [
      Text(
        widget.reporte.esPasajeroAusente
            ? 'La resolución registra la decisión. Para suspender la cuenta usa el botón del detalle del reporte.'
            : 'La resolución solo registra la gestión administrativa. No genera devolución, cobro ni compensación automática.',
        style: const TextStyle(color: ColoresApp.textoSuave),
      ),
      DropdownButtonFormField<String>(
        borderRadius: BorderRadius.circular(14),
        dropdownColor: Colors.white,
        initialValue: _tipo,
        decoration: const InputDecoration(labelText: 'Tipo de resolución *'),
        items: [for (final tipo in _opciones) DropdownMenuItem(value: tipo, child: Text(Formato.enumTexto(tipo)))],
        onChanged: (v) => setState(() => _tipo = v ?? _tipo),
      ),
      TextFormField(
        controller: _observacion,
        maxLines: 4,
        maxLength: 1000,
        decoration: const InputDecoration(labelText: 'Observación del administrador *'),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Describa la gestión realizada' : null,
      ),
    ],
  );
}
