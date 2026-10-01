import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/core/carnet/lectura_carnet.dart';
import 'package:taxiuap_movil/core/carnet/lectura_licencia.dart';

// Texto como el que ML Kit lee de una licencia de moto (datos inventados) con la foto girada 0, 90,
// 270 y 180 grados: el orden de las lineas cambia y hay letras mal leidas, igual que en las pruebas
// con fotos reales.
const _anversos = <String>[
  '''
7654321
15/03/2001
Fecha de nacimiento
Ermisión
10/02/2985
7654321
Nro de licencia
MhOLIVIANO
Nacionalidad
10/02/2030
Vencimiento
M
Sexo
MAMANI
JUAN, PEREZ:
NombresApellidos
Tsegip
CSERAC
GENERAL
DENTIFICACION
PERSONAL CATEGORIAM
STADo PzINACION DE BOLIVIA
LICENCIA PARA CONDUCIR''',
  '''
M
hsegip
15/03/2001
Fecha de nacimiento
10/02/205
Ermisión
10/02/2030
Vencimiento
7654321
Nro. de licencia
MhoLIVIANO
SexoNacionalidad
MAMANI
JUAN, PẸREZ
Nombres Apeldos
7654321
SERAACISGENERAL DENTIFICACION PERsONAL CATEGORIA M
LICENCHA PARA CONDUCIR
FESTADO PRINACION DE BOLIVIA''',
  '''
STAD9 PRINACION DE BOLIVIA LICENCA PARA CONDUCIR
SERACISGENERAL
DNTIRCACION PERSONAL CATEGORÍA M
7654321
NombresApelidos
JUAN, PEREZ
MAMANI
SexoNacionalidad
MOLIVIANO
Nro de licencia
7654321
Emisión
10/02/294s
Vencimiento
10/02/2030
Fecha de nacimiento
15/03/2001
hsegip,
M''',
  '''
LICENCA PARA GONDUCIR
SERAICISSENERAL DNTIFICACION PERsONAL CATEGORIA M
FESTADO PRINACION DE BOLIVIA
Dhsegip
Nombres Apeldos
JUAN, PEREZ
MAMNI
Nacionalidad
hOLIVIANO
Sexo
M
M
10/02/2030
Vencimiento
Nro de licencia
7654321
Fecha de nacimiento
10/02/205
Emisión
15/03/2001
7654321''',
];

const _reversos = <String>[
  '''
O RH ( + ) No
Grupo S.
Audífonos
No
Lentes
Motocicletas, triciclos y cuadriciclos
M
10/02/2030
VENCIMIENTO
10/02/2025
EMISION
7654321
OSegie''',
  '''
Motocicletas, triciclos y cuadriciclos
egip
10/02/2030
VENCIMIENTO
10/02/2025
EMISION
No
Lentes
M
No
Audifonos
O RH ( +)
Grupo S.
7654321''',
  '''
7654321
Audífonos
Grupo S.
O RH ( + ) No
M
EMISION
Lentes
No
OhSegip
10/02/2025
VENCIMIENTO
10/02/2030
Motocicletas, triciclos y cuadriciclos''',
  '''
egip
7654321
EMISION
10/02/2025
VENCIMIENTO
10/02/2030
ME
Motocicletas, triciclos y cuadriciclos
Lentes
No
Audifonos
No
Grupo S.
O RH ( +)''',
];

const _carnetAnverso = '''
ESTADO PLURINACIONAL DE BOLIVIA
CEDULA DE IDENTIDAD
N° 7654321
NOMBRES:
JUAN
APELLIDOS:
PEREZ MAMANI
FECHA DE NACIMIENTO:
15/03/2001
''';

