import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/core/carnet/lector_documentos.dart';
import 'package:taxiuap_movil/core/carnet/lectura_licencia.dart';

// Lecturas como las que devuelve el servidor (Gemini). Datos inventados.
void main() {
  test('carnet nuevo: nombre de las etiquetas del anverso, corte seguro', () {
    final datos = datosCarnetDeLecturas(
      LecturaFoto.json({
        'aceptada': true, 'formato': 'NUEVO', 'numero': '7654321', 'complemento': '1A',
        'nombres': 'MARÍA ELENA', 'apellidos': 'ROJAS VACA', 'nombreSeparado': true,
        'fechaNacimiento': '1995-04-12',
      }),
      LecturaFoto.json({
        'aceptada': true, 'formato': 'NUEVO', 'numero': '7654321', 'nombres': 'MARIA ELENA',
        'apellidos': 'ROJAS VACA', 'nombreSeparado': true, 'fechaNacimiento': '1995-04-12',
      }),
    );
    expect(datos.ci, '7654321');
    expect(datos.complemento, '1A');
    expect(datos.nombres, 'MARÍA ELENA');
    expect(datos.apellidos, 'ROJAS VACA');
    expect(datos.nombreSeguro, isTrue);
    expect(datos.nombresEditables, isFalse);
    expect(datos.fechaNacimiento, DateTime(1995, 4, 12));
  });

  test('carnet antiguo: un solo renglon, se proponen los dos ultimos como apellidos', () {
    final datos = datosCarnetDeLecturas(
      LecturaFoto.json({'aceptada': true, 'formato': 'ANTIGUO', 'numero': '7654321'}),
      LecturaFoto.json({
        'aceptada': true, 'formato': 'ANTIGUO', 'numero': '7654321',
        'nombreCompleto': 'JUAN CARLOS PEREZ MAMANI', 'fechaNacimiento': '1990-03-15',
      }),
    );
    expect(datos.nombres, 'JUAN CARLOS');
    expect(datos.apellidos, 'PEREZ MAMANI');
    expect(datos.nombreSeguro, isFalse);
    // Solo puede mover el corte, con las mismas palabras.
    expect(datos.revisarNombreEscrito('JUAN', 'CARLOS PEREZ MAMANI'), isNull);
    expect(datos.revisarNombreEscrito('PEDRO', 'PEREZ MAMANI'), isNotNull);
  });

  test('carnet antiguo con el corte propuesto por el servidor: completo, bloqueado y sin aviso', () {
    final datos = datosCarnetDeLecturas(
      LecturaFoto.json({'aceptada': true, 'formato': 'ANTIGUO', 'numero': '7654321'}),
      LecturaFoto.json({
        'aceptada': true, 'formato': 'ANTIGUO', 'numero': '7654321', 'nombres': 'JUAN CARLOS',
        'apellidos': 'PEREZ MAMANI', 'nombreCompleto': 'JUAN CARLOS PEREZ MAMANI', 'fechaNacimiento': '1990-03-15',
      }),
    );
    expect(datos.nombres, 'JUAN CARLOS');
    expect(datos.apellidos, 'PEREZ MAMANI');
    expect(datos.nombreSeguro, isTrue);
    expect(datos.nombresEditables, isFalse);
    expect(datos.apellidosEditables, isFalse);
    expect(datos.revisarNombreEscrito('JUAN CARLOS', 'PEREZ MAMANI'), isNull);

    // Si la licencia separa distinto (con su coma), manda la licencia.
    final licencia = datosLicenciaDeLecturas(
      LecturaFoto.json({'aceptada': true, 'numero': '7654321', 'nombres': 'JUAN', 'apellidos': 'CARLOS PEREZ MAMANI', 'nombreSeparado': true}),
      LecturaFoto.json({'aceptada': true, 'categoria': 'M', 'vencimiento': '2031-01-01'}),
    );
    final cortado = cortarConLicencia(datos, licencia)!;
    expect(cortado.nombres, 'JUAN');
    expect(cortado.apellidos, 'CARLOS PEREZ MAMANI');
  });

  test('licencia: la coma separa nombres y apellidos y corta el nombre del carnet antiguo', () {
    final licencia = datosLicenciaDeLecturas(
      LecturaFoto.json({
        'aceptada': true, 'formato': 'LICENCIA', 'numero': '7654321', 'nombres': 'JUAN',
        'apellidos': 'CARLOS PEREZ MAMANI', 'nombreSeparado': true, 'categoria': 'M',
      }),
      LecturaFoto.json({'aceptada': true, 'formato': 'LICENCIA', 'categoria': 'M', 'vencimiento': '2031-01-01'}),
    );
    expect(licencia.numeroCompleto, '7654321');
    expect(licencia.esMoto, isTrue);
    expect(licencia.vencimiento, DateTime(2031, 1, 1));
    expect(nombreCoincide('JUAN CARLOS PEREZ MAMANI', licencia), isTrue);

    final carnet = datosCarnetDeLecturas(
      LecturaFoto.json({'aceptada': true, 'numero': '7654321'}),
      LecturaFoto.json({'aceptada': true, 'nombreCompleto': 'JUAN CARLOS PEREZ MAMANI', 'fechaNacimiento': '1990-03-15'}),
    );
    final cortado = cortarConLicencia(carnet, licencia)!;
    expect(cortado.nombres, 'JUAN');
    expect(cortado.apellidos, 'CARLOS PEREZ MAMANI');
    expect(cortado.nombreSeguro, isTrue);
  });
}
