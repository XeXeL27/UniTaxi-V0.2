import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_excepcion.dart';
import '../core/carnet/lector_documentos.dart';
import '../core/carnet/lectura_carnet.dart';
import '../core/carnet/lectura_licencia.dart';
import '../core/carnet/ocr_carnet.dart';
import '../core/tema.dart';
import '../widgets/dialogos.dart';
import 'editor_foto.dart';

/// Documento que se fotografia: el carnet de identidad o la licencia de conducir.
enum DocumentoFoto { carnet, licencia }

/// Fotos del carnet (o de la licencia) elegidas y lo que se leyo de ellas.
class SeleccionCarnet {
  final Uint8List? anverso;
  final Uint8List? reverso;

  /// Datos del carnet leidos de las dos fotos; null mientras falte una, si no hay lector (web) o
  /// si es una licencia.
  final DatosCarnet? datos;

  /// Datos de la licencia leidos de las dos fotos (solo con [DocumentoFoto.licencia]).
  final DatosLicencia? licencia;

  /// Texto leido de cada foto (para comparar el nombre de la licencia con el del carnet).
  final String? textoAnverso;
  final String? textoReverso;

  /// Los datos los leyo el servidor (Gemini) y no el lector del telefono: el numero ya es el correcto
  /// y no hace falta volver a buscarlo en el texto.
  final bool delServidor;

  const SeleccionCarnet({
    this.anverso,
    this.reverso,
    this.datos,
    this.licencia,
    this.textoAnverso,
    this.textoReverso,
    this.delServidor = false,
  });

  bool get completa => anverso != null && reverso != null;

  String get texto => '${textoAnverso ?? ''}\n${textoReverso ?? ''}';
}

enum _Lado { anverso, reverso }

/// De donde sale la foto: la camara, la galeria o la misma foto ya elegida (para girarla). [ver]
/// solo la muestra en grande.
enum _Origen { camara, galeria, girar, ver }

/// Dos recuadros (anverso y reverso) para tomar con la camara o cargar de la galeria la foto del
/// carnet. Antes de leerla la persona la endereza en [enderezarFoto]. Cada foto se lee en el servidor
/// con Gemini (APK y web) y solo se acepta si es el documento boliviano del lado que corresponde; con
/// las dos se sacan el CI, el complemento, el nombre y la fecha de nacimiento. Si el servidor no puede
/// leer, el APK lee en el telefono con ML Kit y la web pide los datos a mano. Una foto ya elegida se
/// puede ver en grande, girar o cambiar.
class SelectorCarnet extends StatefulWidget {
  final ValueChanged<SeleccionCarnet> onCambio;
  final DocumentoFoto documento;

  const SelectorCarnet({super.key, required this.onCambio, this.documento = DocumentoFoto.carnet});

  @override
  State<SelectorCarnet> createState() => _SelectorCarnetState();
}

class _SelectorCarnetState extends State<SelectorCarnet> {
  bool get _esLicencia => widget.documento == DocumentoFoto.licencia;

  bool Function(String) _acepta(_Lado lado) => _esLicencia
      ? (lado == _Lado.anverso ? pareceAnversoLicencia : pareceReversoLicencia)
      : (lado == _Lado.anverso ? pareceAnverso : pareceReverso);

  final Map<_Lado, Uint8List> _fotos = {};
  final Map<_Lado, String> _textos = {};

  /// Lo que leyo el servidor de cada foto.
  final Map<_Lado, LecturaFoto> _lecturas = {};

  /// El servidor no pudo leer: el resto de las fotos de este selector se lee en el telefono.
  bool _soloTelefono = false;
  final Map<_Lado, String> _errores = {};
  _Lado? _leyendo;

  String _tituloEditor(_Lado lado) => switch ((_esLicencia, lado)) {
        (false, _Lado.anverso) => 'Anverso del carnet',
        (false, _Lado.reverso) => 'Reverso del carnet',
        (true, _Lado.anverso) => 'Anverso de la licencia',
        (true, _Lado.reverso) => 'Reverso de la licencia',
      };

