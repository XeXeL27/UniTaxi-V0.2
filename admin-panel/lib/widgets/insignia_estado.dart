import 'package:flutter/material.dart';

import '../core/formato.dart';
import '../core/relieve.dart';

/// Etiqueta de color para valores de estado y situacion (ACTIVO, PENDIENTE, RECHAZADO, etc.), con
/// el estilo de la guia relieve: pildora tenida del color, con un punto y el texto mas oscuro.
/// [texto] reemplaza al texto que sale del codigo.
class InsigniaEstado extends StatelessWidget {
  final String valor;
  final String? texto;

  const InsigniaEstado(this.valor, {super.key, this.texto});

  static const _exito = {
    'ACTIVO',
    'ACTIVA',
    'HABILITADO',
    'HABILITADA',
    'APROBADO',
    'APROBADA',
    'COMPLETADO',
    'RESUELTO',
    'ATENDIDA',
    'ACEPTADA',
    'VERIFICADO',
    'ENTREGADO',
    'SUBIDA',
  };
  static const _alerta = {
    'PENDIENTE',
    'OBSERVADO',
    'EN_REVISION',
    'CON_OFERTAS',
    'EN_CURSO',
    'VENCIDO',
    'PENDIENTE_RECOGIDA',
    'EN_CAMINO_RECOGIDA',
    'EN_MANO',
  };
  static const _peligro = {
    'INACTIVO',
    'ELIMINADA',
    'RECHAZADO',
    'RECHAZADA',
    'SUSPENDIDO',
    'CANCELADO',
    'CANCELADA',
    'VENCIDA',
    'NO_ENTREGADO',
    'SUSPENDIDA',
  };
  static const _info = {'PASAJERO', 'CONDUCTOR', 'DELIVERY'};
  static const _admin = {'ADMIN', 'ADMINISTRADOR'};

  Color get _color => switch (valor) {
    _ when _exito.contains(valor) => const Color(0xFF2E7D4F),
    _ when _alerta.contains(valor) => const Color(0xFFB7791F),
    _ when _peligro.contains(valor) => const Color(0xFFC8243F),
    _ when _info.contains(valor) => const Color(0xFF2F6BD8),
    _ when _admin.contains(valor) => const Color(0xFF7C3AED),
    _ => const Color(0xFF5E7497),
  };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final oscuro = Relieve.aclarar(color, -0.25);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Relieve.aclarar(color, 0.92), Relieve.aclarar(color, 0.84)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Relieve.aclarar(color, 0.55)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.22), offset: const Offset(0, 2), blurRadius: 4, spreadRadius: -1),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: oscuro, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            texto ?? Formato.enumTexto(valor),
            maxLines: 1,
            style: TextStyle(color: oscuro, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
