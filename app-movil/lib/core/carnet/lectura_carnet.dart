/// Interpreta el texto leido (OCR) de las fotos del carnet de identidad boliviano. Sirve para los
/// dos modelos: el nuevo (tarjeta con zona de lectura MRZ "I<BOL..." en el reverso) y el antiguo
/// ("No 1234567" en el anverso y "Nacido el 27 de Agosto de 1998" en el reverso).
///
/// Solo se toma lo que pide el formulario: numero de CI, complemento y fecha de nacimiento. Los
/// nombres ya vienen de la cuenta de Google.
library;

/// Datos del carnet que llenan el formulario.
class DatosCarnet {
  final String? ci;

  /// Lo que va pegado al numero despues del guion (por ejemplo "1B" en "1234567-1B").
  final String? complemento;
  final DateTime? fechaNacimiento;

  const DatosCarnet({this.ci, this.complemento, this.fechaNacimiento});

  bool get completo => ci != null && fechaNacimiento != null;
}

/// Mayusculas y sin tildes, para comparar sin depender de como leyo el OCR.
String _normalizar(String texto) {
  const con = 'ÁÉÍÓÚÜÑáéíóúüñ';
  const sin = 'AEIOUUNaeiouun';
  final buffer = StringBuffer();
  for (final c in texto.split('')) {
    final i = con.indexOf(c);
    buffer.write(i >= 0 ? sin[i] : c);
  }
  return buffer.toString().toUpperCase();
}

/// Senales de que es un carnet boliviano. Tolerante con lo que el OCR lee mal ("BOLIVEA", "IDENTIAD").
bool _esDeBolivia(String t) =>
    t.contains('BOLIV') ||
    t.contains('PLURINACIONAL') ||
    t.contains('IDENTIFICACION PERSONAL') ||
    t.contains('SEGIP') ||
    t.contains('I<BOL') ||
    t.contains('CEDULA DE IDENTIDAD');

bool _diceCedula(String t) => t.contains('CEDULA') || t.contains('IDENTIDAD') || t.contains('IDENTIFICACION');

bool _tieneMarcasReverso(String t) =>
    t.contains('I<BOL') ||
    t.contains('LUGAR DE NACIMIENTO') ||
    t.contains('NACIDO EL') ||
    t.contains('CERTIFICA') ||
    t.contains('DOCUMENTOS REGISTRADOS') ||
    (t.contains('DOMICILIO') && t.contains('ESTADO CIVIL'));

/// Numero despues de "N°", "Nº", "No" o "N." y, si va pegado con guion, su complemento.
final _numero = RegExp(r'\bN\s*(?:°|º|O|0|\.)\s*[:.]?\s*(\d{5,10})(?:\s*-\s*([0-9A-Z]{1,3}))?(?![0-9A-Z])');

/// Numeros sueltos de 6 a 9 digitos que pueden ser el CI: no empiezan con 0 (series como "0200690") ni
/// van pegados a un guion o a letras ("3094343-LA", "QGDPYPIQ-16251008"), y no son parte de una fecha.
List<String> _candidatos(String t) => [
  for (final m in RegExp(r'(?<![0-9A-Z/.-])([1-9]\d{5,8})(?![0-9A-Z/.-])').allMatches(t)) m[1]!,
];

/// Numero del anverso: el que sigue a "N°" / "No"; si el OCR los separo, un numero suelto (el que
/// tambien aparece en [otroLado], si hay).
({String ci, String? complemento})? _numeroAnverso(String t, [String otroLado = '']) {
  final conEtiqueta = _numero.firstMatch(t);
  if (conEtiqueta != null) return (ci: conEtiqueta[1]!, complemento: conEtiqueta[2]);
  final candidatos = _candidatos(t);
  if (candidatos.isEmpty) return null;
  final enAmbos = candidatos.where((c) => otroLado.contains(c));
  return (ci: enAmbos.isNotEmpty ? enAmbos.first : candidatos.first, complemento: null);
}

