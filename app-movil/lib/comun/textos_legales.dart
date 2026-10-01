import 'package:flutter/material.dart';

import '../core/tema.dart';

/// Seccion de un texto legal: titulo y parrafo.
typedef SeccionLegal = ({String titulo, String texto});

/// Texto de ejemplo de las politicas de privacidad. Reemplazar por el texto aprobado.
const List<SeccionLegal> politicasPrivacidad = [
  (
    titulo: 'Qué datos guardamos',
    texto:
        'Tu nombre, carnet de identidad, correo, teléfono y foto de perfil; la ubicación de tu teléfono '
        'mientras usas la app para pedir o realizar un viaje, y el historial de tus viajes y calificaciones.',
  ),
  (
    titulo: 'Para qué los usamos',
    texto:
        'Para conectar pasajeros con conductores, calcular rutas y precios, mostrar la ubicación del '
        'conductor durante el viaje y mantener la seguridad del servicio.',
  ),
  (
    titulo: 'Con quién los compartimos',
    texto:
        'Durante un viaje, el pasajero ve el nombre, la foto, el vehículo y la ubicación del conductor, y '
        'el conductor ve el nombre del pasajero y los puntos de partida y destino. No vendemos tus datos.',
  ),
  (
    titulo: 'Fotos del carnet y de la licencia',
    texto:
        'Para leer tu número, tu nombre y tus fechas, las fotos de tu carnet y de tu licencia se envían a '
        'Gemini, el servicio de inteligencia artificial de Google, solo en el momento de leerlas. Las fotos '
        'quedan guardadas en el servidor de UNITAXI y solo las ve la administración para verificar tu '
        'identidad. Si Gemini no está disponible, la lectura se hace en tu teléfono.',
  ),
  (
    titulo: 'Tus derechos',
    texto:
        'Puedes revisar y corregir tus datos desde Datos personales, y pedir a la administración de '
        'UNITAXI que desactive tu cuenta.',
  ),
];

/// Texto de ejemplo de los terminos y condiciones. Reemplazar por el texto aprobado.
const List<SeccionLegal> terminosCondiciones = [
  (
    titulo: 'Uso del servicio',
    texto:
        'UNITAXI conecta pasajeros con conductores habilitados por la administración. Las cuentas son '
        'personales: no compartas tu usuario ni tu contraseña.',
  ),
  (
    titulo: 'Precio y pago',
    texto:
        'El precio del viaje se muestra antes de pedirlo y se paga al conductor al llegar al destino, en '
        'efectivo o con el QR de su banca móvil. Solo el conductor puede cambiar el método de pago.',
  ),
  (
    titulo: 'Cancelaciones',
    texto:
        'El pasajero puede cancelar una solicitud mientras busca conductor y el viaje antes de que '
        'comience. Las cancelaciones repetidas pueden llevar a la suspensión de la cuenta.',
  ),
  (
    titulo: 'Conductores',
    texto:
        'Los conductores deben mantener vigentes y aprobados sus documentos, y respetar las normas de '
        'tránsito y el trato respetuoso con los pasajeros.',
  ),
  (
    titulo: 'Calificaciones',
    texto:
        'Al terminar un viaje el pasajero puede calificar al conductor. Los comentarios ofensivos se '
        'pueden quitar.',
  ),
];

/// Pantalla de un texto legal (politicas o terminos).
class PantallaTextoLegal extends StatelessWidget {
  final String titulo;
  final List<SeccionLegal> secciones;

  const PantallaTextoLegal({super.key, required this.titulo, required this.secciones});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      appBar: AppBar(
        backgroundColor: ColoresApp.azul,
        foregroundColor: ColoresApp.blanco,
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final seccion in secciones) ...[
                Text(
                  seccion.titulo,
                  style: const TextStyle(color: ColoresApp.azul, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(seccion.texto, style: const TextStyle(color: ColoresApp.texto, fontSize: 14.5, height: 1.5)),
                const SizedBox(height: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
