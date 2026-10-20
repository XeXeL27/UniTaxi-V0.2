import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http_parser/http_parser.dart';
import 'package:provider/provider.dart';

import '../core/api_excepcion.dart';
import '../core/carnet/lector_documentos.dart';
import '../core/cliente_api.dart';
import '../core/formato.dart';
import '../core/iconos.dart';
import '../core/sesion.dart';
import '../core/tema.dart';
import '../widgets/boton_principal.dart';
import '../widgets/dialogos.dart';
import 'selector_carnet.dart';
import 'selfie_carnet.dart';

/// Cuenta que ya usaba la app y le falta algo del carnet (UsuarioSesion.carnetPendiente):
/// - SELFIE: solo su foto sosteniendo el carnet. Tiene un plazo; si no la sube a tiempo su cuenta se
///   suspende hasta que un administrador la habilite. Puede dejarla para despues ("Mas tarde").
/// - CARNET: no tiene las fotos de su carnet: anverso, reverso y la foto con el carnet (con plazo).
/// - VENCIDO: su carnet vencio. No pide viajes ni recibe solicitudes hasta subir las fotos del carnet
///   nuevo y la foto con el carnet (el servidor lo frena); se le pide cada vez que abre la app.
/// Los datos deben ser los que ya tiene registrados (POST /api/cuenta/carnet/actualizar). Si el servidor
/// no puede revisar la foto o la cara no se parece, la cuenta queda en revision del administrador.
/// En SELFIE la foto se revisa al tomarla contra el anverso guardado (/api/cuenta/carnet/revisar-selfie).
/// Si el servidor ya no tiene las fotos del carnet, cualquier error vuelve a consultar la cuenta: pasa a
/// CARNET y la pantalla muestra el anverso y el reverso para tomarlos de nuevo.
class PantallaFotoConCarnet extends StatefulWidget {
  const PantallaFotoConCarnet({super.key});

  @override
  State<PantallaFotoConCarnet> createState() => _PantallaFotoConCarnetState();
}

class _PantallaFotoConCarnetState extends State<PantallaFotoConCarnet> {
  SeleccionCarnet _carnet = const SeleccionCarnet();
  SeleccionSelfie _selfie = const SeleccionSelfie();
  bool _enviando = false;
  String? _error;

  /// La pantalla empezo pidiendo solo la foto con el carnet y el servidor ya no tenia las fotos del carnet.
  bool _fotosPerdidas = false;

  /// Vuelve a consultar la cuenta tras un error: si el servidor ya no tiene las fotos del carnet,
  /// carnetPendiente pasa de SELFIE a CARNET y la pantalla muestra el anverso y el reverso.
  Future<void> _actualizarCuenta() async {
    final sesion = context.read<Sesion>();
    final antes = sesion.usuario?.carnetPendiente;
    try {
      final json = await context.read<ClienteApi>().get('/api/cuenta/yo') as Map<String, dynamic>;
      if (!mounted) return;
      final ahora = json['carnetPendiente'] as String?;
      if (antes == 'SELFIE' && ahora != null && ahora != 'SELFIE') {
        setState(() {
          _fotosPerdidas = true;
          _error = null;
        });
      }
      if (ahora != antes) await sesion.reemplazarUsuario(json);
    } catch (_) {
      // Sin conexion queda el error que ya se mostro.
    }
  }

  /// Revisa la foto con el carnet contra el anverso que el servidor ya tiene guardado.
  Future<LecturaSelfie?> _revisarConAnversoGuardado(Uint8List foto) async {
    final Map<String, dynamic> datos;
    try {
      datos = await context.read<ClienteApi>().enviarFormulario('/api/cuenta/carnet/revisar-selfie', const {}, [
        (campo: 'selfie', bytes: foto, nombre: 'carnet_selfie.jpg', tipo: MediaType('image', 'jpeg')),
      ]) as Map<String, dynamic>;
    } on ApiExcepcion catch (e) {
      // Sin respuesta del servidor la revisa al enviarla; un rechazo puede ser que falten las fotos del carnet.
      if (e.codigo == null) return null;
      unawaited(_actualizarCuenta());
      rethrow;
    }
    return datos['disponible'] == true ? LecturaSelfie.json(datos) : null;
  }