/// Anverso: es un carnet boliviano, dice cedula / identidad, trae el numero y no es el reverso. Se
/// acepta en cualquier posicion en que el texto se pueda leer.
bool pareceAnverso(String texto) {
  final t = _normalizar(texto);
  return _esDeBolivia(t) && _diceCedula(t) && _numeroAnverso(t) != null && !_tieneMarcasReverso(t);
}

/// Reverso: es un carnet boliviano con los datos de nacimiento, domicilio o la zona MRZ.
bool pareceReverso(String texto) {
  final t = _normalizar(texto);
  return _esDeBolivia(t) && _tieneMarcasReverso(t);
}

const _meses = {
  'ENERO': 1, 'FEBRERO': 2, 'MARZO': 3, 'ABRIL': 4, 'MAYO': 5, 'JUNIO': 6, 'JULIO': 7, 'AGOSTO': 8,
  'SEPTIEMBRE': 9, 'SETIEMBRE': 9, 'OCTUBRE': 10, 'NOVIEMBRE': 11, 'DICIEMBRE': 12,
};

DateTime? _fechaValida(int anio, int mes, int dia) {
  if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;
  final fecha = DateTime(anio, mes, dia);
  // DateTime corrige fechas imposibles (31/02 -> marzo): se descartan.
  if (fecha.month != mes || fecha.day != dia) return null;
  if (anio < 1900 || !fecha.isBefore(DateTime.now())) return null;
  return fecha;
}

/// Fecha de nacimiento: "FECHA DE NACIMIENTO: 07/11/2002" (nuevo), la linea 2 de la MRZ
/// "0211071M..." (AAMMDD) o "Nacido el 27 de Agosto de 1998" (antiguo).
DateTime? _fechaNacimiento(String t) {
  final conEtiqueta = RegExp(r'NACIMIENTO\W{0,6}(\d{1,2})\s*[/.-]\s*(\d{1,2})\s*[/.-]\s*(\d{4})').firstMatch(t);
  if (conEtiqueta != null) {
    final f = _fechaValida(int.parse(conEtiqueta[3]!), int.parse(conEtiqueta[2]!), int.parse(conEtiqueta[1]!));
    if (f != null) return f;
  }
  final nacido = RegExp(r'NACIDO\s+EL\W{0,4}(\d{1,2})\s+DE\s+([A-Z]+)\s+DE\s+(\d{4})').firstMatch(t);
  if (nacido != null && _meses.containsKey(nacido[2])) {
    final f = _fechaValida(int.parse(nacido[3]!), _meses[nacido[2]]!, int.parse(nacido[1]!));
    if (f != null) return f;
  }
  // MRZ (TD1), linea 2: AAMMDD de nacimiento, digito, sexo, AAMMDD de vencimiento.
  final mrz = RegExp(r'(\d{2})(\d{2})(\d{2})\d[MF<X]\d{6}').firstMatch(t.replaceAll(' ', ''));
  if (mrz != null) {
    final aa = int.parse(mrz[1]!);
    final siglo = aa > DateTime.now().year % 100 ? 1900 : 2000;
    final f = _fechaValida(siglo + aa, int.parse(mrz[2]!), int.parse(mrz[3]!));
    if (f != null) return f;
  }
  return null;
}

/// Junta lo leido en el anverso y en el reverso.
DatosCarnet extraerDatosCarnet(String anverso, String reverso) {
  final a = _normalizar(anverso);
  final r = _normalizar(reverso);
  String? ci;
  String? complemento;
  // Numero de la MRZ del reverso del carnet nuevo ("I<BOL1234567<1"): el mas confiable.
  final mrz = RegExp(r'I<BOL(\d{5,10})<').firstMatch(r.replaceAll(' ', ''));
  final numero = _numeroAnverso(a, r);
  if (numero != null) {
    ci = numero.ci;
    complemento = numero.complemento;
    // Sin "N°" en el anverso pero con MRZ: manda la MRZ.
    if (mrz != null && _numero.firstMatch(a) == null) ci = mrz[1];
  } else {
    ci = mrz?[1];
  }
  return DatosCarnet(
    ci: ci,
    complemento: complemento,
    fechaNacimiento: _fechaNacimiento(a) ?? _fechaNacimiento(r),
  );
}
