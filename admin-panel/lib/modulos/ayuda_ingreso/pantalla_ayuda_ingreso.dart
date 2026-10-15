import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/avisos_admin.dart';
import '../../core/cliente_api.dart';
import '../../core/iconos.dart';
import '../../core/tema.dart';
import '../../widgets/flujos_crud.dart';
import '../../widgets/listado_remoto.dart';
import '../../widgets/modal_formulario.dart';
import '../../widgets/tabla/columna_tabla.dart';
import '../personas/personas_api.dart';
import 'ayuda_ingreso_api.dart';
import 'modelos.dart';

const _situaciones = ['PENDIENTE', 'ATENDIDA', 'DESCARTADA'];

/// Personas > Problemas de ingreso: quienes intentaron registrarse, ya estaban registrados y no pudieron
/// recuperar su cuenta con los 3 codigos por correo. Dejan el problema y un celular; mientras tanto no
/// pueden volver a intentarlo por 24 horas.
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
        ColumnaTabla(titulo: 'Problema', ancho: 200, proporcion: 3, valor: (a) => a.descripcion),
        ColumnaTabla(titulo: 'Situación', tipo: TipoColumna.estado, opciones: _situaciones, valor: (a) => a.situacion),
        ColumnaTabla(titulo: 'Correo registrado', ancho: 160, proporcion: 2, valor: (a) => a.correo ?? 'Sin correo'),
        ColumnaTabla(titulo: 'Usuario', valor: (a) => a.nombreUsuario ?? 'Sin cuenta activa'),
        ColumnaTabla(titulo: 'Desde', valor: (a) => a.origenTexto),
        ColumnaTabla(titulo: 'RU', valor: (a) => a.ru ?? ''),
        ColumnaTabla(titulo: 'Atendido', tipo: TipoColumna.fechaHora, valor: (a) => a.fechaAtencion),
        ColumnaTabla(titulo: 'Atendido por', valor: (a) => a.atendidoPor ?? ''),
        ColumnaTabla(titulo: 'Observación', ancho: 160, proporcion: 2, valor: (a) => a.observacionAdmin ?? ''),
      ],
      accionesFila: (ayuda, recargar) => [
        if (ayuda.pendiente && ayuda.idUsuario != null && ayuda.correo != null)
          IconButton(
            tooltip: 'Enviar credenciales al correo registrado',
            onPressed: () => flujoAccion(
              context,
              mensajeConfirmacion: 'Se generará una contraseña nueva para ${ayuda.nombreCompleto} y se enviará con '
                  'su usuario a ${ayuda.correo}. El mensaje quedará como atendido.',
              textoConfirmar: 'Sí, enviar',
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
            icon: const Icon(Iconos.envelope, size: 16, color: ColoresApp.azul),
          ),
        if (ayuda.pendiente)
          IconButton(
            tooltip: 'Marcar como atendido o descartado',
            onPressed: () => flujoEditar(
              context,
              descripcion: 'el mensaje de ${ayuda.nombreCompleto}',
              formulario: _FormularioAtender(api: api, ayuda: ayuda),
              mensajeExito: 'Se registró lo que se hizo con el mensaje.',
              alTerminar: () {
                recargar();
                avisos.actualizar();
              },
            ),
            icon: const Icon(Iconos.clipboardCheck, size: 16, color: ColoresApp.exito),
          ),
      ],
    );
  }
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
        '${widget.ayuda.nombreCompleto} (celular ${widget.ayuda.celular}): ${widget.ayuda.descripcion}',
        style: const TextStyle(color: ColoresApp.textoSuave),
      ),
      DropdownButtonFormField<String>(
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
