/// Interpreta el texto leido (OCR) de las fotos del carnet de identidad boliviano. Sirve para los
/// dos modelos: el nuevo (tarjeta con zona de lectura MRZ "I<BOL..." en el reverso) y el antiguo
/// ("No 1234567" en el anverso y "Nacido el 27 de Agosto de 1998" en el reverso).
///
/// Se toma lo que pide el registro: numero de CI, complemento, fecha de nacimiento y el nombre
/// impreso (nombres y apellidos). El nombre del carnet reemplaza al de la cuenta de Google, que puede
/// ser un apodo.
library;

/// Datos del carnet que llenan el formulario.
class DatosCarnet {
  final String? ci;

  /// Lo que va pegado al numero despues del guion (por ejemplo "1B" en "1234567-1B").
  final String? complemento;
  final DateTime? fechaNacimiento;

  /// Nombres y apellidos tal como estan impresos, en mayusculas ("JUAN CARLOS", "PÉREZ MAMANI").
  final String? nombres;
  final String? apellidos;

  /// false cuando el carnet no deja claro donde terminan los nombres (carnet antiguo: "A: MARIA ELENA
  /// ROJAS VACA") o la MRZ corto un nombre largo: la persona acomoda sus nombres a mano.
  final bool nombreSeguro;

  /// La MRZ corto los nombres (tienen 30 letras como maximo): los apellidos estan bien, pero a los
  /// nombres les puede faltar el final.
  final bool nombreCortado;

  /// El carnet antiguo no separa nombres de apellidos y el corte lo propuso el lector (Gemini): se
  /// muestra como seguro, pero la coma de la licencia puede corregirlo (cortarConLicencia).
  final bool corteSugerido;

  /// Palabras leidas (sin tildes), para revisar lo que la persona acomode a mano.
  final List<String> palabrasNombres;
  final List<String> palabrasApellidos;

  /// Todas las palabras leidas en las dos fotos (sin el texto fijo del carnet). Si el nombre no se
  /// pudo sacar solo, la persona lo escribe y cada palabra debe estar aqui.
  final Set<String> palabrasDelCarnet;

  const DatosCarnet({
    this.ci,
    this.complemento,
    this.fechaNacimiento,
    this.nombres,
    this.apellidos,
    this.nombreSeguro = true,
    this.nombreCortado = false,
    this.corteSugerido = false,
    this.palabrasNombres = const [],
    this.palabrasApellidos = const [],
    this.palabrasDelCarnet = const {},
  });

  bool get completo => ci != null && fechaNacimiento != null;

  /// Los mismos datos con el nombre cortado despues de [cantidadNombres] palabras y el corte seguro:
  /// lo dice otro documento (la licencia separa nombres y apellidos con una coma).
  DatosCarnet cortadoEn(int cantidadNombres) {
    final impresas = nombreCompleto.split(' ');
    final palabras = [...palabrasNombres, ...palabrasApellidos];
    return DatosCarnet(
      ci: ci,
      complemento: complemento,
      fechaNacimiento: fechaNacimiento,
      nombres: impresas.take(cantidadNombres).join(' '),
      apellidos: impresas.skip(cantidadNombres).join(' '),
      palabrasNombres: palabras.take(cantidadNombres).toList(),
      palabrasApellidos: palabras.skip(cantidadNombres).toList(),
      palabrasDelCarnet: palabrasDelCarnet,
    );
  }

  bool get tieneNombre => nombres != null && apellidos != null;

  String get nombreCompleto => '${nombres ?? ''} ${apellidos ?? ''}'.trim();

  /// Que campos del nombre puede corregir la persona: cuando la lectura no es segura o cuando no se
  /// pudo sacar el nombre (entonces lo escribe y se compara con lo leido).
  bool get nombresEditables => !tieneNombre || !nombreSeguro;
  bool get apellidosEditables => !tieneNombre || (!nombreSeguro && !nombreCortado);

