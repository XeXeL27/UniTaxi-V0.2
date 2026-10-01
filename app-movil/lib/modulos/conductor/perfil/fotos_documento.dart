import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../comun/confirmar_identidad.dart';
import '../../../comun/perfil_api.dart';
import '../../../comun/selector_carnet.dart';
import '../../../core/api_excepcion.dart';
import '../../../core/carnet/lectura_licencia.dart';
import '../../../core/carnet/lector_documentos.dart';
import '../../../core/cliente_api.dart';
import '../../../core/formato.dart';
import '../../../core/tema.dart';
import '../../../widgets/boton_principal.dart';
import '../../../widgets/dialogos.dart';
import '../../../widgets/formatos.dart';
import 'documentos_api.dart';

/// Carnet o licencia del conductor en Mis documentos: se ven siempre (fotos del anverso y del
/// reverso) y se vuelven a tomar solo con un permiso del administrador, confirmando con la huella o
/// la contrasena.
class TarjetaFotosDocumento extends StatelessWidget {
  final DocumentoFoto documento;
  final String detalle;
  final bool tieneFotos;

  /// Con permiso vigente del administrador aparece "Cambiar fotos".
  final bool permitido;
  final VoidCallback alCambiar;

  const TarjetaFotosDocumento({
    super.key,
    required this.documento,
    required this.detalle,
    required this.tieneFotos,
    required this.permitido,
    required this.alCambiar,
  });

  bool get _esLicencia => documento == DocumentoFoto.licencia;

