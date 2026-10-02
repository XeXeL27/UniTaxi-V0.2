import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../core/iconos.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../widgets/foto_usuario.dart';
import '../personas/modelos.dart';
import 'expediente_api.dart';
import 'modal_carnet.dart';
import 'modelos.dart';
import 'vista_expediente.dart';

/// Expediente del pasajero: todo lo que el ve en su app (datos, foto, favoritos, viajes y las
/// calificaciones que dio), con la moderacion de sus comentarios.
class ExpedientePasajero extends StatelessWidget {
  final ExpedienteApi api;
  final PasajeroAdmin pasajero;
  final VoidCallback alCambiar;

  const ExpedientePasajero({super.key, required this.api, required this.pasajero, required this.alCambiar});

  @override
  Widget build(BuildContext context) {
    final id = pasajero.idPasajero;
    return Carga<PerfilExpediente>(
      cargar: () => api.perfilPasajero(id),
      builder: (perfil, _) => MarcoExpediente(
        foto: FotoUsuario(nombre: perfil.nombreCompleto, radio: 30, color: ColoresApp.rojo, cargar: () => api.foto(perfil.idUsuario)),
        titulo: perfil.nombreCompleto,
        subtitulo: 'Pasajero  |  usuario ${pasajero.nombreUsuario}',
        pestanas: const [
          (Iconos.idCard, 'Datos'),
          (Iconos.solidStar, 'Favoritos'),
          (Iconos.route, 'Viajes'),
          (Iconos.solidComments, 'Calificaciones dadas'),
        ],
        vistas: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SeccionExpediente(
                titulo: 'Datos personales',
                icono: Iconos.user,
                accion: BotonVerCarnet(api: api, idUsuario: perfil.idUsuario, nombre: perfil.nombreCompleto),
                child: DatosEnGrilla([
                  ('Nombres', perfil.nombres),
                  ('Apellidos', perfil.apellidos),
                  ('Carnet de identidad', perfil.ciCompleto),
                  ('Fecha de nacimiento', Formato.fecha(perfil.fechaNacimiento)),
                  ('Correo', perfil.correo),
                  ('Teléfono', perfil.telefono),
                  ('Usuario', pasajero.nombreUsuario),
                  ('Registrado', Formato.fechaHora(pasajero.fechaRegistro)),
                  ('Foto de perfil', perfil.tieneFoto ? 'Subida' : 'Sin foto'),
                  ('Calificación como pasajero', perfil.calificacionPromedio?.toStringAsFixed(2).replaceAll('.', ',')),
                ]),
              ),
            ],
          ),
          Carga<List<FavoritoExpediente>>(
            cargar: () => api.favoritos(id),
            builder: (favoritos, _) => _Favoritos(favoritos: favoritos),
          ),
          Carga<List<ViajeExpediente>>(
            cargar: () => api.viajesPasajero(id),
            builder: (viajes, _) => ListaViajes(viajes: viajes, mostrarPasajero: false),
          ),
          Carga<List<CalificacionExpediente>>(
            cargar: () => api.calificacionesDadas(id),
            builder: (calificaciones, recargar) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ListaCalificaciones(
                  api: api,
                  calificaciones: calificaciones,
                  mostrarEmisor: false,
                  recargar: () {
                    recargar();
                    alCambiar();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Favoritos extends StatelessWidget {
  final List<FavoritoExpediente> favoritos;

  const _Favoritos({required this.favoritos});

  @override
  Widget build(BuildContext context) {
    if (favoritos.isEmpty) return const Vacio('No tiene lugares favoritos.');
    final conPosicion = favoritos.where((f) => f.posicion != null).toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (conPosicion.isNotEmpty)
          Container(
            height: 280,
            margin: const EdgeInsets.only(bottom: 14),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RadiosApp.tarjeta),
              border: Border.all(color: ColoresApp.borde),
            ),
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: conPosicion.length == 1
                    ? null
                    : CameraFit.coordinates(
                        coordinates: [for (final f in conPosicion) f.posicion!],
                        padding: const EdgeInsets.all(50),
                      ),
                initialCenter: conPosicion.first.posicion!,
                initialZoom: 15,
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'taxiuap.admin'),
                MarkerLayer(
                  markers: [
                    for (final f in conPosicion)
                      Marker(
                        point: f.posicion!,
                        width: 34,
                        height: 34,
                        child: Tooltip(
                          message: f.nombre,
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: ColoresApp.rojo,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(Iconos.solidStar, color: Colors.white, size: 13),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        for (final f in favoritos)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ColoresApp.superficie,
              borderRadius: BorderRadius.circular(RadiosApp.control),
              border: Border.all(color: ColoresApp.borde),
            ),
            child: Row(
              children: [
                const Icon(Iconos.locationDot, color: ColoresApp.rojo, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.nombre, style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azul)),
                      Text(f.direccion, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
