import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/cliente_api.dart';
import '../../core/menu.dart';
import '../../core/sesion.dart';
import '../../core/tema.dart';
import '../personas/personas_api.dart';

/// Resumen con totales; cada tarjeta lleva a su listado.
class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  late final PersonasApi _api = PersonasApi(context.read<ClienteApi>());
  late final Future<List<int>> _totales = Future.wait([
    _api.listarPersonas().then((l) => l.length),
    _api.listarUsuarios().then((l) => l.length),
    _api.listarPasajeros().then((l) => l.length),
    _api.listarConductores().then((l) => l.length),
  ]);

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<Sesion>().usuario;
    final tarjetas = [Menu.personas, Menu.usuarios, Menu.pasajeros, Menu.conductores];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bienvenido, ${usuario?.nombres ?? ''}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: ColoresApp.azul),
        ),
        const SizedBox(height: 4),
        const Text('Resumen general de UNITAXI', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 20),
        FutureBuilder<List<int>>(
          future: _totales,
          builder: (context, instantanea) => LayoutBuilder(
            builder: (context, restricciones) {
              final columnas = restricciones.maxWidth >= 1100 ? 4 : (restricciones.maxWidth >= 560 ? 2 : 1);
              final ancho = (restricciones.maxWidth - 16 * (columnas - 1)) / columnas;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (var i = 0; i < tarjetas.length; i++)
                    SizedBox(
                      width: ancho,
                      child: _TarjetaTotal(
                        item: tarjetas[i],
                        total: instantanea.hasError ? null : instantanea.data?[i],
                        error: instantanea.hasError,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TarjetaTotal extends StatelessWidget {
  final ItemMenu item;
  final int? total;
  final bool error;

  const _TarjetaTotal({required this.item, required this.total, required this.error});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.go(item.ruta),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: ColoresApp.rojo, width: 4)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: ColoresApp.azul, borderRadius: BorderRadius.circular(8)),
                child: FaIcon(item.icono, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.titulo, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 4),
                    error
                        ? const Text('Sin datos', style: TextStyle(color: ColoresApp.rojo))
                        : total == null
                        ? const SizedBox(width: 60, child: LinearProgressIndicator())
                        : Text(
                            '$total',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: ColoresApp.azul),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
