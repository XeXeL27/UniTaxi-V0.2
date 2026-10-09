import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/iconos.dart';
import '../../../core/tema.dart';
import '../../../widgets/inicio_mapa.dart';

/// Lugar que se ofrece en el menu del inicio: un favorito guardado o un lugar frecuente.
class LugarMenu {
  final String nombre;
  final String detalle;
  final LatLng posicion;
  final bool favorito;

  const LugarMenu({required this.nombre, required this.detalle, required this.posicion, required this.favorito});
}

/// Menu desplegable de abajo en el inicio del pasajero (estilo Uber). Cerrado solo muestra el
/// saludo, el buscador "¿A dónde vas?" y el boton azul; abierto suben los lugares y los servicios
/// sin llenar la pantalla: el mapa queda libre arriba.
class MenuInicio extends StatelessWidget {
  /// Cuantos lugares se muestran como mucho: el menu no debe tapar el mapa.
  static const int maximoLugares = 3;

  final String saludo;

  /// Texto bajo el buscador con el menu cerrado (ubicacion pendiente o como abrir el menu).
  final String indicacion;
  final bool abierto;
  final VoidCallback onAlternar;
  final VoidCallback onBuscar;
  final List<LugarMenu> lugares;
  final ValueChanged<LugarMenu> onLugar;
  final VoidCallback onAnadirLugar;
  final VoidCallback onMotoTaxi;
  final VoidCallback onEntrega;

  /// Claves para la guia de inicio (el buscador y el boton azul).
  final Key? claveBuscador;
  final Key? claveBoton;

  const MenuInicio({
    super.key,
    required this.saludo,
    required this.indicacion,
    required this.abierto,
    required this.onAlternar,
    required this.onBuscar,
    required this.lugares,
    required this.onLugar,
    required this.onAnadirLugar,
    required this.onMotoTaxi,
    required this.onEntrega,
    this.claveBuscador,
    this.claveBoton,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(saludo, style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 15)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Material(
                key: claveBuscador,
                color: ColoresApp.gris,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: onBuscar,
                  borderRadius: BorderRadius.circular(16),
                  child: const SizedBox(
                    height: altoBarraDestino,
                    child: Row(
                      children: [
                        SizedBox(width: 16),
                        Icon(Iconos.magnifyingGlass, color: ColoresApp.tinta, size: 18),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '¿A dónde vas?',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ColoresApp.tinta,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: abierto ? 'Ocultar lugares y servicios' : 'Ver lugares y servicios',
              child: Material(
                key: claveBoton,
                color: ColoresApp.azul,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: onAlternar,
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: altoBarraDestino,
                    height: altoBarraDestino,
                    child: Center(
                      child: AnimatedRotation(
                        turns: abierto ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: const Icon(Iconos.chevronUp, color: ColoresApp.blanco, size: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: abierto ? _opciones() : _cerrado(),
        ),
      ],
    );
  }

  Widget _cerrado() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(indicacion, style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 13)),
  );

  Widget _opciones() {
    final visibles = lugares.take(maximoLugares).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, color: ColoresApp.borde),
          const SizedBox(height: 4),
          if (visibles.isEmpty)
            _FilaLugar(
              icono: Iconos.plus,
              titulo: 'Añadir un lugar',
              detalle: 'Guarda tu casa, la universidad o donde vayas seguido',
              onTap: onAnadirLugar,
            )
          else
            for (var i = 0; i < visibles.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 54, color: ColoresApp.borde),
              _FilaLugar(
                icono: visibles[i].favorito ? Iconos.solidStar : Iconos.clockRotateLeft,
                titulo: visibles[i].nombre,
                detalle: visibles[i].detalle,
                onTap: () => onLugar(visibles[i]),
              ),
            ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AccesoServicio(icono: Iconos.motorcycle, texto: 'Moto taxi', onTap: onMotoTaxi),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AccesoServicio(icono: Iconos.boxOpen, texto: 'Entrega', onTap: onEntrega),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilaLugar extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;

  const _FilaLugar({required this.icono, required this.titulo, required this.detalle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: ColoresApp.gris, shape: BoxShape.circle),
              child: Center(child: Icon(icono, color: ColoresApp.tinta, size: 15)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ColoresApp.tinta, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  if (detalle.isNotEmpty)
                    Text(
                      detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 13),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Moto taxi o Entrega en el menu del inicio.
class _AccesoServicio extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  const _AccesoServicio({required this.icono, required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColoresApp.gris,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, color: ColoresApp.azul, size: 22),
              const SizedBox(height: 8),
              Text(texto, style: const TextStyle(color: ColoresApp.tinta, fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Boton redondo blanco con sombra sobre el mapa (ayuda, volver).
class BotonRedondoMapa extends StatelessWidget {
  static const double tamano = 48;

  final IconData icono;
  final String tooltip;
  final VoidCallback onTap;

  const BotonRedondoMapa({super.key, required this.icono, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: ColoresApp.blanco,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: const Color(0x55000000),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: tamano,
            height: tamano,
            child: Center(child: Icon(icono, color: ColoresApp.tinta, size: 18)),
          ),
        ),
      ),
    );
  }
}

/// Foto de perfil redonda sobre el mapa: lleva a Perfil.
class BotonPerfilMapa extends StatelessWidget {
  final Uint8List? foto;
  final VoidCallback onTap;

  const BotonPerfilMapa({super.key, required this.foto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Tu perfil',
      child: Material(
        shape: const CircleBorder(side: BorderSide(color: ColoresApp.blanco, width: 2)),
        elevation: 4,
        shadowColor: const Color(0x55000000),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AvatarCabecera(foto: foto, iconoSinFoto: Iconos.solidUser, tamano: BotonRedondoMapa.tamano),
        ),
      ),
    );
  }
}