  /// Revisa los nombres y apellidos escritos o acomodados a mano. Si el nombre no se leyo solo, cada
  /// palabra escrita debe aparecer en las fotos del carnet. Si se leyo pero el corte no era seguro,
  /// deben ser las palabras del carnet en el mismo orden; solo cambia donde terminan los nombres. Si
  /// la MRZ corto los nombres, los leidos deben ser el comienzo de los escritos. Devuelve el problema
  /// o null si esta bien.
  String? revisarNombreEscrito(String nombres, String apellidos) {
    if (tieneNombre && nombreSeguro) return null;
    final escritosN = _palabras(nombres);
    final escritosA = _palabras(apellidos);
    if (escritosN.isEmpty || escritosA.isEmpty) return 'Escribe al menos un nombre y un apellido.';
    if (!tieneNombre) {
      final faltan = [...escritosN, ...escritosA].where((p) => !palabrasDelCarnet.any((l) => _mismaPalabra(p, l)));
      return faltan.isEmpty
          ? null
          : 'Escribe tu nombre tal como está en tu carnet: no encontramos ${faltan.join(', ')} en las fotos. Si '
                'está bien escrito, vuelve a tomar las fotos con buena luz.';
    }
    final enCarnet = [...palabrasNombres, ...palabrasApellidos].join(' ');
    if (nombreCortado) {
      if (escritosA.join(' ') != palabrasApellidos.join(' ')) return 'Tus apellidos deben quedar como en tu carnet.';
      final leidos = palabrasNombres;
      var ok = escritosN.length >= leidos.length;
      for (var i = 0; ok && i < leidos.length; i++) {
        final ultima = i == leidos.length - 1;
        ok = ultima ? escritosN[i].startsWith(leidos[i]) : escritosN[i] == leidos[i];
      }
      return ok ? null : 'Tus nombres deben empezar como en tu carnet: ${leidos.join(' ')}.';
    }
    // Se comparan las letras sin espacios: el OCR a veces pega dos palabras ("JUANCARLOS") y la persona
    // las separa.
    return [...escritosN, ...escritosA].join() == enCarnet.replaceAll(' ', '')
        ? null
        : 'Usa las mismas palabras de tu carnet, en el mismo orden: $enCarnet. Solo elige cuáles son tus nombres '
              'y cuáles tus apellidos (puedes separar palabras que salieron juntas).';
  }

  /// La palabra escrita y la leida son la misma: iguales, con una letra mal leida (palabras de 5 o mas
  /// letras) o la escrita es parte de dos palabras que el OCR pego ("JUANCARLOS").
  static bool _mismaPalabra(String escrita, String leida) {
    if (escrita == leida) return true;
    if (escrita.length >= 3 && leida.length > escrita.length + 1 && leida.contains(escrita)) return true;
    if (escrita.length < 5 || (escrita.length - leida.length).abs() > 1) return false;
    return _distancia(escrita, leida) <= 1;
  }

  static int _distancia(String a, String b) {
    var previa = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      final actual = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final costo = a[i - 1] == b[j - 1] ? 0 : 1;
        actual[j] = [previa[j] + 1, actual[j - 1] + 1, previa[j - 1] + costo].reduce((x, y) => x < y ? x : y);
      }
      previa = actual;
    }
    return previa[b.length];
  }

  static List<String> _palabras(String texto) =>
      normalizarOcr(texto).split(RegExp(r'[^A-Z]+')).where((p) => p.isNotEmpty).toList();
}

/// Mayusculas y sin tildes (la Ñ pasa a N), para comparar sin depender de como leyo el OCR.
String normalizarOcr(String texto) {
  const con = 'ÁÀÂÄÉÈÊËÍÌÎÏÓÒÔÖÚÙÛÜÑáàâäéèêëíìîïóòôöúùûüñ';
  const sin = 'AAAAEEEEIIIIOOOOUUUUNaaaaeeeeiiiioooouuuun';
  final buffer = StringBuffer();
  for (final c in texto.split('')) {
    final i = con.indexOf(c);
    buffer.write(i >= 0 ? sin[i] : _vocalConPunto(c));
  }
  return buffer.toString().toUpperCase();
}

