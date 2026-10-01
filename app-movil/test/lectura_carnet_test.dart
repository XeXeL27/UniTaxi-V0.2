import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/core/carnet/lectura_carnet.dart';

// Textos como los devuelve el OCR de las fotos de ejemplo (carnet nuevo y antiguo).
const _anversoNuevo = '''
ESTADO PLURINACIONAL DE BOLIVIA
SERVICIO GENERAL DE IDENTIFICACIÓN PERSONAL
CÉDULA DE
IDENTIDAD
3000000-LA
SERIE: SECCIÓN:
41443 44442
N° 7654321
NOMBRES:
JUAN
APELLIDOS:
PEREZ MAMANI
FECHA DE NACIMIENTO:
07/11/2002
FECHA DE EMISIÓN: FECHA DE EXPIRACIÓN:
08/11/2024 08/11/2029
FIRMA DEL TITULAR
''';

const _reversoNuevo = '''
LUGAR DE NACIMIENTO:
PANDO - NICOLAS SUAREZ - COBIJA
DOMICILIO:
B/ CENTRAL, MUN. DE COBIJA
OCUPACIÓN:
ESTUDIANTE
ESTADO CIVIL:
SOLTERO
ABG. NOMBRE DE EJEMPLO
DIRECTORA GENERAL EJECUTIVA a.i. - SEGIP
I<BOL7654321<1<<<<<<<<<<<<<<<<<<<<<
0211071M2911087BOL<<<<<<<<<<<2
PEREZ<MAMANI<<JUAN<<<<<<<<
''';

const _anversoAntiguo = '''
ESTADO PLURINACIONAL DE BOLIVIA
CÉDULA DE IDENTIDAD
serie 33333
sección 21222
No 8123456
de BENI
Válida hasta el 15 de Septiembre de 2026
ABCDEFGH-12345678
FIRMA DEL INTERESADO
0200000 7C-A4
''';

const _reversoAntiguo = '''
ESTADO PLURINACIONAL DE BOLIVIA - CEDULA DE IDENTIDAD
EL SERVICIO GENERAL DE IDENTIFICACIÓN PERSONAL
CERTIFICA: Que la firma, fotografía e impresión pertenece
A: 8123456 MARIA ELENA ROJAS VACA
Nacido el 27 de Agosto de 1998
En PANDO - NICOLAS SUAREZ - COBIJA
Estado Civil SOLTERO
Profesión/Ocupación ESTUDIANTE
Domicilio COBIJA S/N B.- CENTRAL
DOCUMENTOS REGISTRADOS
''';

