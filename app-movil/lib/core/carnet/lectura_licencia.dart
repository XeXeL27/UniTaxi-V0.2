/// Interpreta el texto leido (OCR) de las fotos de la licencia de conducir boliviana (SEGIP):
/// numero, categoria, vencimiento y el nombre del titular. ML Kit devuelve las lineas en otro orden
/// segun como este girada la foto, asi que nada depende del orden: se buscan etiquetas y patrones.
///
/// En el anverso, bajo "Nombres, Apellidos", va el titular con una coma entre los nombres y los
/// apellidos ("JUAN CARLOS, PEREZ MAMANI"), y el numero de licencia, debajo de la foto, es el del
/// carnet de identidad.
library;

import 'lectura_carnet.dart';

/// Datos de la licencia que llenan el registro del conductor.
class DatosLicencia {
  /// Numero sin complemento (el del CI).
  final String? numero;

  /// Complemento pegado al numero con guion ("1B" en "6565204-1B"), si la licencia lo tiene.
  final String? complemento;

  /// Una letra: P particular, M motociclista, A, B o C profesional.
  final String? categoria;
  final DateTime? vencimiento;
  final DateTime? nacimiento;

  /// Palabras del nombre en la linea "NOMBRES, APELLIDOS" (por ejemplo JUAN, PEREZ).
  final List<String> nombre;

  /// La misma linea cortada en la coma: antes van los nombres y despues los apellidos (el segundo
  /// apellido a veces pasa a la linea de abajo y no esta aqui).
  final List<String> nombres;
  final List<String> apellidos;

  /// Todas las palabras del anverso, para buscar el nombre completo sin depender del orden.
  final List<String> palabras;

  const DatosLicencia({
    this.numero,
    this.complemento,
    this.categoria,
    this.vencimiento,
    this.nacimiento,
    this.nombre = const [],
    this.nombres = const [],
    this.apellidos = const [],
    this.palabras = const [],
  });

  bool get completa => numero != null && categoria != null && vencimiento != null;

  /// "6565204-1B", o solo el numero si no tiene complemento.
  String? get numeroCompleto => numero == null ? null : complemento == null ? numero : '$numero-$complemento';

  bool get esMoto => categoria == 'M';

  bool get vencida {
    final v = vencimiento;
    if (v == null) return false;
    final hoy = DateTime.now();
    return v.isBefore(DateTime(hoy.year, hoy.month, hoy.day));
  }
}

/// Nombre de cada categoria, para los mensajes.
const nombresCategoria = {
  'P': 'Particular',
  'M': 'Motociclista',
  'A': 'Profesional A',
  'B': 'Profesional B',
  'C': 'Profesional C',
};

bool _esDeBolivia(String t) => t.contains('BOLIV') || t.contains('EGIP') || t.contains('IDENTIFICACION');

bool _tieneNumero(String t) => _candidatos(t).isNotEmpty;

/// Numeros de 6 a 9 digitos que no son parte de una fecha.
List<String> _candidatos(String t) => [
  for (final m in RegExp(r'(?<![0-9/.-])([1-9]\d{5,8})(?![0-9/])').allMatches(t)) m[1]!,
];

/// Anverso: dice licencia para conducir, es boliviana, trae el nombre y el numero. Un carnet de
/// identidad no pasa (dice cedula).
bool pareceAnversoLicencia(String texto) {
  final t = normalizarOcr(texto);
  final diceLicencia = t.contains('LICEN') && (t.contains('CONDU') || t.contains('GONDU') || t.contains('CATEGOR'));
  final traeNombre = t.contains('NOMBRES') || t.contains('APEL');
  return diceLicencia && traeNombre && _esDeBolivia(t) && _tieneNumero(t) && !t.contains('CEDULA');
}

/// Reverso: emision y vencimiento, el numero y los datos del reverso (grupo sanguineo, lentes,
/// audifonos o la descripcion de la categoria), sin el nombre ni el titulo del anverso.
bool pareceReversoLicencia(String texto) {
  final t = normalizarOcr(texto);
  final fechas = t.contains('VENCIM') && t.contains('EMISI');
  final marcas = t.contains('GRUPO') || t.contains('LENTES') || t.contains('AUDIF') || t.contains('MOTOCICLETA');
  final esAnverso = t.contains('NOMBRES') || t.contains('APELLIDOS') || t.contains('PARA CONDUCIR');
  return fechas && marcas && !esAnverso && _tieneNumero(t) && !t.contains('CEDULA');
}

