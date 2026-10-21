import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/avisos_admin.dart';
import '../../core/cliente_api.dart';
import '../../core/iconos.dart';
import '../../core/relieve.dart';
import '../../core/tema.dart';
import '../../widgets/flujos_crud.dart';
import '../../widgets/listado_remoto.dart';
import '../../widgets/modal_registro.dart';
import '../../widgets/modal_formulario.dart';
import '../../widgets/tabla/columna_tabla.dart';
import '../personas/personas_api.dart';
import 'ayuda_ingreso_api.dart';
import 'modelos.dart';

const _situaciones = ['PENDIENTE', 'ATENDIDA', 'DESCARTADA'];

/// Personas > Problemas de ingreso: quienes no pueden ingresar. Desde el registro (ya estaban registrados y
/// no pudieron recuperar su cuenta con los 3 codigos por correo) o desde el login (marcan sus problemas,
/// por ejemplo la cuenta suspendida, y con "Otro" escriben el motivo). Dejan un celular y esperan 24 horas
/// para enviar otro. El administrador habilita la cuenta, la mantiene suspendida, le escribe un correo,
/// le reenvia las credenciales o da el caso por atendido.
class PantallaAyudaIngreso extends StatelessWidget {
  const PantallaAyudaIngreso({super.key});

  @override
  Widget build(BuildContext context) {
    final api = AyudaIngresoApi(context.read<ClienteApi>());
    final avisos = context.read<AvisosAdmin>();
    return ListadoRemoto<AyudaIngreso>(
      titulo: 'Problemas de ingreso',
      icono: Iconos.ayudaIngreso,
      nombreArchivo: 'problemas-de-ingreso',
      cargar: () async {
        final lista = await api.listar();
        // Al entrar o recargar, el contador del menu y la campana quedan al dia.
        avisos.actualizar();
        return lista;
      },
      columnas: [
        ColumnaTabla(titulo: 'Fecha', tipo: TipoColumna.fechaHora, valor: (a) => a.fecha),
        ColumnaTabla(titulo: 'Persona', ancho: 160, proporcion: 2, valor: (a) => a.nombreCompleto),
        ColumnaTabla(titulo: 'CI', valor: (a) => a.ci ?? ''),
        ColumnaTabla(titulo: 'Celular', valor: (a) => a.celular),
        ColumnaTabla(titulo: 'Problema', ancho: 200, proporcion: 3, valor: (a) => a.problemaTexto),
        ColumnaTabla(titulo: 'Situación', tipo: TipoColumna.estado, opciones: _situaciones, valor: (a) => a.situacion),
        ColumnaTabla(titulo: 'Cuenta', valor: (a) => a.cuentaTexto),
        ColumnaTabla(titulo: 'Motivo de la suspensión', ancho: 160, proporcion: 2, valor: (a) => a.motivoSuspension ?? ''),
        ColumnaTabla(titulo: 'Correo registrado', ancho: 160, proporcion: 2, valor: (a) => a.correo ?? 'Sin correo'),
        ColumnaTabla(titulo: 'Teléfono registrado', valor: (a) => a.telefono ?? ''),
        ColumnaTabla(titulo: 'Usuario', valor: (a) => a.nombreUsuario ?? 'Sin cuenta activa'),
        ColumnaTabla(titulo: 'Desde', valor: (a) => a.origenTexto),
        ColumnaTabla(titulo: 'RU', valor: (a) => a.ru ?? ''),
        ColumnaTabla(titulo: 'Atendido', tipo: TipoColumna.fechaHora, valor: (a) => a.fechaAtencion),
        ColumnaTabla(titulo: 'Atendido por', valor: (a) => a.atendidoPor ?? ''),
        ColumnaTabla(titulo: 'Observación', ancho: 160, proporcion: 2, valor: (a) => a.observacionAdmin ?? ''),
      ],
      accionesFila: (ayuda, recargar) => [
        if (ayuda.pendiente && ayuda.suspendida)
          AccionRegistro(
            texto: 'Habilitar cuenta',
            icono: Iconos.userCheck,
            tono: TonoBoton.verde,
            alPresionar: () => flujoAccion(
              context,
              mensajeConfirmacion:
                  'Se habilitará la cuenta de ${ayuda.nombreCompleto}: podrá volver a ingresar con su usuario y su '
                  'contraseña${ayuda.correo == null ? '' : ' y se le avisará a ${ayuda.correo}'}. El mensaje quedará como atendido.',
              textoConfirmar: 'Sí, habilitar',
              tono: TonoBoton.verde,
              accion: () => api.habilitar(ayuda.id),
              tituloExito: '¡Cuenta habilitada!',
              mensajeExito: '${ayuda.nombreCompleto} ya puede ingresar a la app.',
              alTerminar: () {
                recargar();
                avisos.actualizar();
              },
            ),
          ),
        if (ayuda.pendiente && ayuda.suspendida)
          AccionRegistro(
            texto: 'Mantener suspendida',
            icono: Iconos.lock,
            tono: TonoBoton.naranja,
            alPresionar: () => flujoCrear(
              context,
              formulario: _FormularioTexto(
                titulo: 'Mantener suspendida',
                icono: Iconos.lock,
                explicacion: 'La cuenta de ${ayuda.nombreCompleto} sigue suspendida. '
                    '${ayuda.correo == null ? 'No tiene correo: avísale al ${ayuda.celular}.' : 'El motivo le llegará a ${ayuda.correo}.'}',
                etiqueta: 'Motivo *',
                textoGuardar: 'Guardar y avisar',
                enviar: (texto, _) => api.mantenerSuspendida(ayuda.id, texto),
              ),
              tituloExito: 'Cuenta suspendida',
              mensajeExito: (_) => 'La cuenta sigue suspendida y el mensaje quedó atendido.',
              alTerminar: () {
                recargar();
                avisos.actualizar();
              },
            ),
          ),
        if (ayuda.pendiente && ayuda.correo != null)
          AccionRegistro(
            texto: 'Enviar correo',
            icono: Iconos.envelope,
            tono: TonoBoton.azul,
            alPresionar: () => flujoCrear(
              context,
              formulario: _FormularioTexto(
                titulo: 'Enviar correo',
                icono: Iconos.envelope,
                explicacion: 'Para ${ayuda.nombreCompleto} (${ayuda.correo}). Problema: ${ayuda.problemaTexto}',
                etiqueta: 'Mensaje *',
                textoGuardar: 'Enviar correo',
                conCerrar: true,
                enviar: (texto, cerrar) => api.enviarCorreo(ayuda.id, texto, cerrar: cerrar),
              ),
              tituloExito: '¡Correo enviado!',
              mensajeExito: (cerrado) => cerrado == true
                  ? 'El correo llegará a ${ayuda.correo} y el mensaje quedó atendido.'
                  : 'El correo llegará a ${ayuda.correo}. El caso sigue pendiente.',
              alTerminar: () {
                recargar();
                avisos.actualizar();
              },
            ),
          ),
        if (ayuda.pendiente && !ayuda.suspendida && ayuda.idUsuario != null && ayuda.correo != null)
          AccionRegistro(
            texto: 'Enviar credenciales',
            icono: Iconos.envelope,
            tono: TonoBoton.celeste,
            alPresionar: () => flujoAccion(
              context,
              mensajeConfirmacion:
                  'Se generará una contraseña nueva para ${ayuda.nombreCompleto} y se enviará con '
                  'su usuario a ${ayuda.correo}. El mensaje quedará como atendido.',
              textoConfirmar: 'Sí, enviar',
              tono: TonoBoton.celeste,
              accion: () async {
                await PersonasApi(context.read<ClienteApi>()).reenviarCredenciales(ayuda.idUsuario!);
                await api.atender(
                  ayuda.id,
                  situacion: 'ATENDIDA',
                  observacion: 'Se enviaron credenciales nuevas a ${ayuda.correo}.',
                );
              },
              tituloExito: '¡Credenciales enviadas!',
              mensajeExito: 'La persona recibirá su usuario y una contraseña nueva en su correo.',
              alTerminar: () {
                recargar();
                avisos.actualizar();
              },
            ),
          ),
        if (ayuda.pendiente)
          AccionRegistro(
            texto: 'Atender o descartar',
            icono: Iconos.clipboardCheck,
            tono: TonoBoton.verde,
            alPresionar: () => flujoEditar(
              context,
              descripcion: 'el mensaje de ${ayuda.nombreCompleto}',
              formulario: _FormularioAtender(api: api, ayuda: ayuda),
              mensajeExito: 'Se registró lo que se hizo con el mensaje.',
              alTerminar: () {
                recargar();
                avisos.actualizar();
              },
            ),
          ),
      ],
    );
  }
}