/// ML Kit a veces devuelve vocales con signos de otros idiomas ("CẠLLISAYA", "PẸREZ"): se pasan a
/// la letra base.
String _vocalConPunto(String c) {
  final u = c.codeUnitAt(0);
  if (u < 0x1EA0 || u > 0x1EF9) return c;
  if (u <= 0x1EB7) return 'A';
  if (u <= 0x1EC7) return 'E';
  if (u <= 0x1ECB) return 'I';
  if (u <= 0x1EE3) return 'O';
  if (u <= 0x1EF1) return 'U';
  return 'Y';
}

String _normalizar(String texto) => normalizarOcr(texto);

/// Complemento valido: dos caracteres con al menos un numero (por ejemplo 1B). Las siglas del
/// departamento de expedicion (LP, PD, PDO...) no son complemento.
bool complementoValido(String complemento) => RegExp(r'^(?=.*\d)[0-9A-Z]{2}$').hasMatch(complemento.toUpperCase());

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

/// Numero suelto con su complemento pegado con guion ("6565204-1B", "123456-1H"), por si el OCR
/// separo el "N°". El complemento debe tener un numero: "3000000-LA" no lo es.
final _numeroConComplemento = RegExp(r'(?<![0-9A-Z/.-])([1-9]\d{5,8})\s*-\s*([0-9A-Z]{2})(?![0-9A-Z])');

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
  for (final m in _numeroConComplemento.allMatches(t)) {
    if (complementoValido(m[2]!)) return (ci: m[1]!, complemento: m[2]);
  }
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
  // El OCR suele pegar el dia con "de" ("Nacido el27de Agosto").
  final nacido = RegExp('NACIDO\\s*EL\\W{0,4}(\\d{1,2})\\s*DE\\s*(${_meses.keys.join('|')})\\s*DE\\s*(\\d{4})').firstMatch(t);
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

// ------------------------------------------------------------------ nombre

const _etiquetas = {
  'NOMBRES', 'NOMBRE', 'APELLIDOS', 'APELLIDO', 'FECHA', 'NACIMIENTO', 'EMISION', 'EXPIRACION', 'FIRMA',
  'TITULAR', 'SERIE', 'SECCION', 'CEDULA', 'IDENTIDAD', 'ESTADO', 'PLURINACIONAL', 'BOLIVIA', 'SERVICIO',
  'GENERAL', 'IDENTIFICACION', 'PERSONAL', 'LUGAR', 'DOMICILIO', 'OCUPACION', 'CIVIL', 'SEGIP',
};

/// Una linea que solo trae un nombre: letras y espacios, sin etiquetas.
List<String>? _soloNombre(String linea) {
  final limpia = linea.replaceAll(RegExp(r'[:.,;]'), ' ').trim();
  if (!RegExp(r'^[A-Z]{2,}( [A-Z]{2,})*$').hasMatch(limpia)) return null;
  final palabras = limpia.split(' ');
  if (palabras.any(_etiquetas.contains)) return null;
  return palabras;
}

typedef _Nombre = ({List<String> nombres, List<String> apellidos});

/// MRZ del carnet nuevo, linea 3: "PEREZ<MAMANI<<JUAN<CARLOS<<<<" (apellidos << nombres). Sin "<"
/// de relleno al final, la linea llego a su largo maximo y los nombres pueden estar cortados.
({_Nombre nombre, bool cortado})? _nombreMrz(String r) {
  for (final linea in r.split('\n')) {
    final l = linea.replaceAll(' ', '').replaceAll('«', '<<');
    final m = RegExp(r'^([A-Z]{2,}(?:<[A-Z]{2,})*)<<([A-Z]{2,}(?:<[A-Z]{2,})*)<*$').firstMatch(l);
    if (m != null) {
      return (nombre: (nombres: m[2]!.split('<'), apellidos: m[1]!.split('<')), cortado: !l.endsWith('<'));
    }
  }
  return null;
}