  Future<void> _elegir(_Lado lado) async {
    if (_leyendo != null) return;
    final actual = _fotos[lado];
    final origen = await showModalBottomSheet<_Origen>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (actual != null)
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.magnifyingGlassPlus, color: ColoresApp.tinta),
                title: const Text('Ver la foto'),
                onTap: () => Navigator.of(context).pop(_Origen.ver),
              ),
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.camera, color: ColoresApp.tinta),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.of(context).pop(_Origen.camara),
            ),
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.image, color: ColoresApp.tinta),
              title: const Text('Cargar de la galería'),
              onTap: () => Navigator.of(context).pop(_Origen.galeria),
            ),
            if (actual != null)
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.rotateRight, color: ColoresApp.tinta),
                title: const Text('Girar esta foto'),
                onTap: () => Navigator.of(context).pop(_Origen.girar),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (origen == null || !mounted) return;
    if (origen == _Origen.ver) {
      await verFoto(context, actual!, titulo: _tituloEditor(lado));
      return;
    }
    Uint8List elegidos;
    if (origen == _Origen.girar) {
      elegidos = actual!;
    } else {
      final elegida = await ImagePicker().pickImage(
        source: origen == _Origen.camara ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 92,
      );
      if (elegida == null || !mounted) return;
      elegidos = await elegida.readAsBytes();
      if (!mounted) return;
    }
    // La persona endereza la foto: derecha se lee mejor y asi la ve el admin.
    final bytes = await enderezarFoto(context, elegidos, titulo: _tituloEditor(lado));
    if (bytes == null || !mounted) return;

    setState(() {
      _leyendo = lado;
      _errores.remove(lado);
    });
    LecturaFoto? lectura;
    String? fallo;
    if (!_soloTelefono) {
      try {
        lectura = await LectorDocumentos.leerEnServidor(bytes, licencia: _esLicencia, anverso: lado == _Lado.anverso);
      } on ApiExcepcion catch (e) {
        fallo = e.mensaje;
      }
      if (lectura == null && fallo == null) _soloTelefono = true;
    }
    if (!mounted) return;

    if (lectura != null || fallo != null) {
      setState(() {
        _leyendo = null;
        if (lectura != null && lectura.aceptada) {
          _fotos[lado] = bytes;
          _lecturas[lado] = lectura;
          _textos.remove(lado);
        } else {
          _quitar(lado);
          _errores[lado] = fallo ?? lectura?.motivo ?? _noEsElDocumento(lado);
        }
      });
      _avisar();
      return;
    }

    if (!OcrCarnet.disponible) {
      // Web sin lectura en el servidor: los datos se escriben a mano.
      setState(() {
        _leyendo = null;
        _fotos[lado] = bytes;
        _lecturas.remove(lado);
      });
      _avisar();
      return;
    }

    // Respaldo: ML Kit en el telefono. La otra foto, si la leyo el servidor, se vuelve a leer aqui
    // para juntar las dos lecturas del mismo lector.
    final resultado = await _leerEnTelefono(bytes, lado);
    final otro = lado == _Lado.anverso ? _Lado.reverso : _Lado.anverso;
    final otraFoto = _fotos[otro];
    final releerOtra = otraFoto != null && _lecturas.containsKey(otro) && !_textos.containsKey(otro);
    final resultadoOtra = releerOtra ? await _leerEnTelefono(otraFoto, otro) : null;
    if (!mounted) return;
    setState(() {
      _leyendo = null;
      _aplicarTelefono(lado, bytes, resultado);
      if (releerOtra) _aplicarTelefono(otro, otraFoto, resultadoOtra!);
    });
    _avisar();
  }

  void _quitar(_Lado lado) {
    _fotos.remove(lado);
    _textos.remove(lado);
    _lecturas.remove(lado);
  }

  /// Lee la foto con ML Kit: (texto, null) si es el documento pedido, (null, error) si no.
  Future<(String?, String?)> _leerEnTelefono(Uint8List bytes, _Lado lado) async {
    try {
      final texto = await OcrCarnet.leer(bytes, _acepta(lado));
      return (texto, texto == null ? _noEsElDocumento(lado) : null);
    } catch (_) {
      // Un error del lector no es lo mismo que una foto que no es un carnet: se dice aparte.
      return (null, 'No se pudo leer la foto en este teléfono. Intenta de nuevo o con otra foto.');
    }
  }

  /// Se llama dentro de setState.
  void _aplicarTelefono(_Lado lado, Uint8List bytes, (String?, String?) resultado) {
    final (texto, error) = resultado;
    _lecturas.remove(lado);
    if (texto == null) {
      _quitar(lado);
      _errores[lado] = error!;
    } else {
      _fotos[lado] = bytes;
      _textos[lado] = texto;
      _errores.remove(lado);
    }
  }

  String _noEsElDocumento(_Lado lado) => switch ((_esLicencia, lado)) {
        (false, _Lado.anverso) => 'Esta foto no es el anverso de un carnet de identidad (el lado con tu foto y el '
            'número). Tómala de frente, con buena luz y que se lea todo el carnet, y gírala hasta que las letras '
            'queden derechas.',
        (false, _Lado.reverso) => 'Esta foto no es el reverso de un carnet de identidad. Tómala de frente, con '
            'buena luz y que se lea todo el carnet, y gírala hasta que las letras queden derechas.',
        (true, _Lado.anverso) => 'Esta foto no es el anverso de una licencia de conducir (el lado con tu foto y '
            'tu nombre). Tómala de frente, con buena luz y que se lea toda la licencia, y gírala hasta que las '
            'letras queden derechas.',
        (true, _Lado.reverso) => 'Esta foto no es el reverso de una licencia de conducir (el lado con la '
            'categoría y el vencimiento). Tómala de frente, con buena luz y que se lea toda la licencia, y '
            'gírala hasta que las letras queden derechas.',
      };

  void _avisar() {
    final la = _lecturas[_Lado.anverso];
    final lr = _lecturas[_Lado.reverso];
    if (la != null && lr != null) {
      widget.onCambio(SeleccionCarnet(
        anverso: _fotos[_Lado.anverso],
        reverso: _fotos[_Lado.reverso],
        datos: _esLicencia ? null : datosCarnetDeLecturas(la, lr),
        licencia: _esLicencia ? datosLicenciaDeLecturas(la, lr) : null,
        textoAnverso: textoDeLectura(la),
        textoReverso: textoDeLectura(lr),
        delServidor: true,
      ));
      return;
    }
    final anverso = _textos[_Lado.anverso];
    final reverso = _textos[_Lado.reverso];
    final leidas = anverso != null && reverso != null;
    widget.onCambio(SeleccionCarnet(
      anverso: _fotos[_Lado.anverso],
      reverso: _fotos[_Lado.reverso],
      datos: leidas && !_esLicencia ? extraerDatosCarnet(anverso, reverso) : null,
      licencia: leidas && _esLicencia ? extraerDatosLicencia(anverso, reverso) : null,
      textoAnverso: anverso,
      textoReverso: reverso,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _ranura(_Lado.anverso, 'Anverso', 'Lado con tu foto')),
            const SizedBox(width: 12),
            Expanded(child: _ranura(_Lado.reverso, 'Reverso', 'Lado de atrás')),
          ],
        ),
        for (final lado in _Lado.values)
          if (_errores[lado] != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: FaIcon(FontAwesomeIcons.circleExclamation, color: ColoresApp.rojo, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errores[lado]!, style: const TextStyle(color: ColoresApp.rojo, fontSize: 13)),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _ranura(_Lado lado, String titulo, String ayuda) {
    final foto = _fotos[lado];
    final leyendo = _leyendo == lado;
    return Material(
      color: ColoresApp.gris,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: leyendo ? null : () => _elegir(lado),
        child: AspectRatio(
          aspectRatio: 1.45,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (foto != null)
                Image.memory(foto, fit: BoxFit.cover, gaplessPlayback: true)
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // El anverso lleva la foto de la persona; el reverso, no (dorso de la tarjeta).
                    FaIcon(
                        switch ((_esLicencia, lado)) {
                          (false, _Lado.anverso) => FontAwesomeIcons.idCard,
                          (false, _Lado.reverso) => FontAwesomeIcons.creditCard,
                          (true, _Lado.anverso) => FontAwesomeIcons.solidIdBadge,
                          (true, _Lado.reverso) => FontAwesomeIcons.solidCreditCard,
                        },
                        color: ColoresApp.tinta,
                        size: 26),
                    const SizedBox(height: 8),
                    Text(titulo, style: const TextStyle(color: ColoresApp.tinta, fontWeight: FontWeight.w700)),
                    Text(ayuda, style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 12)),
                  ],
                ),
              if (foto != null)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: ColoresApp.tinta, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(FontAwesomeIcons.check, color: ColoresApp.blanco, size: 11),
                        const SizedBox(width: 5),
                        Text(titulo, style: const TextStyle(color: ColoresApp.blanco, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              if (foto != null && !leyendo)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Material(
                    color: const Color(0xCC000000),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => verFoto(context, foto, titulo: _tituloEditor(lado)),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: FaIcon(FontAwesomeIcons.magnifyingGlassPlus, color: ColoresApp.blanco, size: 14),
                      ),
                    ),
                  ),
                ),
              if (leyendo)
                Container(
                  color: const Color(0xAA000000),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: ColoresApp.blanco, strokeWidth: 2.5)),
                      SizedBox(height: 8),
                      Text('Leyendo la foto...', style: TextStyle(color: ColoresApp.blanco, fontSize: 12.5)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso sobre los campos del nombre cuando la persona debe escribirlo o acomodarlo.
String avisoNombreCarnet(DatosCarnet datos) => datos.tieneNombre
    ? 'No pudimos saber cuáles de las palabras de tu carnet son tus nombres y cuáles tus apellidos. Revisa y '
          'acomódalos: usa solo las palabras de tu carnet.'
    : 'No pudimos leer tu nombre automáticamente. Escríbelo tal como está en tu carnet: lo compararemos con '
          'las fotos.';

/// "Tu nombre completo es: ... / Tu número de carnet es: 6565204-1B": la persona confirma sus
/// datos antes de guardar. Devuelve true si confirma; con "No" vuelve a tomar las fotos.
Future<bool> confirmarDatosCarnet(BuildContext context,
    {required String nombre, required String ci, String? complemento, SeleccionCarnet? fotos}) {
  final numero = (complemento ?? '').trim().isEmpty ? ci : '$ci-${complemento!.trim().toUpperCase()}';
  const etiqueta = TextStyle(color: ColoresApp.textoSuave);
  return confirmarViaje(
    context,
    titulo: 'Confirma tus datos',
    textoConfirmar: 'Sí, son mis datos',
    textoCancelar: 'No',
    contenido: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Tu nombre completo es:', textAlign: TextAlign.center, style: etiqueta),
        const SizedBox(height: 6),
        Text(
          nombre.trim().toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: ColoresApp.tinta, fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        const Text('Tu número de carnet es:', textAlign: TextAlign.center, style: etiqueta),
        const SizedBox(height: 6),
        Text(
          numero,
          textAlign: TextAlign.center,
          style: const TextStyle(color: ColoresApp.tinta, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        if (fotos != null && fotos.completa) _FotosLeidas(seleccion: fotos, documento: 'carnet'),
      ],
    ),
  );
}

/// "Confirma que tu número de licencia es: 6565204-1B" despues de confirmar el carnet. Devuelve true
/// si confirma; con "No" vuelve a tomar las fotos de la licencia.
Future<bool> confirmarNumeroLicencia(BuildContext context,
    {required String numero, String? categoria, DateTime? vence, SeleccionCarnet? fotos}) {
  return confirmarViaje(
    context,
    titulo: 'Confirma tu licencia',
    textoConfirmar: 'Sí, es correcto',
    textoCancelar: 'No',
    contenido: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Confirma que tu número de licencia es:', textAlign: TextAlign.center, style: TextStyle(color: ColoresApp.textoSuave)),
        const SizedBox(height: 8),
        Text(
          numero,
          textAlign: TextAlign.center,
          style: const TextStyle(color: ColoresApp.tinta, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        if (categoria != null || vence != null) ...[
          const SizedBox(height: 8),
          Text(
            [
              if (categoria != null) 'Categoría $categoria',
              if (vence != null) 'vence el ${vence.day.toString().padLeft(2, '0')}/${vence.month.toString().padLeft(2, '0')}/${vence.year}',
            ].join(', '),
            textAlign: TextAlign.center,
            style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13.5),
          ),
        ],
        if (fotos != null && fotos.completa) _FotosLeidas(seleccion: fotos, documento: 'licencia'),
      ],
    ),
  );
}

/// Miniaturas de las fotos de las que se leyeron los datos; al tocarlas se ven en grande.
class _FotosLeidas extends StatelessWidget {
  final SeleccionCarnet seleccion;
  final String documento;

  const _FotosLeidas({required this.seleccion, required this.documento});

  @override
  Widget build(BuildContext context) {
    Widget miniatura(Uint8List foto, String lado) => Expanded(
          child: Material(
            color: ColoresApp.gris,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => verFoto(context, foto, titulo: '${lado[0].toUpperCase()}${lado.substring(1)} de tu $documento'),
              child: AspectRatio(
                aspectRatio: 1.45,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(foto, fit: BoxFit.cover, gaplessPlayback: true),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: const Color(0x99000000),
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(lado, textAlign: TextAlign.center,
                            style: const TextStyle(color: ColoresApp.blanco, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Text('Leído de estas fotos (tócalas para verlas):',
              textAlign: TextAlign.center, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              miniatura(seleccion.anverso!, 'anverso'),
              const SizedBox(width: 10),
              miniatura(seleccion.reverso!, 'reverso'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Muestra una foto a pantalla completa, con zoom de dos dedos.
Future<void> verFoto(BuildContext context, Uint8List foto, {required String titulo}) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (context) => Scaffold(
      backgroundColor: ColoresApp.tinta,
      appBar: AppBar(
        backgroundColor: ColoresApp.tinta,
        foregroundColor: ColoresApp.blanco,
        title: Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        leading: IconButton(
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).pop(),
          icon: const FaIcon(FontAwesomeIcons.xmark, color: ColoresApp.blanco, size: 20),
        ),
      ),
      body: SafeArea(
        child: InteractiveViewer(
          maxScale: 6,
          child: Center(child: Image.memory(foto, fit: BoxFit.contain, gaplessPlayback: true)),
        ),
      ),
    ),
  ));
}