List<DateTime> _fechas(String t) {
  final limite = DateTime.now().year + 20;
  final fechas = <DateTime>[];
  for (final m in RegExp(r'(?<!\d)(\d{2})\s*/\s*(\d{2})\s*/\s*(\d{4})(?!\d)').allMatches(t)) {
    final dia = int.parse(m[1]!);
    final mes = int.parse(m[2]!);
    final anio = int.parse(m[3]!);
    if (mes < 1 || mes > 12 || dia < 1 || dia > 31 || anio < 1920 || anio > limite) continue;
    final fecha = DateTime(anio, mes, dia);
    if (fecha.month == mes && fecha.day == dia) fechas.add(fecha);
  }
  return fechas;
}

/// Categoria: "CATEGORIA M" del anverso (el OCR a veces la pega: "CATEGORIAM"). Si no se lee, el
/// reverso de la licencia de moto dice "Motocicletas, triciclos y cuadriciclos".
String? _categoria(String anverso, String reverso) {
  final m = RegExp(r'CATEGOR[I1L]?A\s*[:.]?\s*([PMABC])(?![A-Z])').firstMatch(anverso);
  if (m != null) return m[1];
  if (reverso.contains('MOTOCICLETA')) return 'M';
  return null;
}

/// Numero: el que aparece en los dos lados (en el anverso va dos veces); si no, el mas repetido.
String? _numero(String anverso, String reverso) {
  final delAnverso = _candidatos(anverso);
  final delReverso = _candidatos(reverso).toSet();
  final enAmbos = delAnverso.where(delReverso.contains);
  if (enAmbos.isNotEmpty) return enAmbos.first;
  final todos = [...delAnverso, ...delReverso];
  if (todos.isEmpty) return null;
  final cuenta = <String, int>{};
  for (final n in todos) {
    cuenta[n] = (cuenta[n] ?? 0) + 1;
  }
  return (cuenta.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
}

/// Complemento pegado con guion al [numero] en cualquiera de los dos lados.
String? _complemento(String? numero, String anverso, String reverso) {
  if (numero == null) return null;
  final patron = RegExp('(?<![0-9])$numero\\s*-\\s*([0-9A-Z]{2})(?![0-9A-Z])');
  for (final texto in [anverso, reverso]) {
    for (final m in patron.allMatches(texto)) {
      if (complementoValido(m[1]!)) return m[1];
    }
  }
  return null;
}

/// Palabras de solo letras (sin tildes), de 2 o mas letras.
List<String> palabrasDe(String texto) => [
  for (final m in RegExp(r'[A-Z]{2,}').allMatches(normalizarOcr(texto))) m[0]!,
];

/// Linea del titular bajo la etiqueta "Nombres, Apellidos": los nombres, una coma y los apellidos
/// ("JUAN CARLOS, PEREZ MAMANI"). La etiqueta, que tambien lleva coma, no es el nombre: puede venir
/// sola en su linea o delante del nombre.
({List<String> nombres, List<String> apellidos})? _lineaNombre(String anverso) {
  for (final original in anverso.split('\n')) {
    final linea = original.replaceFirst(RegExp(r'^\s*NOMBRES?\W*APEL[A-Z]*\s*[:.;]?\s*'), '');
    final m = RegExp(r'^\s*([A-Z][A-Z ]*[A-Z])\s*,\s*([A-Z][A-Z ]*[A-Z])\s*[:.;]?\s*$').firstMatch(linea);
    if (m == null) continue;
    final nombres = palabrasDe(m[1]!);
    final apellidos = palabrasDe(m[2]!);
    if ([...nombres, ...apellidos].any((p) => p.startsWith('NOMBRE') || p.startsWith('APEL'))) continue;
    return (nombres: nombres, apellidos: apellidos);
  }
  return null;
}

/// Junta lo leido en el anverso y en el reverso. Con [ci] (el numero del carnet), si ese numero se leyo
/// en la licencia es el numero de licencia: la licencia trae otros numeros.
DatosLicencia extraerDatosLicencia(String anverso, String reverso, {String? ci}) {
  final a = normalizarOcr(anverso);
  final r = normalizarOcr(reverso);
  final fechas = [..._fechas(a), ..._fechas(r)]..sort();
  // Vencimiento: la fecha mas lejana; nacimiento: la mas antigua (si es distinta de la emision).
  final vencimiento = fechas.isEmpty ? null : fechas.last;
  final nacimiento = fechas.length < 3 ? null : fechas.first;
  final delCarnet = ci != null && [..._candidatos(a), ..._candidatos(r)].contains(ci.trim());
  final numero = delCarnet ? ci.trim() : _numero(a, r);
  final titular = _lineaNombre(a);
  return DatosLicencia(
    numero: numero,
    complemento: _complemento(numero, a, r),
    categoria: _categoria(a, r),
    vencimiento: vencimiento,
    nacimiento: nacimiento,
    nombre: titular == null ? const [] : [...titular.nombres, ...titular.apellidos],
    nombres: titular?.nombres ?? const [],
    apellidos: titular?.apellidos ?? const [],
    palabras: palabrasDe(a),
  );
}

/// Distancia de edicion (Levenshtein) entre dos palabras cortas.
int _distancia(String a, String b) {
  var anterior = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final actual = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final costo = a[i - 1] == b[j - 1] ? 0 : 1;
      actual[j] = [anterior[j] + 1, actual[j - 1] + 1, anterior[j - 1] + costo].reduce((x, y) => x < y ? x : y);
    }
    anterior = actual;
  }
  return anterior[b.length];
}