/// Texto del administrador (motivo o correo). [conCerrar] agrega la casilla "Dar el caso por atendido";
/// [enviar] recibe el texto y esa casilla. El modal devuelve si el caso se cerro.
class _FormularioTexto extends StatefulWidget {
  final String titulo;
  final IconData icono;
  final String explicacion;
  final String etiqueta;
  final String textoGuardar;
  final bool conCerrar;
  final Future<void> Function(String texto, bool cerrar) enviar;

  const _FormularioTexto({
    required this.titulo,
    required this.icono,
    required this.explicacion,
    required this.etiqueta,
    required this.textoGuardar,
    this.conCerrar = false,
    required this.enviar,
  });

  @override
  State<_FormularioTexto> createState() => _FormularioTextoState();
}

class _FormularioTextoState extends State<_FormularioTexto> {
  final _clave = GlobalKey<FormState>();
  final _texto = TextEditingController();
  bool _cerrar = true;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ModalFormulario(
    titulo: widget.titulo,
    icono: widget.icono,
    claveFormulario: _clave,
    textoGuardar: widget.textoGuardar,
    alGuardar: () async {
      final cerrar = !widget.conCerrar || _cerrar;
      await widget.enviar(_texto.text.trim(), cerrar);
      return cerrar;
    },
    campos: [
      Text(widget.explicacion, style: const TextStyle(color: ColoresApp.textoSuave)),
      TextFormField(
        controller: _texto,
        maxLines: 5,
        maxLength: 1000,
        decoration: InputDecoration(labelText: widget.etiqueta, alignLabelWithHint: true),
        validator: (v) => (v ?? '').trim().length < 5 ? 'Escribe al menos 5 letras' : null,
      ),
      if (widget.conCerrar)
        CheckboxListTile(
          value: _cerrar,
          onChanged: (v) => setState(() => _cerrar = v ?? true),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text('Dar el caso por atendido'),
          subtitle: const Text('Desmárcalo si esperas que la persona te responda.'),
        ),
    ],
  );
}

