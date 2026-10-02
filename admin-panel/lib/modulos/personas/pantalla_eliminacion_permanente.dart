import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/iconos.dart';
import '../../core/tema.dart';
import '../../widgets/dialogos.dart';
import '../../widgets/listado_remoto.dart';
import '../../widgets/modal_formulario.dart';
import '../../widgets/tabla/columna_tabla.dart';
import 'modelos.dart';
import 'personas_api.dart';

/// Personas > Eliminacion permanente: borra de la base de datos, sin vuelta atras, a una persona con
/// sus cuentas, credenciales, archivos y todo lo que es solo suyo. Los viajes que hizo con otra
/// persona y sus calificaciones se conservan a nombre de "USUARIO ELIMINADO" (son tambien del otro).
///
/// Flujo: resumen de lo que se borra -> confirmacion naranja -> escribir el correo -> modal rojo.
class PantallaEliminacionPermanente extends StatelessWidget {
  const PantallaEliminacionPermanente({super.key});

  @override
  Widget build(BuildContext context) {
    final api = PersonasApi(context.read<ClienteApi>());
    return ListadoRemoto<PersonaEliminable>(
      titulo: 'Eliminación permanente',
      icono: Iconos.eliminarPermanente,
      nombreArchivo: 'personas_eliminables',
      cargar: api.listarEliminables,
      columnas: [
        ColumnaTabla(titulo: 'Nombre', valor: (p) => p.nombreCompleto, ancho: 160, proporcion: 2.5),
        ColumnaTabla(titulo: 'CI', valor: (p) => p.ci, ancho: 90, proporcion: 1.2),
        ColumnaTabla(titulo: 'Correo', valor: (p) => p.correo, ancho: 200, proporcion: 2.5),
        ColumnaTabla(titulo: 'Teléfono', valor: (p) => p.telefono, ancho: 100, proporcion: 1.3),
        ColumnaTabla(titulo: 'Cuentas', valor: (p) => p.cuentas, ancho: 120, proporcion: 1.6),
        ColumnaTabla(
          titulo: 'Registro',
          tipo: TipoColumna.estado,
          opciones: const ['ACTIVA', 'ELIMINADA'],
          valor: (p) => p.estado,
        ),
        ColumnaTabla(titulo: 'Registrado', tipo: TipoColumna.fechaHora, valor: (p) => p.registrado),
      ],
      accionesFila: (persona, recargar) => [
        IconButton(
          tooltip: 'Eliminar de forma permanente',
          onPressed: () => _eliminar(context, api, persona, recargar),
          icon: const Icon(Iconos.eliminarPermanente, size: 17, color: ColoresApp.rojo),
        ),
      ],
    );
  }

  Future<void> _eliminar(BuildContext context, PersonasApi api, PersonaEliminable persona, VoidCallback recargar) async {
    final ResumenEliminacion resumen;
    try {
      resumen = await api.resumenEliminacion(persona.idPersona);
    } on ApiExcepcion catch (e) {
      if (context.mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
      return;
    }
    if (!context.mounted) return;
    if (resumen.bloqueo != null) {
      await mostrarErrorDialogo(context, titulo: 'No se puede eliminar', mensaje: resumen.bloqueo!);
      return;
    }
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Está seguro de eliminar este registro?',
      mensaje: 'Se eliminarán de manera PERMANENTE todos los registros de ${resumen.nombreCompleto}: sus cuentas, '
          'credenciales, datos, fotos y documentos. No se puede deshacer.',
      textoConfirmar: 'Sí, continuar',
    );
    if (!confirmado || !context.mounted) return;
    final resultado = await abrirModal(context, _FormularioEliminacion(api: api, resumen: resumen));
    if (resultado == null || !context.mounted) return;
    recargar();
    await mostrarEliminado(
      context,
      titulo: 'Eliminado para siempre',
      mensaje: 'Se eliminaron de forma permanente los registros de ${resumen.nombreCompleto}.',
    );
  }
}

/// Que se borra, que se conserva y el campo donde el administrador escribe el correo para confirmar.
class _FormularioEliminacion extends StatefulWidget {
  final PersonasApi api;
  final ResumenEliminacion resumen;

  const _FormularioEliminacion({required this.api, required this.resumen});

  @override
  State<_FormularioEliminacion> createState() => _FormularioEliminacionState();
}

class _FormularioEliminacionState extends State<_FormularioEliminacion> {
  final _claveFormulario = GlobalKey<FormState>();
  final _confirmacion = TextEditingController();

  @override
  void dispose() {
    _confirmacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resumen;
    const estiloLinea = TextStyle(fontSize: 13.5, height: 1.45, color: ColoresApp.texto);
    return ModalFormulario(
      titulo: 'Eliminar a ${r.nombreCompleto}',
      icono: Iconos.eliminarPermanente,
      claveFormulario: _claveFormulario,
      textoGuardar: 'Eliminar para siempre',
      alGuardar: () async {
        await widget.api.eliminarPermanente(r.idPersona, _confirmacion.text.trim());
        return true;
      },
      campos: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFDECEE),
            borderRadius: BorderRadius.circular(RadiosApp.control),
            border: Border.all(color: const Color(0xFFF5B5BF)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Iconos.triangleExclamation, color: ColoresApp.rojo, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Esta eliminación es permanente: los registros se borran de la base de datos y sus archivos del '
                  'servidor. No se puede deshacer. La persona podrá registrarse de nuevo con su CI y su correo.',
                  style: TextStyle(fontSize: 13, height: 1.4, color: ColoresApp.rojoOscuro, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Se elimina:', style: TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azul)),
            const SizedBox(height: 4),
            if (r.seElimina.isEmpty)
              const Text('- Solo el registro de la persona.', style: estiloLinea)
            else
              for (final (concepto, cantidad) in r.seElimina) Text('- $concepto: $cantidad', style: estiloLinea),
            const Text('- Su carpeta de archivos (fotos del carnet, licencia, PDF y QR).', style: estiloLinea),
            if (r.viajesConservados > 0 || r.calificacionesConservadas > 0) ...[
              const SizedBox(height: 10),
              const Text('Se conserva:', style: TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azul)),
              const SizedBox(height: 4),
              Text(
                '- ${r.viajesConservados} viaje(s) y ${r.calificacionesConservadas} calificación(es) con otras personas: '
                'quedan a nombre de "USUARIO ELIMINADO" para no borrar el historial ni los comentarios del otro.',
                style: estiloLinea,
              ),
            ],
          ],
        ),
        TextFormField(
          controller: _confirmacion,
          decoration: InputDecoration(
            labelText: 'Para confirmar escriba: ${r.confirmacion}',
            hintText: r.confirmacion,
          ),
          validator: (v) => (v?.trim().toLowerCase() ?? '') == r.confirmacion.toLowerCase()
              ? null
              : 'Escriba exactamente ${r.confirmacion}',
        ),
      ],
    );
  }
}
