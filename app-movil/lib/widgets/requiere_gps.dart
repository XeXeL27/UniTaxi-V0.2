import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../core/iconos.dart';
import '../core/navegador.dart';
import '../core/tema.dart';
import 'boton_principal.dart';

/// [aproximada]: Android 12+ con el permiso de "ubicacion aproximada" (un punto a 1-3 km de donde
/// esta la persona): no sirve para marcar la partida ni para seguir al conductor.
enum _EstadoGps { verificando, listo, apagado, sinPermiso, bloqueado, aproximada }

/// Exige la ubicacion encendida y con permiso para usar la app (pasajero y conductor). Mientras
/// falte, una pantalla tapa todo con el boton para activarla; la vista de abajo sigue viva, asi un
/// viaje en curso no se pierde. Se vuelve a revisar al encender o apagar el GPS, al volver a la app
/// y, mientras falte, cada pocos segundos.
class RequiereGps extends StatefulWidget {
  final Widget child;

  /// true mientras el GPS esta encendido y con permiso (la pantalla de activarlo no tapa nada).
  /// La guia de inicio espera a que lo este.
  static final listo = ValueNotifier<bool>(false);

  const RequiereGps({super.key, required this.child});

  @override
  State<RequiereGps> createState() => _RequiereGpsState();
}

class _RequiereGpsState extends State<RequiereGps> with WidgetsBindingObserver {
  _EstadoGps _estado = _EstadoGps.verificando;
  StreamSubscription<ServiceStatus>? _servicio;
  Timer? _reintento;
  Timer? _inicio;
  bool _pidiendo = false;

