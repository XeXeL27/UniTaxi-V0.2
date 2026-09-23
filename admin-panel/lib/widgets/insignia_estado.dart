import 'package:flutter/material.dart';

import '../core/formato.dart';

/// Etiqueta de color para valores de estado y situacion (ACTIVO, PENDIENTE, RECHAZADO, etc.).
class InsigniaEstado extends StatelessWidget {
  final String valor;

  const InsigniaEstado(this.valor, {super.key});

  static const _exito = {'ACTIVO', 'APROBADO', 'APROBADA', 'COMPLETADO', 'RESUELTO', 'ATENDIDA', 'ACEPTADA'};
  static const _alerta = {'PENDIENTE', 'EN_REVISION', 'CON_OFERTAS', 'EN_CURSO'};
  static const _peligro = {'INACTIVO', 'RECHAZADO', 'RECHAZADA', 'SUSPENDIDO', 'CANCELADO', 'CANCELADA', 'VENCIDA'};

  @override
  Widget build(BuildContext context) {
    final (fondo, texto) = switch (valor) {
      _ when _exito.contains(valor) => (const Color(0xFF198754), Colors.white),
      _ when _alerta.contains(valor) => (const Color(0xFFFFC107), const Color(0xFF212529)),
      _ when _peligro.contains(valor) => (const Color(0xFFDC3545), Colors.white),
      _ => (const Color(0xFF6C757D), Colors.white),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(6)),
      child: Text(
        Formato.enumTexto(valor),
        style: TextStyle(color: texto, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
