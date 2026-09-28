import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_excepcion.dart';
import '../../../core/cliente_api.dart';
import '../../../core/formato.dart';
import '../../../core/tema.dart';
import '../../../widgets/pagina_seccion.dart';
import '../../../widgets/paneles.dart';
import '../viaje/conductor_api.dart';

/// Seccion Comentarios de la barra inferior: calificaciones que el conductor recibio de sus pasajeros.
class PantallaComentarios extends StatefulWidget {
  const PantallaComentarios({super.key});

  @override
  State<PantallaComentarios> createState() => PantallaComentariosState();
}

class PantallaComentariosState extends State<PantallaComentarios> {
  late final ConductorApi _api = ConductorApi(context.read<ClienteApi>());
  CalificacionesRecibidas? _datos;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Vuelve a consultar al entrar a la seccion (pudo llegar una calificacion nueva).
  Future<void> recargar() => _cargar();

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final datos = await _api.calificaciones();
      if (mounted) setState(() => _datos = datos);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final datos = _datos;
    return PaginaSeccion(
      titulo: 'Comentarios',
      subtitulo: 'Lo que opinan tus pasajeros',
      constructor: (context, relleno) => _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: ColoresApp.rojo)))
          : datos == null
          ? const Center(child: CircularProgressIndicator(color: ColoresApp.azul))
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: relleno,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: ColoresApp.azul, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Text(
                          datos.promedio.toStringAsFixed(1).replaceAll('.', ','),
                          style: const TextStyle(color: ColoresApp.blanco, fontSize: 44, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Estrellas(valor: datos.promedio, tamano: 20),
                              const SizedBox(height: 6),
                              Text(
                                datos.total == 1 ? '1 calificación' : '${datos.total} calificaciones',
                                style: TextStyle(color: ColoresApp.blanco.withValues(alpha: 0.8)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (datos.calificaciones.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 30),
                      child: Text(
                        'Todavía no recibiste calificaciones.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ColoresApp.textoSuave),
                      ),
                    ),
                  for (final calificacion in datos.calificaciones)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TarjetaComentario(calificacion: calificacion),
                    ),
                ],
              ),
            ),
    );
  }
}

class _TarjetaComentario extends StatelessWidget {
  final CalificacionRecibida calificacion;

  const _TarjetaComentario({required this.calificacion});

  @override
  Widget build(BuildContext context) {
    final positiva = calificacion.puntuacion >= 4;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarIniciales(nombre: calificacion.nombrePasajero, radio: 18, color: ColoresApp.textoSuave),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      calificacion.nombrePasajero,
                      style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      formatoFechaHora(calificacion.fecha),
                      style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Estrellas(valor: calificacion.puntuacion.toDouble(), tamano: 14),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            calificacion.comentario ?? 'Sin comentario',
            style: TextStyle(
              color: calificacion.comentario == null ? ColoresApp.textoSuave : ColoresApp.texto,
              fontStyle: calificacion.comentario == null ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          if (calificacion.etiquetas.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final etiqueta in calificacion.etiquetas)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: positiva ? ColoresApp.azulSuave : ColoresApp.rojoSuave,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      etiqueta,
                      style: TextStyle(color: positiva ? ColoresApp.azul : ColoresApp.rojoOscuro, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
