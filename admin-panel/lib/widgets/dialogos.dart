import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Modales de resultado y confirmacion del panel (icono grande en circulo, titulo de color,
/// mensaje y botones). Se usan en todas las pantallas:
///
/// - verde: la accion se realizo (registro, edicion).
/// - naranja: pide confirmacion antes de editar o eliminar.
/// - rojo: se elimino un registro, o la accion fallo.
enum TipoDialogo { exito, confirmacion, eliminado, error }

class _Estilo {
  final Color color;
  final FaIconData icono;

  const _Estilo(this.color, this.icono);
}

const _estilos = {
  TipoDialogo.exito: _Estilo(Color(0xFF198754), FontAwesomeIcons.check),
  TipoDialogo.confirmacion: _Estilo(Color(0xFFF08C00), FontAwesomeIcons.exclamation),
  TipoDialogo.eliminado: _Estilo(Color(0xFFDC3545), FontAwesomeIcons.trashCan),
  TipoDialogo.error: _Estilo(Color(0xFFDC3545), FontAwesomeIcons.xmark),
};

/// Modal verde: la accion se realizo.
Future<void> mostrarExito(BuildContext context, {String titulo = '¡Listo!', required String mensaje}) {
  return _mostrar(context, TipoDialogo.exito, titulo, mensaje);
}

/// Modal rojo: se elimino el registro.
Future<void> mostrarEliminado(BuildContext context, {String titulo = 'Registro eliminado', required String mensaje}) {
  return _mostrar(context, TipoDialogo.eliminado, titulo, mensaje);
}

/// Modal rojo: la accion no se pudo realizar.
Future<void> mostrarErrorDialogo(
  BuildContext context, {
  String titulo = 'No se pudo completar',
  required String mensaje,
}) {
  return _mostrar(context, TipoDialogo.error, titulo, mensaje);
}

/// Modal naranja con Cancelar / confirmar. Devuelve true si el usuario confirma.
Future<bool> confirmarAccion(
  BuildContext context, {
  String titulo = '¿Está seguro?',
  required String mensaje,
  String textoConfirmar = 'Sí, continuar',
}) async {
  final confirmado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoResultado(
      tipo: TipoDialogo.confirmacion,
      titulo: titulo,
      mensaje: mensaje,
      textoBoton: textoConfirmar,
      conCancelar: true,
    ),
  );
  return confirmado ?? false;
}

Future<void> _mostrar(BuildContext context, TipoDialogo tipo, String titulo, String mensaje) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DialogoResultado(tipo: tipo, titulo: titulo, mensaje: mensaje, textoBoton: 'Aceptar'),
  );
}

class _DialogoResultado extends StatelessWidget {
  final TipoDialogo tipo;
  final String titulo;
  final String mensaje;
  final String textoBoton;
  final bool conCancelar;

  const _DialogoResultado({
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.textoBoton,
    this.conCancelar = false,
  });

  @override
  Widget build(BuildContext context) {
    final estilo = _estilos[tipo]!;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 110,
                height: 110,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: estilo.color, width: 5),
                ),
                child: FaIcon(estilo.icono, color: estilo.color, size: 52),
              ),
              const SizedBox(height: 20),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: estilo.color),
              ),
              const SizedBox(height: 12),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Color(0xFF212529), height: 1.4),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (conCancelar)
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6C757D),
                        side: const BorderSide(color: Color(0xFF6C757D)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  FilledButton(
                    autofocus: true,
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: estilo.color,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    child: Text(textoBoton),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
