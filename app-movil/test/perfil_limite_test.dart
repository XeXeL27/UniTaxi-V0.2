import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taxiuap_movil/comun/datos_perfil.dart';
import 'package:taxiuap_movil/comun/perfil_api.dart';
import 'package:taxiuap_movil/core/cliente_api.dart';
import 'package:taxiuap_movil/core/sesion.dart';

void main() {
  test(
    'actualiza únicamente el límite de adelanto mediante la API exclusiva',
    () async {
      final cliente = _ClienteEspia();
      final perfil = PerfilApi(cliente);

      final respuesta = await perfil.actualizarLimiteAdelantoCompra(
        125.50,
        'secreto',
      );

      expect(cliente.ruta, '/api/conductor/perfil/limite-adelanto-compra');
      expect(cliente.cuerpo, {
        'limiteAdelantoCompra': 125.50,
        'password': 'secreto',
      });
      expect(respuesta.limiteAdelantoCompra, 125.50);
    },
  );

  testWidgets(
    'el perfil del conductor muestra el límite de adelanto separado',
    (tester) async {
      final cliente = _ClienteEspia();
      final perfil = Perfil(
        nombres: 'ANA',
        apellidos: 'REPARTIDORA',
        limiteAdelantoCompra: 80,
      );

      await tester.pumpWidget(
        Provider<ClienteApi>.value(
          value: cliente,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DatosPerfil(
                  perfil: perfil,
                  esConductor: true,
                  alGuardar: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Límite para compras'), findsOneWidget);
      expect(find.text('80 Bs'), findsOneWidget);
    },
  );
}

class _ClienteEspia extends ClienteApi {
  _ClienteEspia() : super(Sesion());

  String? ruta;
  Map<String, dynamic>? cuerpo;

  @override
  Future<dynamic> patch(String ruta, Map<String, dynamic> cuerpo) async {
    this.ruta = ruta;
    this.cuerpo = cuerpo;
    return {
      'limiteAdelantoCompra': 125.50,
      'nombres': 'ANA',
      'apellidos': 'REPARTIDORA',
    };
  }
}
