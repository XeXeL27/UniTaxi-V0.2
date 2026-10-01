import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

const bool ocrDisponible = true;

/// Lee la foto con ML Kit (alfabeto latino) en cualquier posicion: derecha, de cabeza o de costado.
/// ML Kit lee algo aunque el texto este girado, pero de cabeza o de costado desordena las lineas y
/// pega palabras ("JUANCARLOS"). Por eso se mide hacia donde corre el texto y se gira la foto hasta
/// dejarlo derecho; se devuelve la lectura derecha que el documento acepte o, si ninguna lo esta, la
/// primera aceptada. El texto devuelto trae primero las filas armadas por posicion ([_textoPorFilas]) y
/// despues el texto tal como lo entrega ML Kit.
Future<String?> leerTexto(Uint8List imagen, bool Function(String texto) acepta) async {
  final lector = TextRecognizer(script: TextRecognitionScript.latin);
  final carpeta = await Directory.systemTemp.createTemp('carnet');
  try {
    img.Image? decodificada;
    Future<RecognizedText?> leer(int grados) async {
      Uint8List bytes = imagen;
      if (grados != 0) {
        if (decodificada == null) {
          final original = img.decodeImage(imagen);
          if (original == null) return null;
          // La foto de la camara puede venir girada por EXIF: se aplica antes de rotarla.
          decodificada = img.bakeOrientation(original);
        }
        bytes = img.encodeJpg(img.copyRotate(decodificada!, angle: grados), quality: 90);
      }
      final archivo = File('${carpeta.path}/carnet_$grados.jpg');
      await archivo.writeAsBytes(bytes, flush: true);
      return lector.processImage(InputImage.fromFilePath(archivo.path));
    }

    String? primeraAceptada;
    final probados = <int>{};
    var orden = const [0, 90, 270, 180];
    for (var i = 0; i < orden.length; i++) {
      final grados = orden[i];
      if (!probados.add(grados)) continue;
      final leido = await leer(grados);
      if (leido == null) return null;
      final angulo = _anguloTexto(leido);
      final derecho = angulo != null && angulo.abs() < 25;
      final texto = '${_textoPorFilas(leido, angulo)}\n${leido.text}';
      if (acepta(texto)) {
        if (derecho) return texto;
        primeraAceptada ??= texto;
      }
      // Con la primera lectura se sabe cuanto esta girado el texto: se prueban primero los giros que
      // lo dejarian derecho (en un sentido y en el otro).
      if (i == 0 && angulo != null) {
        final cuarto = ((angulo / 90).round() * 90) % 360;
        orden = [0, (360 - cuarto) % 360, cuarto, 90, 270, 180];
      }
    }
    return primeraAceptada;
  } finally {
    await lector.close();
    try {
      await carpeta.delete(recursive: true);
    } catch (_) {
      // Es la carpeta temporal de la app: el sistema la limpia.
    }
  }
}

/// Direccion en que corre el texto, en grados (0 = derecho, 180 = de cabeza, +-90 = de costado):
/// promedio de las lineas, pesado por su largo. Con [cercaDe] solo cuentan las lineas que se apartan
/// menos de 30 grados de ese angulo. null si no se leyo nada.
double? _anguloTexto(RecognizedText leido, {double? cercaDe}) {
  var x = 0.0;
  var y = 0.0;
  for (final bloque in leido.blocks) {
    for (final linea in bloque.lines) {
      final puntos = linea.cornerPoints;
      if (puntos.length < 2) continue;
      final a = atan2((puntos[1].y - puntos[0].y).toDouble(), (puntos[1].x - puntos[0].x).toDouble());
      if (cercaDe != null) {
        var diferencia = (a * 180 / pi - cercaDe).abs() % 360;
        if (diferencia > 180) diferencia = 360 - diferencia;
        if (diferencia > 30) continue;
      }
      final peso = linea.text.length.toDouble();
      x += cos(a) * peso;
      y += sin(a) * peso;
    }
  }
  if (x == 0 && y == 0) return null;
  return atan2(y, x) * 180 / pi;
}

/// Lineas agrupadas en filas segun su posicion en la foto, de arriba abajo y de izquierda a derecha,
/// con el texto enderezado por [angulo]. ML Kit separa en bloques lo que esta en una misma fila (en el
/// carnet antiguo "A:" y el nombre, "Nacido el" y la fecha) y los devuelve lejos uno del otro; aqui
/// quedan juntos. Las lineas que corren en otra direccion (el texto vertical del borde) van al final.
String _textoPorFilas(RecognizedText leido, double? estimado) {
  if (estimado == null) return '';
  // El promedio de [_anguloTexto] lo tuerce el texto del borde: se recalcula solo con las lineas que
  // corren casi igual.
  final angulo = _anguloTexto(leido, cercaDe: estimado) ?? estimado;
  final t = angulo * pi / 180;
  final c = cos(t);
  final s = sin(t);
  final lineas = <({double u, double v, double alto, String texto})>[];
  final deCostado = <String>[];
  for (final bloque in leido.blocks) {
    for (final linea in bloque.lines) {
      final p = linea.cornerPoints;
      if (p.length < 4) continue;
      final propio = atan2((p[1].y - p[0].y).toDouble(), (p[1].x - p[0].x).toDouble()) * 180 / pi;
      var diferencia = (propio - angulo).abs() % 360;
      if (diferencia > 180) diferencia = 360 - diferencia;
      if (diferencia > 30) {
        deCostado.add(linea.text);
        continue;
      }
      final x = p.map((q) => q.x).reduce((a, b) => a + b) / p.length;
      final y = p.map((q) => q.y).reduce((a, b) => a + b) / p.length;
      final alto = sqrt(pow(p[3].x - p[0].x, 2) + pow(p[3].y - p[0].y, 2));
      lineas.add((u: x * c + y * s, v: -x * s + y * c, alto: alto.toDouble(), texto: linea.text));
    }
  }
  lineas.sort((a, b) => a.v.compareTo(b.v));
  final filas = <List<({double u, double v, double alto, String texto})>>[];
  for (final linea in lineas) {
    final ultima = filas.isEmpty ? null : filas.last;
    if (ultima != null) {
      final v = ultima.map((l) => l.v).reduce((a, b) => a + b) / ultima.length;
      final alto = ultima.map((l) => l.alto).reduce(max);
      if ((linea.v - v).abs() < 0.5 * min(alto, linea.alto)) {
        ultima.add(linea);
        continue;
      }
    }
    filas.add([linea]);
  }
  return [
    for (final fila in filas) (fila..sort((a, b) => a.u.compareTo(b.u))).map((l) => l.texto).join(' '),
    ...deCostado,
  ].join('\n');
}
