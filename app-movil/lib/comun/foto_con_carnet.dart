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

  /// El servidor rechazo los datos del carnet: se ofrece "Mis fotos estan bien, enviar a revision".
  bool _ofrecerRevision = false;

  /// Cambia para vaciar las fotos del carnet (la persona dijo que los datos leidos no son los suyos).
  int _versionCarnet = 0;

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

  /// Envia las fotos. Con las fotos del carnet la persona confirma antes los datos leidos: si su cuenta
  /// tiene otro dato o le falta uno, el servidor lo actualiza con el del carnet. [aRevision]: "Mis fotos estan
  /// bien, enviar a revision" (no se cambia nada y lo revisa un administrador).
  Future<void> _enviar(UsuarioSesion usuario, {bool aRevision = false}) async {
    final conCarnet = usuario.carnetPendiente != 'SELFIE';
    if (conCarnet && !_carnet.completa) {
      setState(() => _error = 'Agrega la foto del anverso y del reverso de tu carnet.');
      return;
    }
    if (_selfie.foto == null) {
      setState(() => _error = 'Tómate la foto sosteniendo tu carnet junto a tu cara.');
      return;
    }
    var confirma = false;
    final leidos = _carnet.datos;
    if (conCarnet && !aRevision && leidos?.ci != null) {
      final respuesta = await confirmarDatosCarnet(
        context,
        nombre: leidos!.nombreCompleto.isEmpty ? 'No se pudo leer' : leidos.nombreCompleto,
        ci: leidos.ci!,
        complemento: leidos.complemento,
        fechaNacimiento: leidos.fechaNacimiento,
        fotos: _carnet,
        aviso: 'Si tu cuenta tiene otro dato o le falta alguno, lo actualizaremos con el de tu carnet.',
        mensajeObservado:
            'Un administrador revisará tus fotos y corregirá tus datos. Mientras tanto no podrás pedir viajes ni '
            'recibir solicitudes; te avisaremos cuando esté listo.',
      );
      if (!mounted) return;
      if (respuesta == RespuestaCarnet.repetir) {
        setState(() {
          _carnet = const SeleccionCarnet();
          _versionCarnet++;
          _ofrecerRevision = false;
          _error = 'Vuelve a tomar las fotos del anverso y del reverso de tu carnet.';
        });
        return;
      }
      aRevision = respuesta == RespuestaCarnet.observado;
      confirma = respuesta == RespuestaCarnet.confirma;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    final sesion = context.read<Sesion>();
    try {
      final json = await context.read<ClienteApi>().enviarFormulario(
        '/api/cuenta/carnet/actualizar',
        {'confirmaDatos': confirma, 'observado': aRevision},
        [
          if (conCarnet) ...[
            (campo: 'anverso', bytes: _carnet.anverso!, nombre: 'carnet_anverso.jpg', tipo: MediaType('image', 'jpeg')),
            (campo: 'reverso', bytes: _carnet.reverso!, nombre: 'carnet_reverso.jpg', tipo: MediaType('image', 'jpeg')),
          ],
          (campo: 'selfie', bytes: _selfie.foto!, nombre: 'carnet_selfie.jpg', tipo: MediaType('image', 'jpeg')),
        ],
      ) as Map<String, dynamic>;
      if (!mounted) return;
      final enRevision = json['carnetObservado'] == true;
      final datosCambiados = json['nombres'] != usuario.nombres || json['apellidos'] != usuario.apellidos;
      await mostrarExito(
        context,
        titulo: '¡Gracias!',
        mensaje: enRevision
            ? 'Recibimos tus fotos. Un administrador las revisará; te avisaremos cuando puedas seguir usando UNITAXI.'
            : json['carnetPendiente'] == 'VENCIDO'
            ? 'Recibimos tu foto, pero tu carnet está vencido: ahora toma las fotos de tu carnet nuevo.'
            : datosCambiados
            ? 'Recibimos tus fotos y actualizamos tu cuenta con los datos de tu carnet.'
            : 'Recibimos tu foto con el carnet.',
      );
      // La app pasa sola a la pantalla que corresponde (inicio, revision o carnet vencido).
      await sesion.reemplazarUsuario(json);
    } on ApiExcepcion catch (e) {
      if (mounted) {
        setState(() {
          _error = e.mensaje;
          // Un dato que no coincide (por ejemplo, otro numero de carnet): lo puede revisar un administrador.
          _ofrecerRevision = conCarnet && !aRevision && e.codigo == 422;
        });
      }
      if (mounted && e.codigo != null) await _actualizarCuenta();
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _enviarARevision(UsuarioSesion usuario) async {
    final envia = await confirmarAccion(
      context,
      titulo: '¿Enviar tus fotos a revisión?',
      mensaje:
          'Un administrador comparará tus fotos con los datos de tu cuenta y los corregirá. Mientras tanto no '
          'podrás pedir viajes ni recibir solicitudes; te avisaremos cuando esté listo.',
      textoConfirmar: 'Sí, enviar a revisión',
      textoCancelar: 'Volver',
    );
    if (envia && mounted) await _enviar(usuario, aRevision: true);
  }

  /// "Mas tarde". Con 3 dias o menos de plazo ([plazoUrgente]) antes avisa en rojo que la cuenta se
  /// suspendera.
  Future<void> _masTarde(DateTime? plazoUrgente, {required bool conCarnet}) async {
    final sesion = context.read<Sesion>();
    if (plazoUrgente != null) {
      await mostrarErrorDialogo(
        context,
        titulo: 'Tu cuenta se suspenderá',
        mensaje: '${textoTiempoRestante(plazoUrgente)} para confirmar tus datos con '
            '${conCarnet ? 'las fotos de tu carnet' : 'tu foto con el carnet'}. Si no '
            '${conCarnet ? 'las subes' : 'la subes'} antes del ${formatoFecha(plazoUrgente)} a las ${_hora(plazoUrgente)}, '
            'tu cuenta se suspenderá hasta que la administración la habilite.',
      );
    }
    sesion.postergarFotoCarnet();
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<Sesion>().usuario!;
    final pendiente = usuario.carnetPendiente;
    final vencido = pendiente == 'VENCIDO';
    final conCarnet = pendiente != 'SELFIE';
    final plazo = usuario.plazoSelfie;
    // Con 3 dias o menos el aviso pasa a rojo y "Mas tarde" vuelve a advertir de la suspension.
    final urgente = !vencido && plazo != null && plazo.difference(DateTime.now()) <= const Duration(days: 3);
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
                    if (!vencido && plazo != null && urgente) ...[
                      const SizedBox(height: 14),
                      _AvisoPlazoUrgente(plazo: plazo, conCarnet: conCarnet),
                    ] else if (!vencido && plazo != null) ...[
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
                                'Tienes hasta el ${formatoFecha(plazo)} a las ${_hora(plazo)}. '
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
                      SelectorCarnet(
                        key: ValueKey(_versionCarnet),
                        onCambio: (carnet) => setState(() {
                          _carnet = carnet;
                          _error = null;
                          _ofrecerRevision = false;
                        }),
                      ),
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
                      if (_ofrecerRevision) ...[
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _enviando ? null : () => _enviarARevision(usuario),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ColoresApp.tinta,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Mis fotos están bien, enviar para que lo revise un administrador',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
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
                      onPressed: _enviando ? null : () => _masTarde(urgente ? plazo : null, conCarnet: conCarnet),
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

String _hora(DateTime fecha) => '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

/// "Te quedan 3 días", "Te queda 1 día" o "Te quedan menos de 24 horas" hasta [plazo].
String textoTiempoRestante(DateTime plazo, {DateTime? ahora}) {
  final falta = plazo.difference(ahora ?? DateTime.now());
  if (falta.inHours < 24) return 'Te quedan menos de 24 horas';
  final dias = falta.inDays;
  return dias == 1 ? 'Te queda 1 día' : 'Te quedan $dias días';
}

/// Aviso rojo del plazo cuando quedan 3 dias o menos.
class _AvisoPlazoUrgente extends StatelessWidget {
  final DateTime plazo;

  /// Faltan tambien las fotos del carnet (no solo la foto con el carnet).
  final bool conCarnet;

  const _AvisoPlazoUrgente({required this.plazo, required this.conCarnet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresApp.rojoSuave,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.rojo.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Iconos.triangleExclamation, color: ColoresApp.rojo, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${textoTiempoRestante(plazo)}: confirma tus datos con ${conCarnet ? 'las fotos' : 'tu foto'}',
                  style: const TextStyle(color: ColoresApp.rojoOscuro, fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${conCarnet ? 'Súbelas' : 'Súbela'} antes del ${formatoFecha(plazo)} a las ${_hora(plazo)} o tu cuenta '
                  'se suspenderá hasta que la administración la habilite.',
                  style: const TextStyle(color: ColoresApp.rojoOscuro, fontSize: 13.5, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