/// Anverso del carnet nuevo: "NOMBRES:" y "APELLIDOS:" con el valor en la misma linea o en la
/// siguiente.
_Nombre? _nombreConEtiquetas(String a) {
  final lineas = a.split('\n').map((l) => l.trim()).toList();
  List<String>? valor(String etiqueta) {
    for (var i = 0; i < lineas.length; i++) {
      final m = RegExp('^$etiqueta\\s*[:.]?\\s*(.*)\$').firstMatch(lineas[i]);
      if (m == null) continue;
      final enLinea = _soloNombre(m[1]!);
      if (enLinea != null) return enLinea;
      if (i + 1 < lineas.length) return _soloNombre(lineas[i + 1]);
    }
    return null;
  }
  final nombres = valor('NOMBRES');
  final apellidos = valor('APELLIDOS');
  return nombres != null && apellidos != null ? (nombres: nombres, apellidos: apellidos) : null;
}

/// Palabras del reverso del carnet antiguo que no son parte del nombre.
const _textoReversoAntiguo = {
  'PERTENECE', 'IMPRESION', 'CERTIFICA', 'FIRMA', 'FOTOGRAFIA', 'NACIDO', 'CIVIL', 'SOLTERO', 'SOLTERA',
  'CASADO', 'CASADA', 'PROFESION', 'OCUPACION', 'DOMICILIO', 'DOCUMENTOS', 'REGISTRADOS', 'DIRECTOR',
  'DIRECTORA', 'DEPARTAMENTAL', 'ESTUDIANTE', 'QUE', 'LA', 'EL',
};

/// Departamentos y ciudades del lugar de nacimiento ("PANDO NICOLAS SUAREZ COBIJA"): no son el nombre.
const _lugares = {'PANDO', 'BENI', 'ORURO', 'POTOSI', 'CHUQUISACA', 'TARIJA', 'COCHABAMBA', 'COBIJA', 'RIBERALTA'};

/// Pedazos del texto vertical del borde ("ESTADO PLURINACIONAL DE BOLIVIA - CEDULA DE IDENTIDAD"),
/// que con la foto un poco inclinada se cuela entre las lineas mal leido ("sTADO PLhuCIONAL DE BOLVIA").
final _textoDelBorde = RegExp(r'TADO|PLUR|PLK|CIONAL|BOLV|BOLIV|CEDUL|IDENTI');

/// Texto de fondo del carnet antiguo: la microletra que llena la tarjeta ("ESTADOPLURINACIONALDEBOLIVIA"
/// repetido; dos vueltas para los pedazos que pasan de una a otra) y el borde vertical. Con sombra o la
/// foto inclinada ML Kit lee pedazos con letras de menos o cambiadas que parecen palabras
/// ("ONALDEOLIVIAE URINAIONALC") y se escapan de [_textoDelBorde].
const _textosDeFondo = [
  'ESTADOPLURINACIONALDEBOLIVIAESTADOPLURINACIONALDEBOLIVIA',
  'ESTADOPLURINACIONALDEBOLIVIACEDULADEIDENTIDAD',
];

/// Menor cantidad de letras a cambiar, agregar o quitar para que [palabra] aparezca dentro de [texto].
int _distanciaDentro(String palabra, String texto) {
  // La primera fila en 0: la palabra puede empezar en cualquier parte del texto.
  var previa = List<int>.filled(texto.length + 1, 0);
  for (var i = 1; i <= palabra.length; i++) {
    final actual = List<int>.filled(texto.length + 1, i);
    for (var j = 1; j <= texto.length; j++) {
      final costo = palabra[i - 1] == texto[j - 1] ? 0 : 1;
      actual[j] = [previa[j] + 1, actual[j - 1] + 1, previa[j - 1] + costo].reduce((a, b) => a < b ? a : b);
    }
    previa = actual;
  }
  // Y puede terminar en cualquier parte.
  return previa.reduce((a, b) => a < b ? a : b);
}

/// La palabra es un pedazo del texto de fondo. De 5 o 6 letras solo si esta tal cual (OLIVIA esta dentro
/// de BOLIVIA y es un nombre real; por eso una linea se descarta recien cuando casi todo es fondo); desde
/// 7 letras se tolera una letra mal leida cada 5.
bool _esDelFondo(String palabra) {
  if (palabra.length < 5) return false;
  final tolerancia = palabra.length >= 7 ? palabra.length ~/ 5 : 0;
  return _textosDeFondo.any((t) => _distanciaDentro(palabra, t) <= tolerancia);
}