  @override
  Widget build(BuildContext context) {
    final titulo = _esLicencia ? 'Licencia de conducir' : 'Carnet de identidad';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: permitido ? ColoresApp.exito : ColoresApp.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FaIcon(
                _esLicencia ? FontAwesomeIcons.solidIdBadge : FontAwesomeIcons.idCard,
                color: ColoresApp.azul,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700),
                    ),
                    Text(detalle, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: tieneFotos ? () => _verFotos(context, titulo) : null,
                  icon: const FaIcon(FontAwesomeIcons.eye, size: 14),
                  label: Text(tieneFotos ? 'Ver fotos' : 'Sin fotos'),
                ),
              ),
              if (permitido) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: alCambiar,
                    style: FilledButton.styleFrom(backgroundColor: ColoresApp.exito),
                    icon: const FaIcon(FontAwesomeIcons.camera, size: 14),
                    label: const Text('Cambiar fotos'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _verFotos(BuildContext context, String titulo) {
    final api = DocumentosApi(context.read<ClienteApi>());
    Future<Uint8List?> cargar(String lado) => _esLicencia ? api.fotoLicencia(lado) : api.fotoCarnet(lado);
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        titulo,
                        style: const TextStyle(color: ColoresApp.azul, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                for (final lado in const ['anverso', 'reverso']) ...[
                  const SizedBox(height: 8),
                  Text(lado == 'anverso' ? 'Anverso' : 'Reverso', style: const TextStyle(color: ColoresApp.textoSuave)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FutureBuilder<Uint8List?>(
                      future: cargar(lado),
                      builder: (context, foto) {
                        if (foto.connectionState != ConnectionState.done) {
                          return const SizedBox(
                            height: 180,
                            child: Center(child: CircularProgressIndicator(color: ColoresApp.azul)),
                          );
                        }
                        final bytes = foto.data;
                        if (bytes == null) {
                          return const SizedBox(height: 80, child: Center(child: Text('No se pudo cargar la foto')));
                        }
                        return Image.memory(bytes, fit: BoxFit.contain);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Volver a tomar las fotos del carnet o de la licencia (con permiso del administrador). En el APK
/// se leen en el telefono: del carnet el CI y la fecha; de la licencia el numero, la categoria (solo
/// M), el vencimiento y el nombre, que debe ser el del conductor.
class PantallaCambiarFotos extends StatefulWidget {
  final DocumentoFoto documento;
  final Perfil perfil;

  const PantallaCambiarFotos({super.key, required this.documento, required this.perfil});

  @override
  State<PantallaCambiarFotos> createState() => _PantallaCambiarFotosState();
}

class _PantallaCambiarFotosState extends State<PantallaCambiarFotos> {
  SeleccionCarnet _seleccion = const SeleccionCarnet();
  final _numero = TextEditingController();
  final _complemento = TextEditingController();

  /// Nombre leido del carnet nuevo; solo se edita si el carnet no dejaba claro el corte.
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  DateTime? _fecha;
  bool _enviando = false;
  String? _error;

  /// Cambia para vaciar el selector cuando la persona dice que los datos leidos no son los suyos.
  int _intento = 0;

  bool get _esLicencia => widget.documento == DocumentoFoto.licencia;

  /// Nombre leido (o escrito y comparado) de las fotos nuevas del carnet; en la web, el de la cuenta.
  String get _nombreLeido =>
      _seleccion.datos != null ? '${_nombres.text.trim()} ${_apellidos.text.trim()}' : widget.perfil.nombreCompleto;

  @override
  void dispose() {
    _numero.dispose();
    _complemento.dispose();
    _nombres.dispose();
    _apellidos.dispose();
    super.dispose();
  }

  void _alCambiar(SeleccionCarnet seleccion) {
    setState(() {
      _seleccion = seleccion;
      _error = null;
      if (_esLicencia) {
        final datos = seleccion.licencia;
        if (datos == null) return;
        _numero.text = datos.numeroCompleto ?? '';
        _fecha = datos.vencimiento;
        _error = _problemaLicencia(datos);
      } else {
        final datos = seleccion.datos;
        if (datos == null) return;
        _numero.text = datos.ci ?? '';
        _complemento.text = datos.complemento ?? '';
        // Sin nombre leido se propone el de la cuenta; se compara con lo leido en las fotos.
        _nombres.text = (datos.nombres ?? widget.perfil.nombres).toUpperCase();
        _apellidos.text = (datos.apellidos ?? widget.perfil.apellidos).toUpperCase();
        _fecha = datos.fechaNacimiento;
        if (datos.ci != null && datos.ci != widget.perfil.ci) {
          _error = 'El número de este carnet (${datos.ci}) no es el de tu cuenta (${widget.perfil.ci ?? ''}).';
        }
      }
    });
  }

  String? _problemaLicencia(DatosLicencia datos) {
    if (datos.categoria != null && !datos.esMoto) {
      return 'Tu licencia es de categoría ${datos.categoria}. Por ahora solo aceptamos licencias de motocicleta (M).';
    }
    if (!datos.completa) return 'No pudimos leer bien tu licencia. Vuelve a tomar las fotos de frente y con buena luz.';
    if (datos.vencida) return 'Esta licencia venció el ${formatoFecha(datos.vencimiento)}.';
    final complementoCarnet = widget.perfil.complementoCi ?? '';
    if (datos.numero != widget.perfil.ci ||
        (datos.complemento != null &&
            complementoCarnet.isNotEmpty &&
            datos.complemento != complementoCarnet.toUpperCase())) {
      return 'El número de la licencia (${datos.numeroCompleto}) no coincide con tu carnet (${widget.perfil.ciCompleto}).';
    }
    if (!nombreCoincide(widget.perfil.nombreCompleto, datos)) {
      return 'El nombre de la licencia no coincide con el tuyo (${widget.perfil.nombreCompleto}).';
    }
    return null;
  }

  String _fechaJson(DateTime f) =>
      '${f.year.toString().padLeft(4, '0')}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

  Future<void> _guardar() async {
    if (!_seleccion.completa) {
      setState(() => _error = 'Agrega la foto del anverso y del reverso.');
      return;
    }
    if (_error != null) return;
    final numero = _numero.text.trim();
    if (!RegExp(r'^\d{5,10}(-[0-9A-Z]{2})?$').hasMatch(numero) || _fecha == null) {
      setState(
        () => _error = LectorDocumentos.puedeLeer
            ? 'No se leyeron todos los datos. Vuelve a tomar las fotos.'
            : 'Escribe el número y elige la fecha.',
      );
      return;
    }
    final problemaNombre = _esLicencia ? null : _seleccion.datos?.revisarNombreEscrito(_nombres.text, _apellidos.text);
    if (problemaNombre != null) {
      setState(() => _error = problemaNombre);
      return;
    }
    final confirmado = _esLicencia
        ? await confirmarNumeroLicencia(context, numero: numero, categoria: 'M', vence: _fecha, fotos: _seleccion)
        : await confirmarDatosCarnet(
                context,
                nombre: _nombreLeido,
                ci: numero,
                complemento: _complemento.text,
                fotos: _seleccion,
                // Ya es conductor: el cambio de fotos se hace con permiso del administrador.
                conObservado: false,
              ) ==
              RespuestaCarnet.confirma;
    if (!mounted) return;
    // "No": las fotos nuevas y lo leido se descartan y se vuelven a tomar.
    if (!confirmado) {
      setState(() {
        _intento++;
        _seleccion = const SeleccionCarnet();
        _numero.clear();
        _complemento.clear();
        _nombres.clear();
        _apellidos.clear();
        _fecha = null;
        _error = _esLicencia
            ? 'Vuelve a tomar las fotos del anverso y del reverso de tu licencia.'
            : 'Vuelve a tomar las fotos del anverso y del reverso de tu carnet.';
      });
      return;
    }
    final contrasena = await confirmarIdentidad(context, accion: 'cambiar las fotos');
    if (contrasena == null || !mounted) return;
    setState(() => _enviando = true);
    final api = DocumentosApi(context.read<ClienteApi>());
    try {
      if (_esLicencia) {
        await api.cambiarLicencia(
          {
            'numeroLicencia': numero,
            'categoriaLicencia': 'M',
            'vencimientoLicencia': _fechaJson(_fecha!),
            'password': contrasena,
          },
          _seleccion.anverso!,
          _seleccion.reverso!,
        );
      } else {
        await api.cambiarCarnet(
          {
            'ci': numero,
            'complementoCi': _complemento.text.trim().toUpperCase(),
            'fechaNacimiento': _fechaJson(_fecha!),
            // El nombre de las fotos nuevas reemplaza al anterior (en la web queda el de la cuenta).
            if (_seleccion.datos?.tieneNombre ?? false) ...{
              'nombres': _nombres.text.trim(),
              'apellidos': _apellidos.text.trim(),
            },
            'password': contrasena,
          },
          _seleccion.anverso!,
          _seleccion.reverso!,
        );
      }
      if (!mounted) return;
      await mostrarExito(
        context,
        titulo: '¡Fotos actualizadas!',
        mensaje: _esLicencia
            ? 'Guardamos las fotos nuevas de tu licencia.'
            : 'Guardamos las fotos nuevas de tu carnet.',
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha ?? (_esLicencia ? DateTime(hoy.year + 1) : DateTime(hoy.year - 25)),
      firstDate: _esLicencia ? hoy : DateTime(1920),
      lastDate: _esLicencia ? DateTime(hoy.year + 15) : hoy,
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  @override
  Widget build(BuildContext context) {
    final leido = LectorDocumentos.puedeLeer;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColoresApp.azul,
        foregroundColor: ColoresApp.blanco,
        title: Text(
          _esLicencia ? 'Fotos de tu licencia' : 'Fotos de tu carnet',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _esLicencia
                ? 'Toma una foto de cada lado de tu licencia de conducir (categoría M).'
                : 'Toma una foto de cada lado de tu carnet de identidad.',
            style: const TextStyle(color: ColoresApp.textoSuave),
          ),
          const SizedBox(height: 12),
          SelectorCarnet(key: ValueKey(_intento), documento: widget.documento, onCambio: _alCambiar),
          if (_seleccion.completa || !leido) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _numero,
              readOnly: leido,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _esLicencia ? 'Número de licencia' : 'Número de carnet',
                filled: leido,
                fillColor: ColoresApp.gris,
              ),
            ),
            // Si el nombre no se leyo solo o el carnet no dejaba claro donde terminan los nombres, la
            // persona lo escribe o acomoda.
            if (!_esLicencia && (_seleccion.datos?.nombresEditables ?? false)) ...[
              const SizedBox(height: 12),
              Text(
                avisoNombreCarnet(_seleccion.datos!),
                style: const TextStyle(
                  color: ColoresApp.rutaSecundariaBorde,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nombres,
                inputFormatters: Formatos.letras,
                decoration: const InputDecoration(labelText: 'Nombres'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apellidos,
                readOnly: !(_seleccion.datos?.apellidosEditables ?? false),
                inputFormatters: Formatos.letras,
                decoration: const InputDecoration(labelText: 'Apellidos'),
              ),
            ],
            if (!_esLicencia) ...[
              const SizedBox(height: 12),
              // En el APK el complemento sale de la foto, no se escribe.
              TextField(
                controller: _complemento,
                readOnly: leido,
                decoration: InputDecoration(
                  labelText: leido ? 'Complemento (se lee de la foto)' : 'Complemento (solo si tu carnet lo tiene)',
                  filled: leido,
                  fillColor: ColoresApp.gris,
                ),
              ),
            ],
            const SizedBox(height: 12),
            InkWell(
              onTap: leido ? null : _elegirFecha,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: _esLicencia ? 'Vence' : 'Fecha de nacimiento',
                  filled: leido,
                  fillColor: ColoresApp.gris,
                ),
                child: Text(_fecha == null ? '' : formatoFecha(_fecha)),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: ColoresApp.rojoSuave, borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: const TextStyle(color: ColoresApp.rojoOscuro)),
            ),
          ],
          const SizedBox(height: 18),
          BotonPrincipal(texto: 'Guardar fotos', cargando: _enviando, onPressed: _guardar),
        ],
      ),
    );
  }
}