/// Dos palabras son la misma aunque el OCR haya leido mal una letra (dos en las largas).
bool _parecida(String a, String b) {
  if (a == b) return true;
  final corta = a.length < b.length ? a.length : b.length;
  if (corta < 5) return false;
  return _distancia(a, b) <= (corta >= 8 ? 2 : 1);
}

bool _contiene(List<String> palabras, String buscada) => palabras.any((p) => _parecida(p, buscada));

/// El nombre de la licencia es el de la persona: cada palabra de su nombre completo (de 3 o mas
/// letras) esta en la licencia y cada palabra de la linea "NOMBRES, APELLIDOS" de la licencia esta
/// en su nombre. Tolera tildes, la Ñ leida como N y una letra mal leida por el OCR.
bool nombreCoincide(String nombreCompleto, DatosLicencia licencia) {
  final persona = palabrasDe(nombreCompleto).where((p) => p.length >= 3).toList();
  if (persona.isEmpty) return false;
  if (!persona.every((p) => _contiene(licencia.palabras, p))) return false;
  return licencia.nombre.where((p) => p.length >= 3).every((p) => _contiene(persona, p));
}

/// El carnet antiguo no separa nombres de apellidos ("A: JUAN CARLOS PEREZ MAMANI"); la licencia si,
/// con la coma ("JUAN CARLOS, PEREZ MAMANI"). Si los nombres de la licencia son el comienzo del nombre
/// del carnet y sus apellidos estan en el resto, devuelve el carnet cortado ahi, con el corte seguro;
/// si no, null.
DatosCarnet? cortarConLicencia(DatosCarnet carnet, DatosLicencia licencia) {
  if (!carnet.tieneNombre || (carnet.nombreSeguro && !carnet.corteSugerido) || carnet.nombreCortado) return null;
  final palabras = [...carnet.palabrasNombres, ...carnet.palabrasApellidos];
  final nombres = licencia.nombres;
  if (nombres.isEmpty || licencia.apellidos.isEmpty || nombres.length >= palabras.length) return null;
  for (var i = 0; i < nombres.length; i++) {
    if (!_parecida(palabras[i], nombres[i])) return null;
  }
  final resto = palabras.sublist(nombres.length);
  if (!licencia.apellidos.every((p) => _contiene(resto, p))) return null;
  return carnet.cortadoEn(nombres.length);
}

/// La linea del nombre de la licencia tambien esta en el texto del carnet (las dos son del SEGIP).
bool nombreEnCarnet(DatosLicencia licencia, String textoCarnet) {
  final carnet = palabrasDe(textoCarnet);
  final nombre = licencia.nombre.where((p) => p.length >= 3).toList();
  if (nombre.isEmpty || carnet.isEmpty) return true;
  return nombre.every((p) => _contiene(carnet, p));
}