class _FormularioAtender extends StatefulWidget {
  final AyudaIngresoApi api;
  final AyudaIngreso ayuda;

  const _FormularioAtender({required this.api, required this.ayuda});

  @override
  State<_FormularioAtender> createState() => _FormularioAtenderState();
}

class _FormularioAtenderState extends State<_FormularioAtender> {
  final _clave = GlobalKey<FormState>();
  final _observacion = TextEditingController();
  String _situacion = 'ATENDIDA';

  @override
  void dispose() {
    _observacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ModalFormulario(
    titulo: 'Atender mensaje',
    icono: Iconos.clipboardCheck,
    claveFormulario: _clave,
    textoGuardar: 'Guardar',
    alGuardar: () async {
      await widget.api.atender(widget.ayuda.id, situacion: _situacion, observacion: _observacion.text.trim());
      return true;
    },
    campos: [
      Text(
        '${widget.ayuda.nombreCompleto} (celular ${widget.ayuda.celular}): ${widget.ayuda.problemaTexto}',
        style: const TextStyle(color: ColoresApp.textoSuave),
      ),
      DropdownButtonFormField<String>(
        borderRadius: BorderRadius.circular(14),
        dropdownColor: Colors.white,
        initialValue: _situacion,
        decoration: const InputDecoration(labelText: 'Resultado *'),
        items: const [
          DropdownMenuItem(value: 'ATENDIDA', child: Text('Atendido')),
          DropdownMenuItem(value: 'DESCARTADA', child: Text('Descartado')),
        ],
        onChanged: (v) => setState(() => _situacion = v ?? _situacion),
      ),
      TextFormField(
        controller: _observacion,
        maxLines: 4,
        maxLength: 1000,
        decoration: const InputDecoration(labelText: 'Qué se hizo *'),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Describe lo que se hizo' : null,
      ),
    ],
  );
}
