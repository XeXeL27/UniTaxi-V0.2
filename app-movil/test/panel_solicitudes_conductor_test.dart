import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/core/cliente_api.dart';
import 'package:taxiuap_movil/core/sesion.dart';
import 'package:taxiuap_movil/mapa/controlador_mapa.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/conductor_api.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/flujo_conductor.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/paneles_conductor.dart';

void main() {
  testWidgets('separa la etiqueta de encomienda del avatar y el nombre', (tester) async {
    final flujo = FlujoConductor(
      api: ConductorApi(ClienteApi(Sesion())),
      mapa: ControladorMapa(),
    )
      ..listaAbierta = true
      ..listaCargada = true
      ..solicitudes = [Solicitud.desdeJson({
        'idSolicitud': 1,
        'nombrePasajero': 'ANA FLORES',
        'origenWkt': 'POINT(-68.75 -11.02)',
        'destinoWkt': 'POINT(-68.74 -11.03)',
        'origenDireccion': 'Calle Bruno Racua, Barrio Junin',
        'destinoDireccion': 'Calle Elvira Gutierrez, Barrio Conavi',
        'precioSugerido': 11.38,
        'situacionSolicitud': 'PENDIENTE',
        'datosEntrega': {'tipoEnvio': 'ENCOMIENDA', 'descripcion': 'Documentos'},
      })];

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PanelSolicitudes(flujo: flujo))));

    expect(find.byKey(const ValueKey('tipo-envio-solicitud')), findsOneWidget);
    expect(find.text('Encomienda'), findsOneWidget);
    expect(find.text('ANA FLORES'), findsOneWidget);
  });
}
