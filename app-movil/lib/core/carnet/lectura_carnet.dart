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

bool _esDeBolivia(String t) =>
    t.contains('BOLIVIA') || t.contains('IDENTIFICACION PERSONAL') || t.contains('SEGIP') || t.contains('I<BOL');

bool _tieneMarcasReverso(String t) =>
    t.contains('I<BOL') ||
    t.contains('LUGAR DE NACIMIENTO') ||
    t.contains('NACIDO EL') ||
    t.contains('CERTIFICA') ||
    t.contains('DOCUMENTOS REGISTRADOS') ||
    (t.contains('DOMICILIO') && t.contains('ESTADO CIVIL'));

/// Numero despues de "N°", "Nº", "No" o "N." y, si va pegado con guion, su complemento.
final _numero = RegExp(r'\bN\s*(?:°|º|O|0|\.)\s*[:.]?\s*(\d{5,10})(?:\s*-\s*([0-9A-Z]{1,3}))?(?![0-9A-Z])');

/// Anverso: es un carnet boliviano, dice "CEDULA DE IDENTIDAD", trae el numero y no es el reverso.
bool pareceAnverso(String texto) {
  final t = _normalizar(texto);
  return _esDeBolivia(t) && t.contains('CEDULA') && _numero.hasMatch(t) && !_tieneMarcasReverso(t);
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
  final numero = _numero.firstMatch(a);
  if (numero != null) {
    ci = numero[1];
    complemento = numero[2];
  } else {
    // Sin "N°" legible en el anverso: el numero de la MRZ del reverso ("I<BOL12382492<1").
    final mrz = RegExp(r'I<BOL(\d{5,10})<').firstMatch(r.replaceAll(' ', ''));
    ci = mrz?[1];
  }
  return DatosCarnet(
    ci: ci,
    complemento: complemento,
    fechaNacimiento: _fechaNacimiento(a) ?? _fechaNacimiento(r),
  );
}
