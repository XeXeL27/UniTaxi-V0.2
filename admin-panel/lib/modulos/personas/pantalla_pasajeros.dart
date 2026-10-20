import 'package:flutter/material.dart';

import '../../core/iconos.dart';

import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/relieve.dart';
import '../../core/tema.dart';
import '../../widgets/boton_relieve.dart';
import '../../widgets/dialogos.dart';
import '../../widgets/listado_remoto.dart';
import '../../widgets/modal_registro.dart';
import '../../widgets/tabla/columna_tabla.dart';
import '../expediente/expediente_api.dart';
import '../expediente/expediente_pasajero.dart';
import '../expediente/vista_expediente.dart';
import 'acciones_cuenta.dart';
import 'modelos.dart';
import 'personas_api.dart';
import '../../widgets/dialogo_animado.dart';

/// Pasajeros: consulta, suspender o habilitar y eliminar su cuenta (se registran desde Personas o
/// Usuarios, o desde la app).
class PantallaPasajeros extends StatelessWidget {
  const PantallaPasajeros({super.key});

  @override
  Widget build(BuildContext context) {
    final api = PersonasApi(context.read<ClienteApi>());
    final expedienteApi = ExpedienteApi(context.read<ClienteApi>());
    return ListadoRemoto<PasajeroAdmin>(
      titulo: 'Pasajeros',
      icono: Iconos.userCheck,
      nombreArchivo: 'pasajeros',
      cargar: api.listarPasajeros,
      alAbrir: (pasajero, recargar) {
        final cierre = CierreModal();
        void hecho() {
          recargar();
          cierre.cerrar();
        }

        abrirExpediente(
          context,
          ExpedientePasajero(
            api: expedienteApi,
            personasApi: api,
            pasajero: pasajero,
            alCambiar: recargar,
            cierre: cierre,
            acciones: [
              AccionRegistro(
                texto: 'Verificar con SIGSE',
                icono: Iconos.idBadge,
                tono: TonoBoton.morado,
                alPresionar: () => verificarEstudianteUap(context, api: api, pasajero: pasajero, recargar: hecho),
              ),
              accionEliminarCuenta(
                context,
                api: api,
                idUsuario: pasajero.idUsuario,
                cuenta: 'la cuenta de pasajero de ${pasajero.nombreCompleto}',
                hecho: hecho,
              ),
            ],
          ),
        );
      },
      columnas: [
        ColumnaTabla(titulo: 'Usuario', valor: (p) => p.nombreUsuario),
        ColumnaTabla(titulo: 'Nombre', valor: (p) => '${p.nombres} ${p.apellidos}', ancho: 150, proporcion: 2.5),
        ColumnaTabla(
          titulo: 'Estudiante UAP',
          tipo: TipoColumna.estado,
          opciones: const ['VERIFICADO', 'VENCIDO', 'PENDIENTE', 'RECHAZADO', 'NO'],
          valor: (p) => p.estudianteTexto,
        ),
        ColumnaTabla(titulo: 'Correo', valor: (p) => p.correo, ancho: 210, proporcion: 2.5),
        ColumnaTabla(titulo: 'Teléfono', valor: (p) => p.telefono, ancho: 100, proporcion: 1.4),
        ColumnaTabla(titulo: 'Calificación', tipo: TipoColumna.numero, valor: (p) => p.calificacionPromedio, ancho: 90),
        ColumnaTabla(titulo: 'N.º calif.', tipo: TipoColumna.numero, valor: (p) => p.totalCalificaciones, ancho: 90),
        ColumnaTabla(
          titulo: 'Situación',
          tipo: TipoColumna.estado,
          opciones: const ['ACTIVO', 'SUSPENDIDO'],
          valor: (p) => p.situacion,
        ),
        ColumnaTabla(titulo: 'RU', valor: (p) => p.ru, ancho: 90),
        ColumnaTabla(titulo: 'Registrado', tipo: TipoColumna.fechaHora, valor: (p) => p.fechaRegistro),
      ],
    );
  }
}

/// Pide el RU (con el que ya tenia, si hay) y verifica al pasajero con el SIGSE de la UAP: queda como
/// estudiante si su nombre, CI y fecha de nacimiento coinciden y esta matriculado.
Future<void> verificarEstudianteUap(
  BuildContext context, {
  required PersonasApi api,
  required PasajeroAdmin pasajero,
  required VoidCallback recargar,
}) async {
  final previo = pasajero.ru != null && RegExp(r'^\d+$').hasMatch(pasajero.ru!) ? pasajero.ru! : '';
  final campo = TextEditingController(text: previo);
  final ru = await mostrarDialogo<String>(
    context: context,
    builder: (contexto) => AlertDialog(
      icon: const Icon(Iconos.idBadge, color: Color(0xFF7C3AED)),
      title: const Text('Verificar con SIGSE'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Se consultará el RU en el sistema de la UAP. ${pasajero.nombreCompleto} quedará como estudiante '
            '(con descuento) si está matriculado y su nombre, CI y fecha de nacimiento coinciden.',
            style: const TextStyle(color: ColoresApp.textoSuave),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: campo,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'RU'),
            onSubmitted: (v) => Navigator.of(contexto).pop(v.trim()),
          ),
        ],
      ),
      actions: [
        BotonRelieve(texto: 'Cancelar', alPresionar: () => Navigator.of(contexto).pop()),
        BotonRelieve(
          texto: 'Verificar',
          icono: Iconos.idBadge,
          tono: TonoBoton.morado,
          alPresionar: () => Navigator.of(contexto).pop(campo.text.trim()),
        ),
      ],
    ),
  );
  campo.dispose();
  if (ru == null || ru.isEmpty || !context.mounted) return;
  try {
    await api.verificarEstudianteUap(pasajero.idPasajero, ru);
    if (!context.mounted) return;
    await mostrarExito(
      context,
      titulo: '¡Estudiante verificado!',
      mensaje: '${pasajero.nombreCompleto} quedó como estudiante UAP.',
    );
    recargar();
  } on ApiExcepcion catch (e) {
    if (context.mounted) await mostrarErrorDialogo(context, titulo: 'No se pudo verificar', mensaje: e.mensaje);
  }
}