  Future<void> _enviar(UsuarioSesion usuario) async {
    final conCarnet = usuario.carnetPendiente != 'SELFIE';
    if (conCarnet && !_carnet.completa) {
      setState(() => _error = 'Agrega la foto del anverso y del reverso de tu carnet.');
      return;
    }
    if (_selfie.foto == null) {
      setState(() => _error = 'Tómate la foto sosteniendo tu carnet junto a tu cara.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    final sesion = context.read<Sesion>();
    try {
      final json = await context.read<ClienteApi>().enviarFormulario('/api/cuenta/carnet/actualizar', const {}, [
        if (conCarnet) ...[
          (campo: 'anverso', bytes: _carnet.anverso!, nombre: 'carnet_anverso.jpg', tipo: MediaType('image', 'jpeg')),
          (campo: 'reverso', bytes: _carnet.reverso!, nombre: 'carnet_reverso.jpg', tipo: MediaType('image', 'jpeg')),
        ],
        (campo: 'selfie', bytes: _selfie.foto!, nombre: 'carnet_selfie.jpg', tipo: MediaType('image', 'jpeg')),
      ]) as Map<String, dynamic>;
      if (!mounted) return;
      final enRevision = json['carnetObservado'] == true;
      await mostrarExito(
        context,
        titulo: '¡Gracias!',
        mensaje: enRevision
            ? 'Recibimos tu foto. Un administrador la revisará; te avisaremos cuando puedas seguir usando UNITAXI.'
            : json['carnetPendiente'] == 'VENCIDO'
            ? 'Recibimos tu foto, pero tu carnet está vencido: ahora toma las fotos de tu carnet nuevo.'
            : 'Recibimos tu foto con el carnet.',
      );
      // La app pasa sola a la pantalla que corresponde (inicio, revision o carnet vencido).
      await sesion.reemplazarUsuario(json);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
      if (mounted && e.codigo != null) await _actualizarCuenta();
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<Sesion>().usuario!;
    final pendiente = usuario.carnetPendiente;
    final vencido = pendiente == 'VENCIDO';
    final conCarnet = pendiente != 'SELFIE';
    final plazo = usuario.plazoSelfie;
    final nombre = usuario.primerNombre;
    final String titulo;
    final String texto;
    if (vencido) {
      titulo = 'Tu carnet venció';
      texto =
          '${usuario.carnetVencimiento == null ? 'Tu carnet ya no está vigente' : 'Tu carnet venció el ${formatoFecha(usuario.carnetVencimiento)}'}. '
          'Para seguir pidiendo viajes o recibiendo solicitudes toma una foto de cada lado de tu carnet nuevo y una '
          'foto tuya sosteniéndolo junto a tu cara.';
    } else {
      titulo = nombre.isEmpty ? 'Tómate una foto con tu carnet' : '$nombre, tómate una foto con tu carnet';
      texto =
          'Para cuidar a todos en UNITAXI ahora pedimos ${conCarnet ? 'las fotos de tu carnet y ' : ''}una foto tuya '
          'sosteniendo tu carnet (el lado con tu foto) junto a tu cara. Deben verse tu cara y el número del carnet.';
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: BarraSistema.sobreClaro,
      child: Scaffold(
        backgroundColor: ColoresApp.blanco,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: ColoresApp.tinta,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(texto, style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 14.5, height: 1.45)),
                    if (!vencido && plazo != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Iconos.clock, color: ColoresApp.rutaSecundariaBorde, size: 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tienes hasta el ${formatoFecha(plazo)} a las '
                                '${plazo.hour.toString().padLeft(2, '0')}:${plazo.minute.toString().padLeft(2, '0')}. '
                                'Si no la subes, tu cuenta se suspenderá hasta que la administración la habilite.',
                                style: const TextStyle(color: ColoresApp.rutaSecundariaBorde, fontSize: 13.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (conCarnet && _fotosPerdidas) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Iconos.circleExclamation, color: ColoresApp.rutaSecundariaBorde, size: 16),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No encontramos las fotos de tu carnet. Tómalas de nuevo: el anverso, el reverso '
                                'y tu foto con el carnet.',
                                style: TextStyle(color: ColoresApp.rutaSecundariaBorde, fontSize: 13.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (conCarnet) ...[
                      SelectorCarnet(onCambio: (carnet) => setState(() {
                        _carnet = carnet;
                        _error = null;
                      })),
                      const SizedBox(height: 12),
                    ],
                    SelectorSelfieCarnet(
                      anverso: conCarnet ? _carnet.anverso : null,
                      necesitaAnverso: conCarnet,
                      // Sin fotos nuevas del carnet se revisa contra el anverso que el servidor ya tiene.
                      revisarCon: conCarnet ? null : _revisarConAnversoGuardado,
                      onCambio: (selfie) => setState(() {
                        _selfie = selfie;
                        _error = null;
                      }),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ColoresApp.rojoSuave,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Iconos.circleExclamation, color: ColoresApp.rojo, size: 16),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_error!, style: const TextStyle(color: ColoresApp.rojoOscuro))),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    BotonPrincipal(
                      texto: 'Enviar',
                      color: ColoresApp.tinta,
                      cargando: _enviando,
                      onPressed: () => _enviar(usuario),
                    ),
                    const SizedBox(height: 10),
                    // Con el carnet vencido tambien entra (por ejemplo, para terminar un viaje en curso), pero el
                    // servidor no le deja pedir viajes ni recibir solicitudes.
                    TextButton(
                      onPressed: _enviando ? null : context.read<Sesion>().postergarFotoCarnet,
                      child: const Text('Más tarde', style: TextStyle(color: ColoresApp.grisTexto)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
