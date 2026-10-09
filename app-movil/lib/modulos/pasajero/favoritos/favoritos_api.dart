import 'package:flutter/widgets.dart' show IconData;
import 'package:latlong2/latlong.dart';

import '../../../core/cliente_api.dart';
import '../../../core/iconos.dart';
import '../../../mapa/servicios_mapa.dart';

/// Lugar favorito del pasajero (direccion_guardada).
class Favorito {
  final int id;
  final String nombre;
  final String direccion;
  final LatLng? posicion;

  const Favorito({required this.id, required this.nombre, required this.direccion, this.posicion});

  factory Favorito.desdeJson(Map<String, dynamic> json) => Favorito(
    id: (json['id'] as num).toInt(),
    nombre: json['nombre'] as String? ?? '',
    direccion: json['direccion'] as String? ?? '',
    posicion: puntoDesdeWkt(json['ubicacionWkt'] as String?),
  );

  /// Icono segun el nombre: casa, trabajo o estudio, terminal; si no, un marcador.
  IconData get icono {
    final n = nombre.toLowerCase();
    if (n.contains('casa') || n.contains('hogar') || n.contains('depa')) return Iconos.house;
    if (n.contains('trabajo') || n.contains('oficina')) return Iconos.briefcase;
    if (n.contains('universidad') || n.contains('uap') || n.contains('facultad') || n.contains('colegio')) {
      return Iconos.graduationCap;
    }
    if (n.contains('terminal') || n.contains('aeropuerto')) return Iconos.bus;
    if (n.contains('mercado') || n.contains('tienda')) return Iconos.basketShopping;
    if (n.contains('hospital') || n.contains('clinica') || n.contains('clínica')) return Iconos.hospital;
    return Iconos.locationDot;
  }
}

/// Endpoints de /api/pasajero/direcciones.
class FavoritosApi {
  final ClienteApi cliente;

  FavoritosApi(this.cliente);

  Future<List<Favorito>> listar() => cliente.lista('/api/pasajero/direcciones', Favorito.desdeJson);

  Future<Favorito> crear({required String nombre, required String direccion, required LatLng posicion}) async {
    final datos = await cliente.post('/api/pasajero/direcciones', {
      'nombre': nombre.trim(),
      'direccion': direccion.trim(),
      'ubicacionWkt': wktDesdePunto(posicion),
    });
    return Favorito.desdeJson(datos as Map<String, dynamic>);
  }

  /// Borrado logico en el backend.
  Future<void> eliminar(int id) => cliente.delete('/api/pasajero/direcciones/$id');
}
