import 'dart:async';

import 'package:flutter/foundation.dart';

import 'preferencias_aviso.dart';
import 'sonido_movil.dart' if (dart.library.js_interop) 'sonido_web.dart' as plataforma;
import 'vibracion.dart';

/// Audios de aviso (assets/sonidos y, para las notificaciones, android/app/src/main/res/raw).
///
/// Los nombres de archivo no se reutilizan con otro audio: en Android el sonido de un canal de
/// notificacion queda fijo al crearlo y el canal lleva el nombre del archivo (`aviso_v3_<archivo>_...`).
enum SonidoAviso {
  /// Pasajero: un conductor o un repartidor acepto su viaje o su pedido (la moto encendiendo).
  /// Tambien al repartidor cuando el cliente acepta el costo de la compra.
  viajeAceptado('moto_encendiendo', Duration(milliseconds: 2770), 3),

  /// Taxista y repartidor: llego un servicio nuevo (taxi o delivery). Tambien al pasajero cuando tiene
  /// que revisar el costo de su compra.
  nuevoServicio('nuevo_servicio', Duration(milliseconds: 1490), 3),

  /// Pasajero: el conductor llego y lo espera (se repite con cada aviso del conductor).
  llegoTaxi('llego_taxi', Duration(milliseconds: 2040), 3),

  /// Pasajero al abrirse el cuadro para opinar y al entregarse su paquete; conductor al finalizar.
  viajeFinalizado('viaje_finalizado', Duration(milliseconds: 2040), 2),

  /// Pasajero: su solicitud se envio o el repartidor recogio su paquete (un "listo" corto).
  confirmacion('confirmacion', Duration(milliseconds: 470), 1),

  /// Mensaje nuevo del chat del viaje (cliente, conductor y repartidor).
  mensajeChat('mensaje_chat', Duration(milliseconds: 550), 1);

  /// Nombre del archivo sin extension (el mismo en assets y en res/raw).
  final String archivo;

  /// Cuanto dura el audio: mientras suena, otro aviso de menor [prioridad] no lo corta.
  final Duration duracion;

  /// Un aviso importante (aceptado, llego, servicio nuevo) no lo corta un mensaje del chat.
  final int prioridad;

  const SonidoAviso(this.archivo, this.duracion, this.prioridad);
}

/// Sonido de aviso: suena una sola vez, sin repetirse, y nunca dos a la vez.
///
/// - El mismo audio pedido mientras todavia suena no vuelve a empezar (la app y el push, o dos
///   consultas seguidas, avisan una vez).
/// - Un audio de menor prioridad no corta al que suena (un mensaje del chat no tapa la moto); uno
///   de igual o mayor prioridad lo corta y empieza.
class Sonido {
  static SonidoAviso? _actual;
  static DateTime _sonandoHasta = DateTime.fromMillisecondsSinceEpoch(0);

  /// Para los tests: reloj que se puede adelantar.
  @visibleForTesting
  static DateTime Function() reloj = DateTime.now;

  /// Para los tests: reemplaza al reproductor del telefono o del navegador.
  @visibleForTesting
  static Future<void> Function(String archivo) reproductor = plataforma.sonarAviso;

  /// Reproduce [sonido] sin mirar Perfil > Sonido y vibracion (lo usa [conVibracion]). Devuelve false
  /// si no sono porque otro aviso lo tapa.
  static bool _reproducir(SonidoAviso sonido) {
    final ahora = reloj();
    final actual = _actual;
    if (actual != null && ahora.isBefore(_sonandoHasta) && (actual == sonido || sonido.prioridad < actual.prioridad)) {
      return false;
    }
    _actual = sonido;
    _sonandoHasta = ahora.add(sonido.duracion);
    unawaited(reproductor(sonido.archivo));
    return true;
  }

  /// Todo aviso con sonido va con vibracion: el audio si el sonido esta encendido y los dos pulsos si
  /// la vibracion esta encendida (Perfil > Sonido y vibracion).
  static Future<void> conVibracion(SonidoAviso sonido) async {
    if (PreferenciasAviso.sonido.value) _reproducir(sonido);
    await Vibracion.corta();
  }

  @visibleForTesting
  static void reiniciar() {
    _actual = null;
    _sonandoHasta = DateTime.fromMillisecondsSinceEpoch(0);
  }
}