void main() {
  test('reconoce el anverso y el reverso de los dos modelos', () {
    expect(pareceAnverso(_anversoNuevo), isTrue);
    expect(pareceReverso(_anversoNuevo), isFalse);
    expect(pareceReverso(_reversoNuevo), isTrue);
    expect(pareceAnverso(_reversoNuevo), isFalse);
    expect(pareceAnverso(_anversoAntiguo), isTrue);
    expect(pareceReverso(_reversoAntiguo), isTrue);
    expect(pareceAnverso(_reversoAntiguo), isFalse);
  });

  test('rechaza fotos que no son un carnet', () {
    const factura = 'FACTURA N° 1234567\nNIT 1020304050\nTOTAL Bs 80,00';
    expect(pareceAnverso(factura), isFalse);
    expect(pareceReverso(factura), isFalse);
    expect(pareceAnverso(''), isFalse);
  });

  test('carnet nuevo: numero y fecha, sin tomar el 3000000-LA como complemento', () {
    final datos = extraerDatosCarnet(_anversoNuevo, _reversoNuevo);
    expect(datos.ci, '7654321');
    expect(datos.complemento, isNull);
    expect(datos.fechaNacimiento, DateTime(2002, 11, 7));
  });

  test('carnet antiguo: numero y "Nacido el"', () {
    final datos = extraerDatosCarnet(_anversoAntiguo, _reversoAntiguo);
    expect(datos.ci, '8123456');
    expect(datos.complemento, isNull);
    expect(datos.fechaNacimiento, DateTime(1998, 8, 27));
  });

  test('complemento pegado al numero con guion', () {
    final datos = extraerDatosCarnet(_anversoNuevo.replaceFirst('N° 7654321', 'N° 7654321-1B'), _reversoNuevo);
    expect(datos.ci, '7654321');
    expect(datos.complemento, '1B');
  });

  test('complementos 6565204-1B y 123456-1H, con o sin "N°"', () {
    for (final (numero, ci, complemento) in [('6565204-1B', '6565204', '1B'), ('123456-1H', '123456', '1H')]) {
      final conEtiqueta = extraerDatosCarnet(_anversoNuevo.replaceFirst('N° 7654321', 'N° $numero'), '');
      expect(conEtiqueta.ci, ci);
      expect(conEtiqueta.complemento, complemento);
      final sinEtiqueta = extraerDatosCarnet(_anversoNuevo.replaceFirst('N° 7654321', numero), '');
      expect(sinEtiqueta.ci, ci, reason: numero);
      expect(sinEtiqueta.complemento, complemento, reason: numero);
    }
  });

  test('nombre del carnet nuevo: de la MRZ, con las tildes del anverso', () {
    final datos = extraerDatosCarnet(_anversoNuevo.replaceFirst('PEREZ MAMANI', 'PÉREZ MAMANI'), _reversoNuevo);
    expect(datos.nombres, 'JUAN');
    expect(datos.apellidos, 'PÉREZ MAMANI');
    expect(datos.nombreCompleto, 'JUAN PÉREZ MAMANI');
  });

  test('nombre del carnet nuevo sin MRZ: etiquetas NOMBRES y APELLIDOS', () {
    final reverso = _reversoNuevo.replaceFirst('PEREZ<MAMANI<<JUAN<<<<<<<<', '');
    final anverso = _anversoNuevo.replaceFirst('NOMBRES:\nJUAN', 'NOMBRES: JUAN CARLOS').replaceFirst('PEREZ MAMANI', 'DE LA CRUZ');
    final datos = extraerDatosCarnet(anverso, reverso);
    expect(datos.nombres, 'JUAN CARLOS');
    expect(datos.apellidos, 'DE LA CRUZ');
  });

  test('nombre del carnet antiguo: linea "A:" del reverso', () {
    final datos = extraerDatosCarnet(_anversoAntiguo, _reversoAntiguo);
    expect(datos.nombres, 'MARIA ELENA');
    expect(datos.apellidos, 'ROJAS VACA');
  });

  test('carnet antiguo: el corte no es seguro y la persona acomoda las mismas palabras', () {
    final datos = extraerDatosCarnet(_anversoAntiguo, _reversoAntiguo);
    expect(datos.nombreSeguro, isFalse);
    expect(datos.nombresEditables, isTrue);
    expect(datos.apellidosEditables, isTrue);
    // Un nombre y tres palabras de apellido, o tres nombres y un apellido: valen.
    expect(datos.revisarNombreEscrito('María', 'Elena Rojas Vaca'), isNull);
    expect(datos.revisarNombreEscrito('Maria Elena Rojas', 'Vaca'), isNull);
    // Otras palabras, otro orden o un campo vacio: no.
    expect(datos.revisarNombreEscrito('Maria Elena', 'Rojas Paz'), isNotNull);
    expect(datos.revisarNombreEscrito('Elena Maria', 'Rojas Vaca'), isNotNull);
    expect(datos.revisarNombreEscrito('Maria Elena Rojas Vaca', ''), isNotNull);
  });

  test('carnet antiguo: "A:" sola y el nombre antes o despues, con basura del OCR', () {
    String reverso(List<String> lineas) => lineas.join('\n');
    final casos = {
      // Foto derecha: el nombre despues de "A:".
      reverso(['EL SERVICIO GENERAL DE IDENTIFICACIÓN PERSONAL', 'CERTIFICA: Que la firma, fotografía',
        'e impresión pertenece', '8123456', 'A:', 'MARIA ELENA ROJAS VACA', 'Nacido el 27 de Agosto de 1998',
        'En', 'PANDO NICOLAS SUAREZ-COBIJA']): 'MARIA ELENA ROJAS VACA',
      // De cabeza: el nombre antes de "A:" y el numero pegado al texto de despues.
      reverso(['DOCUMENTOS REGISTRADOS', 'PANDO NICOLAS SUAREZ -COBIJA', 'En', 'Nacido el 27 de Agosto de 1998',
        'MARIA ELENA ROJAS VACA', 'A:', '8123456 e impresión pertenece', 'CERTIFICA: Que la firma, fotografía']):
          'MARIA ELENA ROJAS VACA',
      // De costado: letra suelta pegada delante del nombre.
      reverso(['CERTIFICA: Que la firma, fotografía', 'e impresión pertenece', '8123456',
        'uMARIA ELENA ROJAS VACA', 'A:', 'PANDO NICOLAS SUAREZ -COBIJA', 'Nacido el27 de Agosto de 1998']):
          'MARIA ELENA ROJAS VACA',
      // Numero suelto pegado delante del nombre.
      reverso(['e impresión pertenece', '8123456', 'A:', '3MARIA ELENA ROJAS VACA', 'Nacido el 27 de Agosto de 1998']):
          'MARIA ELENA ROJAS VACA',
    };
    casos.forEach((texto, esperado) {
      final datos = extraerDatosCarnet(_anversoAntiguo, texto);
      expect('${datos.palabrasNombres.join(' ')} ${datos.palabrasApellidos.join(' ')}', esperado, reason: texto);
      expect(datos.nombreSeguro, isFalse);
    });
  });

  test('carnet antiguo inclinado: "A:" mal leida o perdida y el borde colado entre las lineas', () {
    String reverso(List<String> lineas) => lineas.join('\n');
    const cabecera = ['EL SERVICIO GENERAL DE IDENTIFICACIÓN PERSONAL', 'CERTIFICA: Que la firma, fotografía',
      'e impresión pertenece', '8123456'];
    final casos = [
      // Sin "A:": el nombre va justo antes de "Nacido el".
      reverso([...cabecera, 'MARIA ELENA ROJAS VACA', 'Nacido el .27 de Agosto de 1998', 'En', 'Estado Civil SOLTERO',
        'PANDO NICOLAS SUAREZ-COBIJA', 'bEKRFAVEN BEN', 'DOCUMENTOS REGISTRADOS']),
      // "A:" leida como "SA" y el nombre despues de "Nacido el".
      reverso([...cabecera, 'SA', '2En', 'SNacido el 27 de Agosto de 1998', 'MARIA ELENA ROJAS VACA',
        'PANDO NICOLAS SUAREZ -COB1JA', 'Estado Civil SOLTERO']),
      // "A" sin dos puntos y el borde vertical en medio.
      reverso([...cabecera, 'sSTADO PLữKhAGIONĂL DE B', 'A', 'MARIA ELENA ROJAS VACA', 'Nacido el27 de Agosto de 1998']),
      // "2A" y el borde antes del nombre.
      reverso([...cabecera, '2A', 'EsTADO PLlkhuCLONAL', 'MARIA ELENA ROJAS VACA', 'Nacido el 27de Agosto de 1998']),
      // "A:" bien leida, pero el borde queda entre la etiqueta y el nombre.
      reverso([...cabecera, 'A:', 'sTADO PLhuCIONAL DE BOLVIA CL', 'MARIA ELENA ROJAS VACA', 'En',
        'Nacido el27 de Agosto de 1998', 'PANDO NICOLAS SUAREZ-COBIJA']),
      // El borde leido todo en mayusculas.
      reverso([...cabecera, 'A:', 'STADO PLURINACIONAL DE BOLIVIA', 'MARIA ELENA ROJAS VACA', 'Nacido el 27 de Agosto de 1998']),
      // Lugar de nacimiento sin guiones junto a "Nacido el".
      reverso([...cabecera, 'MARIA ELENA ROJAS VACA', 'En', 'PANDO NICOLAS SUAREZ COBIJA', 'Nacido el 27 de Agosto de 1998']),
    ];
    for (final texto in casos) {
      final datos = extraerDatosCarnet(_anversoAntiguo, texto);
      expect('${datos.palabrasNombres.join(' ')} ${datos.palabrasApellidos.join(' ')}', 'MARIA ELENA ROJAS VACA',
          reason: texto);
    }
  });

  test('carnet antiguo: la microletra del fondo leida como palabras no pasa por nombre', () {
    String reverso(List<String> lineas) => lineas.join('\n');
    const cabecera = ['EL SERVICIO GENERAL DE IDENTIFICACIÓN PERSONAL', 'CERTIFICA: Que la firma, fotografía',
      'e impresión pertenece', '8123456'];
    final casos = [
      // Pedazos de "...NACIONALDEBOLIVIAESTADOPLURINACIONAL..." con letras de menos, entre "A:" y el nombre.
      reverso([...cabecera, 'A:', 'ONALDEOLIVIAE URINAIONALC', 'MARIA ELENA ROJAS VACA', 'Nacido el 27 de Agosto de 1998']),
      // La microletra antes de "A:" y el nombre despues de "Nacido el".
      reverso([...cabecera, 'ONALDEOLIVIAE URINAIONALC', 'A', 'Nacido el 27 de Agosto de 1998', 'MARIA ELENA ROJAS VACA']),
      // Un pedazo largo de microletra en la misma fila que el nombre.
      reverso([...cabecera, 'A: MARIA ELENA ROJAS VACA NALDEBOLIIAESTAD', 'Nacido el 27 de Agosto de 1998']),
    ];
    for (final texto in casos) {
      final datos = extraerDatosCarnet(_anversoAntiguo, texto);
      expect('${datos.palabrasNombres.join(' ')} ${datos.palabrasApellidos.join(' ')}', 'MARIA ELENA ROJAS VACA',
          reason: texto);
    }
    // Solo microletra: no inventa un nombre, la persona lo escribe.
    final soloFondo = extraerDatosCarnet(_anversoAntiguo,
        reverso([...cabecera, 'A:', 'ONALDEOLIVIAE URINAIONALC', 'Nacido el 27 de Agosto de 1998']));
    expect(soloFondo.tieneNombre, isFalse);
    expect(soloFondo.nombresEditables, isTrue);
  });

  test('carnet antiguo: un nombre real que esta dentro de BOLIVIA sigue valiendo', () {
    final datos = extraerDatosCarnet(_anversoAntiguo,
        'CERTIFICA: Que la firma\n8123456\nA: OLIVIA ROJAS VACA\nNacido el 27 de Agosto de 1998');
    expect(datos.nombreCompleto, 'OLIVIA ROJAS VACA');
  });

  test('carnet antiguo: I leida como "!" o "1" y el dia pegado a "de"', () {
    final datos = extraerDatosCarnet(_anversoAntiguo,
        'CERTIFICA: Que la firma\n8123456\nA:\nLU1S ALBERTO MAMANI QU!SPE\nNacido el27de Agosto de1998\nEn');
    expect(datos.nombreCompleto, 'LUIS ALBERTO MAMANI QUISPE');
    expect(datos.fechaNacimiento, DateTime(1998, 8, 27));
  });

  test('nombre sin leer: se escribe y cada palabra debe estar en las fotos del carnet', () {
    // El nombre quedo mezclado con basura y no se pudo separar solo.
    final datos = extraerDatosCarnet(_anversoAntiguo,
        'CERTIFICA: Que la firma\n8123456\nA: MARIAELENA ROJAS VACA 4x2 dE\nNacido el 27 de Agosto de 1998\nPANDO COBIJA');
    expect(datos.tieneNombre, isFalse);
    expect(datos.nombresEditables, isTrue);
    expect(datos.apellidosEditables, isTrue);
    expect(datos.revisarNombreEscrito('María Elena', 'Rojas Vaca'), isNull);
    // Una letra distinta en una palabra larga se tolera (lectura del OCR).
    expect(datos.revisarNombreEscrito('Maria Elena', 'Rojas Vacas'), isNull);
    // Palabras que no estan en el carnet, el texto fijo o el lugar de nacimiento: no.
    expect(datos.revisarNombreEscrito('Maria Elena', 'Rojas Paz'), contains('PAZ'));
    expect(datos.revisarNombreEscrito('Pando', 'Cobija'), isNotNull);
    expect(datos.revisarNombreEscrito('Maria', ''), isNotNull);
  });

  test('carnet antiguo con dos palabras pegadas: la persona las separa', () {
    final datos = extraerDatosCarnet(_anversoAntiguo, 'CERTIFICA: Que la firma\nA:\nMARIAELENA ROJAS VACA\nNacido el 27 de Agosto de 1998');
    expect(datos.nombres, 'MARIAELENA');
    expect(datos.revisarNombreEscrito('Maria Elena', 'Rojas Vaca'), isNull);
    expect(datos.revisarNombreEscrito('Maria Elena Rojas', 'Vaca'), isNull);
    expect(datos.revisarNombreEscrito('Maria Elena', 'Rojas Paz'), isNotNull);
  });

  test('MRZ completa: seguro, no se edita', () {
    final datos = extraerDatosCarnet(_anversoNuevo, _reversoNuevo);
    expect(datos.nombreSeguro, isTrue);
    expect(datos.nombresEditables, isFalse);
    expect(datos.revisarNombreEscrito('cualquier', 'cosa'), isNull);
  });

  test('MRZ cortada sin etiquetas: apellidos fijos, nombres se completan', () {
    final anverso = _anversoNuevo.replaceFirst('NOMBRES:\nJUAN\nAPELLIDOS:\nPEREZ MAMANI\n', '');
    final reverso = _reversoNuevo.replaceFirst('PEREZ<MAMANI<<JUAN<<<<<<<<', 'PEREZ<MAMANI<<JUAN<CARLOS<ALBER');
    final datos = extraerDatosCarnet(anverso, reverso);
    expect(datos.nombreCortado, isTrue);
    expect(datos.nombresEditables, isTrue);
    expect(datos.apellidosEditables, isFalse);
    expect(datos.revisarNombreEscrito('Juan Carlos Alberto', 'Perez Mamani'), isNull);
    expect(datos.revisarNombreEscrito('Juan Carlos Alberto Luis', 'Pérez Mamani'), isNull);
    expect(datos.revisarNombreEscrito('Juan Alberto', 'Perez Mamani'), isNotNull);
    expect(datos.revisarNombreEscrito('Juan Carlos Alberto', 'Perez'), isNotNull);
  });

  test('MRZ cortada pero con etiquetas en el anverso: manda el anverso', () {
    final anverso = _anversoNuevo.replaceFirst('NOMBRES:\nJUAN', 'NOMBRES:\nJUAN CARLOS ALBERTO');
    final reverso = _reversoNuevo.replaceFirst('PEREZ<MAMANI<<JUAN<<<<<<<<', 'PEREZ<MAMANI<<JUAN<CARLOS<ALBER');
    final datos = extraerDatosCarnet(anverso, reverso);
    expect(datos.nombreSeguro, isTrue);
    expect(datos.nombres, 'JUAN CARLOS ALBERTO');
  });

  test('sin nombre legible no inventa uno', () {
    final datos = extraerDatosCarnet('CEDULA DE IDENTIDAD\nN° 7654321', 'DOMICILIO X\nESTADO CIVIL SOLTERO');
    expect(datos.tieneNombre, isFalse);
  });

  test('sin "N°" legible usa la MRZ y sin fecha con etiqueta usa la MRZ', () {
    final anverso = _anversoNuevo.replaceFirst('N° 7654321', '').replaceFirst('07/11/2002', '');
    final datos = extraerDatosCarnet(anverso, _reversoNuevo);
    expect(datos.ci, '7654321');
    expect(datos.fechaNacimiento, DateTime(2002, 11, 7));
  });

  test('OCR real: "No" lejos del numero y BOLIVIA mal leido', () {
    const anverso = 'No\nESTADO PLURINACIONAL DE BOLIVEA\nCEDULA DE IDENTIDAD\n8123456\nBIO\nABCDEFGH-12345678\n'
        'serie\n33333\nseccion\n21222\nValida hasta el 15 de Septiembre de 2026\nOQH\n0200000 70-A4';
    expect(pareceAnverso(anverso), isTrue);
    final datos = extraerDatosCarnet(anverso, _reversoAntiguo);
    expect(datos.ci, '8123456');
    expect(datos.fechaNacimiento, DateTime(1998, 8, 27));
  });

  test('OCR real: anio de nacimiento mal leido en el anverso, se usa la MRZ', () {
    final anverso = _anversoNuevo.replaceFirst('07/11/2002', '07/11/2902');
    final reverso = _reversoNuevo.replaceFirst('I<BOL', 'I <BOL').replaceFirst('0211071M', '0211071 M');
    final datos = extraerDatosCarnet(anverso, reverso);
    expect(datos.ci, '7654321');
    expect(datos.fechaNacimiento, DateTime(2002, 11, 7));
  });

  test('carnet antiguo: el nombre va despues de "...e impresión pertenece A:"', () {
    final casos = [
      // "A:" y el nombre en la misma linea que "pertenece".
      'EL SERVICIO GENERAL DE IDENTIFICACIÓN PERSONAL\nCERTIFICA: Que la firma, fotografía\n'
          'e impresión pertenece A: MARIA ELENA ROJAS VACA\nEn PANDO - NICOLAS SUAREZ - COBIJA',
      // Sin "A:" ni "Nacido el" legibles: la linea de los numeros en medio y el nombre despues.
      'CERTIFICA: Que la firma, fotografía\ne impresión pertenece\n8123456 200690\nMARIA ELENA ROJAS VACA\n'
          'Estado Civil SOLTERO\nProfesión/Ocupación ESTUDIANTE\nDomicilio B. CENTRAL',
    ];
    for (final texto in casos) {
      final datos = extraerDatosCarnet(_anversoAntiguo, texto);
      expect(datos.nombreCompleto, 'MARIA ELENA ROJAS VACA', reason: texto);
    }
  });
}