void main() {
  test('reconoce el anverso y el reverso en las cuatro posiciones', () {
    for (final a in _anversos) {
      expect(pareceAnversoLicencia(a), isTrue, reason: a);
      expect(pareceReversoLicencia(a), isFalse, reason: a);
    }
    for (final r in _reversos) {
      expect(pareceReversoLicencia(r), isTrue, reason: r);
      expect(pareceAnversoLicencia(r), isFalse, reason: r);
    }
  });

  test('un carnet de identidad o una factura no pasan como licencia', () {
    expect(pareceAnversoLicencia(_carnetAnverso), isFalse);
    expect(pareceReversoLicencia(_carnetAnverso), isFalse);
    const factura = 'FACTURA N° 1234567\nNIT 1020304050\nTOTAL Bs 80,00\nVENCIMIENTO 01/01/2030';
    expect(pareceAnversoLicencia(factura), isFalse);
    expect(pareceReversoLicencia(factura), isFalse);
  });

  test('lee numero, categoria M y vencimiento con cualquier combinacion de posiciones', () {
    for (final a in _anversos) {
      for (final r in _reversos) {
        final datos = extraerDatosLicencia(a, r);
        expect(datos.numero, '7654321');
        expect(datos.categoria, 'M');
        expect(datos.esMoto, isTrue);
        expect(datos.vencimiento, DateTime(2030, 2, 10));
        expect(datos.completa, isTrue);
      }
    }
  });

  test('el nombre de la licencia coincide con el de la persona aunque el OCR lea mal una letra', () {
    for (final a in _anversos) {
      final datos = extraerDatosLicencia(a, _reversos.first);
      expect(nombreCoincide('Juan Perez Mamani', datos), isTrue, reason: a);
      expect(nombreCoincide('JUAN PEREZ MAMANI', datos), isTrue);
      expect(nombreCoincide('Luis Rojas Vaca', datos), isFalse);
      expect(nombreCoincide('Juan Rojas', datos), isFalse);
      expect(nombreEnCarnet(datos, _carnetAnverso), isTrue);
      expect(nombreEnCarnet(datos, 'CEDULA DE IDENTIDAD\nLUIS ROJAS'), isFalse);
    }
  });

  test('la Ñ y las tildes no cambian la comparacion', () {
    const anverso = 'LICENCIA PARA CONDUCIR\nESTADO PLURINACIONAL DE BOLIVIA\nCATEGORIA M\nNombres Apellidos\n'
        'JOSÉ, MUÑOZ\nPEÑA\nNro. de licencia\n7654321\n28/04/2030';
    final datos = extraerDatosLicencia(anverso, 'VENCIMIENTO 28/04/2030 EMISION 28/04/2025 7654321 Grupo S.');
    expect(nombreCoincide('José Muñoz Peña', datos), isTrue);
    expect(nombreCoincide('JOSE MUNOZ PENA', datos), isTrue);
  });

  test('otra categoria se lee para rechazarla', () {
    final anverso = _anversos.first.replaceFirst('CATEGORIAM', 'CATEGORIA B');
    final reverso = _reversos.first.replaceFirst('Motocicletas, triciclos y cuadriciclos', 'Vehiculos livianos');
    final datos = extraerDatosLicencia(anverso, reverso);
    expect(datos.categoria, 'B');
    expect(datos.esMoto, isFalse);
  });

  test('licencia con complemento: 6565204-1B y 123456-1H', () {
    for (final (numero, complemento) in [('6565204', '1B'), ('123456', '1H')]) {
      final anverso = _anversos.first.replaceAll('7654321', '$numero-$complemento');
      final reverso = _reversos.first.replaceAll('7654321', numero);
      final datos = extraerDatosLicencia(anverso, reverso);
      expect(datos.numero, numero);
      expect(datos.complemento, complemento);
      expect(datos.numeroCompleto, '$numero-$complemento');
    }
    final sinComplemento = extraerDatosLicencia(_anversos.first, _reversos.first);
    expect(sinComplemento.complemento, isNull);
    expect(sinComplemento.numeroCompleto, '7654321');
  });

  test('complemento: la sigla del departamento no es complemento', () {
    expect(complementoValido('1B'), isTrue);
    expect(complementoValido('PDO'), isFalse);
    expect(complementoValido('LP'), isFalse);
  });

  test('nombre bajo "Nombres, Apellidos": la coma separa nombres de apellidos y la etiqueta no es el nombre', () {
    const cabecera = 'LICENCIA PARA CONDUCIR\nESTADO PLURINACIONAL DE BOLIVIA\nCATEGORIA M\n';
    const resto = '\nNro. de licencia\n7654321\n10/02/2030';
    for (final titular in [
      'Nombres, Apellidos\nJUAN CARLOS, PEREZ\nMAMANI',
      'Nombres, Apellidos: JUAN CARLOS, PEREZ MAMANI',
      'MAMANI\nJUAN CARLOS, PEREZ:\nNombres, Apellidos',
    ]) {
      final datos = extraerDatosLicencia('$cabecera$titular$resto', _reversos.first);
      expect(datos.nombres, ['JUAN', 'CARLOS'], reason: titular);
      expect(datos.apellidos.first, 'PEREZ', reason: titular);
      expect(nombreCoincide('JUAN CARLOS PEREZ MAMANI', datos), isTrue, reason: titular);
    }
  });

  test('el numero de licencia es el del carnet aunque la licencia traiga otros numeros', () {
    final anverso = '8899001\n${_anversos.first}';
    final reverso = '${_reversos.first} 8899001';
    expect(extraerDatosLicencia(anverso, reverso).numero, '8899001');
    expect(extraerDatosLicencia(anverso, reverso, ci: '7654321').numero, '7654321');
    // Si el numero del carnet no esta en la licencia, se elige como siempre (y luego no coincide).
    expect(extraerDatosLicencia(anverso, reverso, ci: '1112223').numero, '8899001');
  });

  test('la coma de la licencia corta el nombre del carnet antiguo', () {
    const reversoCarnet = 'CERTIFICA: Que la firma, fotografía\ne impresión pertenece\nA: MARIA ELENA ROJAS VACA\n'
        'Nacido el 27 de Agosto de 1998';
    final carnet = extraerDatosCarnet('CEDULA DE IDENTIDAD\nNo 7654321', reversoCarnet);
    expect(carnet.nombreSeguro, isFalse);
    DatosLicencia licencia(String titular) =>
        extraerDatosLicencia('LICENCIA PARA CONDUCIR\nCATEGORIA M\nNombres, Apellidos\n$titular\n7654321', '');
    // Un nombre y tres apellidos: el carnet solo no lo puede saber.
    final unNombre = cortarConLicencia(carnet, licencia('MARIA, ELENA ROJAS'))!;
    expect(unNombre.nombres, 'MARIA');
    expect(unNombre.apellidos, 'ELENA ROJAS VACA');
    expect(unNombre.nombreSeguro, isTrue);
    expect(unNombre.nombresEditables, isFalse);
    final dosNombres = cortarConLicencia(carnet, licencia('MARIA ELENA, ROJAS'))!;
    expect(dosNombres.nombres, 'MARIA ELENA');
    expect(dosNombres.apellidos, 'ROJAS VACA');
    // Otra persona o una licencia sin coma: no se corta.
    expect(cortarConLicencia(carnet, licencia('JUAN, ROJAS')), isNull);
    expect(cortarConLicencia(carnet, licencia('MARIA ELENA ROJAS')), isNull);
  });
}
