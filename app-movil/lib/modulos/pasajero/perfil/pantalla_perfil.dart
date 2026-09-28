import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/cliente_api.dart';
import '../../../core/formato.dart';
import '../../../core/tema.dart';
import '../../../widgets/foto_perfil.dart';
import '../../../comun/perfil_api.dart';

/// Perfil del pasajero: foto (se puede cambiar cuando quiera) y sus datos.
class PantallaPerfilPasajero extends StatefulWidget {
  const PantallaPerfilPasajero({super.key});

  @override
  State<PantallaPerfilPasajero> createState() => _PantallaPerfilPasajeroState();
}

class _PantallaPerfilPasajeroState extends State<PantallaPerfilPasajero> {
  late final PerfilApi _api = PerfilApi(context.read<ClienteApi>());
  late Future<Perfil> _perfil = _api.perfil();
  Uint8List? _foto;

  @override
  void initState() {
    super.initState();
    _cargarFoto();
  }

  Future<void> _cargarFoto() async {
    try {
      final foto = await _api.foto();
      if (mounted) setState(() => _foto = foto);
    } catch (_) {
      // Sin foto quedan las iniciales.
    }
  }

  Future<void> _subir(Uint8List bytes, String nombre) async {
    await _api.subirFoto(bytes, nombre);
    await _cargarFoto();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColoresApp.azul,
        foregroundColor: ColoresApp.blanco,
        title: const Text('Mi perfil', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: FutureBuilder<Perfil>(
        future: _perfil,
        builder: (context, instantanea) {
          final perfil = instantanea.data;
          if (instantanea.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => setState(() => _perfil = _api.perfil()),
                child: Text('${instantanea.error}. Toca para reintentar'),
              ),
            );
          }
          if (perfil == null) return const Center(child: CircularProgressIndicator(color: ColoresApp.azul));
          return ListView(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                decoration: const BoxDecoration(
                  color: ColoresApp.azul,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    FotoPerfilEditable(nombre: perfil.nombreCompleto, foto: _foto, subir: _subir),
                    const SizedBox(height: 14),
                    Text(
                      perfil.nombreCompleto,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ColoresApp.blanco, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toca la cámara para cambiar tu foto',
                      style: TextStyle(color: ColoresApp.blanco.withValues(alpha: 0.75), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: _TarjetaDatos(
                  datos: [
                    (FontAwesomeIcons.idCard, 'Carnet de identidad', perfil.ciCompleto),
                    (
                      FontAwesomeIcons.cakeCandles,
                      'Fecha de nacimiento',
                      perfil.fechaNacimiento == null ? '' : formatoFechaHora(perfil.fechaNacimiento).split(' ').first,
                    ),
                    (FontAwesomeIcons.envelope, 'Correo', perfil.correo ?? ''),
                    (FontAwesomeIcons.phone, 'Teléfono', perfil.telefono ?? ''),
                    (
                      FontAwesomeIcons.solidStar,
                      'Tu calificación',
                      perfil.calificacionPromedio == null
                          ? ''
                          : '${perfil.calificacionPromedio!.toStringAsFixed(1).replaceAll('.', ',')} de 5',
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Para corregir tus datos comunícate con la administración de TaxiUAP.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Lista de datos con icono, en una tarjeta blanca.
class _TarjetaDatos extends StatelessWidget {
  final List<(FaIconData, String, String)> datos;

  const _TarjetaDatos({required this.datos});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: Column(
        children: [
          for (var i = 0; i < datos.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: ColoresApp.borde),
            ListTile(
              leading: SizedBox(width: 24, child: Center(child: FaIcon(datos[i].$1, color: ColoresApp.rojo, size: 17))),
              title: Text(datos[i].$2, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5)),
              subtitle: Text(
                datos[i].$3.isEmpty ? 'Sin dato' : datos[i].$3,
                style: TextStyle(
                  color: datos[i].$3.isEmpty ? ColoresApp.textoSuave : ColoresApp.texto,
                  fontSize: 15.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
