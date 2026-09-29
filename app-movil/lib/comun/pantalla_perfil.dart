import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/cliente_api.dart';
import '../core/tema.dart';
import '../widgets/foto_perfil.dart';
import 'datos_perfil.dart';
import 'perfil_api.dart';

/// Mi perfil, igual para pasajero y conductor: la foto (galeria o camara) y los datos, que se
/// editan en el mismo lugar confirmando con la contrasena (ver [DatosPerfil]).
class PantallaPerfil extends StatefulWidget {
  final bool esConductor;

  const PantallaPerfil({super.key, required this.esConductor});

  @override
  State<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends State<PantallaPerfil> {
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

  void _recargar() => setState(() => _perfil = _api.perfil());

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
          if (instantanea.hasError) {
            return Center(
              child: TextButton(
                onPressed: _recargar,
                child: Text('${instantanea.error}. Toca para reintentar'),
              ),
            );
          }
          final perfil = instantanea.data;
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
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: DatosPerfil(perfil: perfil, esConductor: widget.esConductor, alGuardar: _recargar),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