/// Parte de las letras de la linea que son texto de fondo (0 a 1).
double _parteDelFondo(List<String> palabras) {
  final letras = palabras.fold<int>(0, (suma, p) => suma + p.length);
  final fondo = palabras.where(_esDelFondo).fold<int>(0, (suma, p) => suma + p.length);
  return letras == 0 ? 1 : fondo / letras;
}

/// Nombre de la linea del carnet antiguo: solo letras, de 2 a 6 palabras y sin el texto fijo del
/// reverso. Quita la basura que el OCR pega delante ("uJUAN", "3JUAN" -> JUAN), corrige la I leida
/// como "!", "|" o "1" dentro de una palabra ("CHIPUNAV!") y quita de las puntas los pedazos largos de
/// la microletra que quedaron en la misma fila. El nombre esta impreso en mayusculas: una linea con
/// varias minusculas, o casi toda de microletra, es texto de fondo mal leido.
List<String>? _nombreDeLinea(String lineaOriginal) {
  final limpia = lineaOriginal
      .replaceAll(RegExp(r'(?<![A-Za-z0-9])[a-z0-9]{1,2}(?=[A-ZÁÉÍÓÚÑ]{2,})'), '')
      .replaceAll(RegExp(r'(?<=[A-ZÁÉÍÓÚÑ])[!|1](?=[A-ZÁÉÍÓÚÑ]|\s|$)'), 'I');
  // ML Kit a veces pone alguna minuscula en un texto en mayusculas ("DURi"): se toleran pocas.
  if (RegExp('[a-z]').allMatches(limpia).length * 3 > RegExp('[A-Za-z]').allMatches(limpia).length) return null;
  final leidas = _soloNombre(normalizarOcr(limpia));
  if (leidas == null) return null;
  final palabras = [...leidas];
  bool microletra(String p) => p.length >= 7 && _esDelFondo(p);
  while (palabras.isNotEmpty && microletra(palabras.first)) {
    palabras.removeAt(0);
  }
  while (palabras.isNotEmpty && microletra(palabras.last)) {
    palabras.removeLast();
  }
  if (palabras.length < 2 || palabras.length > 6) return null;
  if (palabras.any((p) => _textoReversoAntiguo.contains(p) || _lugares.contains(p) || _textoDelBorde.hasMatch(p))) {
    return null;
  }
  if (_parteDelFondo(palabras) >= 0.6) return null;
  return palabras;
}

/// "...e impresion pertenece", a veces con "A:" y el nombre en la misma linea.
final _pertenece = RegExp(r'pertenece\W*(?:A\s*[:.;])?\s*(?:\d{5,10}\s+)?(.*)$', caseSensitive: false);