  /// Ya se le pidio la ubicacion precisa y siguio la aproximada: el boton abre los ajustes de la app.
  bool _precisaPedida = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      try {
        _servicio = Geolocator.getServiceStatusStream().listen((_) => _verificar());
      } catch (_) {
        // Sin el aviso del sistema basta con revisar al volver a la app y cada pocos segundos.
      }
    }
    // El permiso se pide ya con la pantalla principal a la vista (no encima del login que se esta
    // cerrando): despues del primer cuadro y una pausa corta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inicio = Timer(const Duration(milliseconds: 700), () {
        if (mounted) _verificar(pedir: true);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _servicio?.cancel();
    _reintento?.cancel();
    _inicio?.cancel();
    RequiereGps.listo.value = false;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _estado != _EstadoGps.verificando) _verificar();
  }

  Future<void> _verificar({bool pedir = false}) async {
    if (_pidiendo) return;
    _EstadoGps nuevo;
    var reintentarPidiendo = false;
    try {
      // Primero el permiso (Android lo pregunta aunque el GPS este apagado) y despues el GPS: asi
      // el servicio de ubicacion del conductor ya tiene permiso cuando la persona enciende el GPS.
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied && pedir) {
        _pidiendo = true;
        try {
          permiso = await Geolocator.requestPermission();
        } finally {
          _pidiendo = false;
        }
      }
      nuevo = switch (permiso) {
        LocationPermission.always || LocationPermission.whileInUse => _EstadoGps.listo,
        LocationPermission.deniedForever => _EstadoGps.bloqueado,
        _ => _EstadoGps.sinPermiso,
      };
      if (nuevo == _EstadoGps.listo && !kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
        nuevo = _EstadoGps.apagado;
      }
      if (nuevo == _EstadoGps.listo && !kIsWeb && await _soloAproximada()) {
        nuevo = _EstadoGps.aproximada;
      }
    } catch (_) {
      // El navegador sin soporte de ubicacion no bloquea la app. En el telefono el error suele ser
      // que otro permiso se estaba preguntando (por ejemplo el de notificaciones): se vuelve a pedir.
      if (kIsWeb) {
        nuevo = _EstadoGps.listo;
      } else {
        nuevo = _EstadoGps.sinPermiso;
        reintentarPidiendo = true;
      }
    }
    if (!mounted) return;
    setState(() => _estado = nuevo);
    RequiereGps.listo.value = nuevo == _EstadoGps.listo;
    _reintento?.cancel();
    if (nuevo != _EstadoGps.listo) {
      _reintento = Timer(const Duration(seconds: 3), () => _verificar(pedir: reintentarPidiendo));
    }
  }

  /// Android 12+ deja dar solo la ubicacion aproximada. Si no se puede saber, se sigue como antes.
  Future<bool> _soloAproximada() async {
    try {
      return await Geolocator.getLocationAccuracy() == LocationAccuracyStatus.reduced;
    } catch (_) {
      return false;
    }
  }

  /// Pide pasar a la ubicacion precisa (Android muestra "Cambiar a ubicacion precisa"). Si la persona
  /// ya la nego, Android no vuelve a preguntar: entonces se abren los ajustes de la app.
  Future<void> _pedirPrecisa() async {
    if (_precisaPedida) {
      try {
        await Geolocator.openAppSettings();
      } catch (_) {}
      return;
    }
    _pidiendo = true;
    try {
      await Geolocator.requestPermission();
    } catch (_) {
      // Otro permiso se estaba preguntando: se intenta de nuevo con el boton.
    } finally {
      _pidiendo = false;
    }
    await _verificar();
    if (mounted && _estado == _EstadoGps.aproximada) setState(() => _precisaPedida = true);
  }

  Future<void> _activar() async {
    switch (_estado) {
      case _EstadoGps.aproximada:
        await _pedirPrecisa();
      case _EstadoGps.apagado:
        // Algunos telefonos no tienen la pantalla de ubicacion directa: entonces los ajustes de la app.
        var abierto = false;
        try {
          abierto = await Geolocator.openLocationSettings();
        } catch (_) {}
        if (!abierto) {
          try {
            await Geolocator.openAppSettings();
          } catch (_) {}
        }
      case _EstadoGps.sinPermiso:
        await _verificar(pedir: true);
      case _EstadoGps.bloqueado:
        if (kIsWeb) {
          // Firefox y Chrome no vuelven a preguntar en la misma pagina: al recargar toman el permiso
          // que la persona cambio en el icono de la barra de direcciones.
          Navegador.recargar();
        } else {
          try {
            await Geolocator.openAppSettings();
          } catch (_) {}
        }
      case _EstadoGps.verificando || _EstadoGps.listo:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloquea = _estado != _EstadoGps.listo && _estado != _EstadoGps.verificando;
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (bloquea)
          Positioned.fill(
            child: AnnotatedRegion<SystemUiOverlayStyle>(value: BarraSistema.sobreClaro, child: _pantalla()),
          ),
      ],
    );
  }

  Widget _pantalla() {
    final (titulo, texto, boton) = switch (_estado) {
      _EstadoGps.aproximada when _precisaPedida => (
        'Activa la ubicación precisa',
        'Tu celular le da a UNITAXI solo una ubicación aproximada, que puede estar a más de un '
            'kilómetro de donde estás. En los ajustes de la app, en Permisos > Ubicación, activa '
            '"Usar ubicación precisa".',
        'Abrir ajustes',
      ),
      _EstadoGps.aproximada => (
        'Activa la ubicación precisa',
        'Tu celular le da a UNITAXI solo una ubicación aproximada, que puede estar a más de un '
            'kilómetro de donde estás. Para que el conductor llegue al lugar correcto, permite la '
            'ubicación precisa.',
        'Permitir ubicación precisa',
      ),
      _EstadoGps.apagado => (
        'Activa tu ubicación',
        'UNITAXI necesita el GPS de tu celular encendido para ubicarte en el mapa y conectarte con '
            'el taxi. Enciéndelo para continuar.',
        'Activar ubicación',
      ),
      _EstadoGps.bloqueado when kIsWeb => (
        'Permite tu ubicación',
        'El navegador tiene bloqueada la ubicación para UNITAXI. Haz clic en el icono de ubicación '
            '(tachado) o del candado junto a la dirección de la página, quita el bloqueo o elige Permitir, '
            'y recarga la página.',
        'Recargar la página',
      ),
      _EstadoGps.bloqueado => (
        'Permite tu ubicación',
        'Negaste el permiso de ubicación. Ábrelo en los ajustes de la app, en Permisos > Ubicación, '
            'y elige "Permitir mientras se usa la app".',
        'Abrir ajustes',
      ),
      _ => (
        'Permite tu ubicación',
        'UNITAXI necesita saber dónde estás para mostrarte en el mapa y conectarte con el taxi.',
        'Permitir ubicación',
      ),
    };
    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(color: ColoresApp.rojoSuave, shape: BoxShape.circle),
          child: const Center(
            child: Icon(Iconos.locationDot, color: ColoresApp.rojo, size: 40),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(color: ColoresApp.azul, fontSize: 23, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 28),
        BotonPrincipal(texto: boton, onPressed: _activar),
      ],
    );
    // En el navegador el mapa se sigue viendo atras, oscurecido, con el aviso en una tarjeta.
    if (kIsWeb) {
      return Material(
        color: Colors.black54,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(color: ColoresApp.blanco, borderRadius: BorderRadius.circular(20)),
                  child: contenido,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Material(
      color: ColoresApp.fondo,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: contenido),
          ),
        ),
      ),
    );
  }
}