/// Reverso del carnet antiguo: "...CERTIFICA: Que la firma, fotografia e impresion pertenece / A: JUAN
/// CARLOS PEREZ MAMANI / Nacido el...". El OCR suele dejar "A:" en una linea y
/// el nombre en la de antes o la de despues (segun como este girada la foto), a veces con una linea de
/// microletra en medio. Con la foto inclinada la etiqueta sale mal ("A", "SA", "2A") o no sale: entonces
/// se busca el nombre junto a "Nacido el", la linea que va debajo. Se juntan todas las lineas que pueden
/// ser el nombre, en orden de preferencia, y gana la primera con menos texto de fondo. No separa nombres
/// de apellidos: se proponen los dos ultimos como apellidos (uno si solo hay dos palabras) y la persona
/// lo corrige.
_Nombre? _nombreAntiguo(String reversoOriginal) {
  final lineas = reversoOriginal.split('\n');
  final candidatos = <List<String>>[];
  void probar(String linea) {
    final nombre = _nombreDeLinea(linea);
    if (nombre != null) candidatos.add(nombre);
  }

  void cercaDe(int i, List<int> desplazamientos) {
    for (final d in desplazamientos) {
      if (i + d >= 0 && i + d < lineas.length) probar(lineas[i + d]);
    }
  }

  for (var i = 0; i < lineas.length; i++) {
    final conNombre = RegExp(r'^\s*A\s*[:.;]\s*(?:\d{5,10}\s+)?(.*)$').firstMatch(lineas[i]);
    final sola = RegExp(r'^\s*[0-9A-Za-z]?A\s*[:.;]?\s*$').hasMatch(lineas[i]);
    if (conNombre == null && !sola) continue;
    if (conNombre != null) probar(conNombre[1]!);
    cercaDe(i, const [1, -1, 2, -2]);
  }
  // Despues de "pertenece" va "A:" con el nombre (entre medio puede quedar la linea con los numeros).
  for (var i = 0; i < lineas.length; i++) {
    final pertenece = _pertenece.firstMatch(lineas[i]);
    if (pertenece == null) continue;
    probar(pertenece[1]!);
    cercaDe(i, const [1, 2, 3]);
  }
  for (var i = 0; i < lineas.length; i++) {
    if (normalizarOcr(lineas[i]).contains('NACIDO')) cercaDe(i, const [-1, 1, -2, 2, -3, 3]);
  }
  List<String>? encontrado;
  var menosFondo = double.infinity;
  for (final candidato in candidatos) {
    final fondo = _parteDelFondo(candidato);
    if (fondo < menosFondo) {
      menosFondo = fondo;
      encontrado = candidato;
    }
  }
  if (encontrado == null) return null;
  final corte = encontrado.length == 2 ? 1 : encontrado.length - 2;
  return (nombres: encontrado.sublist(0, corte), apellidos: encontrado.sublist(corte));
}

/// Cada palabra como esta impresa: en mayusculas y con tildes y Ñ si el OCR las leyo (la MRZ no las
/// trae): "PEREZ" -> "PÉREZ" si el carnet dice PÉREZ.
String _comoImpreso(List<String> palabras, String textoOriginal) {
  final originales = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+').allMatches(textoOriginal).map((m) => m[0]!.toUpperCase());
  return palabras.map((p) => originales.firstWhere((o) => normalizarOcr(o) == p, orElse: () => p)).join(' ');
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
    final leido = numero.complemento;
    complemento = leido != null && complementoValido(leido) ? leido : null;
    // Sin "N°" en el anverso pero con MRZ: manda la MRZ (y el complemento solo si es del mismo numero).
    if (mrz != null && _numero.firstMatch(a) == null && mrz[1] != ci) {
      ci = mrz[1];
      complemento = null;
    }
  } else {
    ci = mrz?[1];
  }
  // MRZ completa o etiquetas del anverso: seguro. MRZ cortada (sin etiquetas legibles) o carnet
  // antiguo: la persona revisa y acomoda su nombre.
  final mrzNombre = _nombreMrz(r);
  final etiquetas = _nombreConEtiquetas(a);
  final _Nombre? nombre;
  var seguro = true;
  var cortado = false;
  if (mrzNombre != null && !mrzNombre.cortado) {
    nombre = mrzNombre.nombre;
  } else if (etiquetas != null) {
    nombre = etiquetas;
  } else if (mrzNombre != null) {
    nombre = mrzNombre.nombre;
    seguro = false;
    cortado = true;
  } else {
    nombre = _nombreAntiguo(reverso);
    seguro = false;
  }
  final original = '$anverso\n$reverso';
  return DatosCarnet(
    ci: ci,
    complemento: complemento,
    fechaNacimiento: _fechaNacimiento(a) ?? _fechaNacimiento(r),
    nombres: nombre == null ? null : _comoImpreso(nombre.nombres, original),
    apellidos: nombre == null ? null : _comoImpreso(nombre.apellidos, original),
    nombreSeguro: seguro,
    nombreCortado: cortado,
    palabrasNombres: nombre?.nombres ?? const [],
    palabrasApellidos: nombre?.apellidos ?? const [],
    palabrasDelCarnet: {
      for (final m in RegExp('[A-Z]{2,}').allMatches('$a\n$r'))
        if (!_etiquetas.contains(m[0]) && !_textoReversoAntiguo.contains(m[0]) && !_lugares.contains(m[0])) m[0]!,
    },
  );
}
