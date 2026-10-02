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

/// Terminos y condiciones de prueba (2026-10-02): UNITAXI como servicio de mototaxi pensado para los
/// estudiantes de la Universidad Amazonica de Pando. Reemplazar por el texto aprobado. Se muestran en
/// Perfil > Terminos y condiciones y en el modal que se acepta al registrarse (aceptar_terminos.dart).
const List<SeccionLegal> terminosCondiciones = [
  (
    titulo: 'Qué es UNITAXI',
    texto:
        'UNITAXI es una aplicación de prueba que conecta a pasajeros con conductores de mototaxi en la ciudad de '
        'Cobija, Pando. Está pensada principalmente para estudiantes, docentes y personal de la Universidad '
        'Amazónica de Pando (UAP), aunque cualquier persona registrada puede usarla. UNITAXI no es una empresa de '
        'transporte: los viajes los realizan conductores independientes habilitados por la administración.',
  ),
  (
    titulo: 'Tu cuenta y tus datos',
    texto:
        'Para registrarte debes tener al menos 16 años y verificar tu identidad con las fotos de tu carnet de '
        'identidad. Los datos que confirmas (nombre, número de carnet y fecha de nacimiento) deben ser verdaderos '
        'y tuyos. Tu cuenta es personal: no compartas tu usuario ni tu contraseña. Si los datos leídos de tu '
        'carnet están mal puedes enviarlos a revisión (Observado); un administrador los corregirá con tus fotos.',
  ),
  (
    titulo: 'Credenciales de acceso',
    texto:
        'Al aceptar estos términos te enviaremos tu usuario y tu contraseña al correo con el que te registraste. '
        'Si tus datos quedaron en revisión, las recibirás cuando la administración los apruebe. Puedes cambiar tu '
        'contraseña en Perfil > Cambiar contraseña.',
  ),
  (
    titulo: 'Seguridad en el viaje',
    texto:
        'El conductor debe llevar casco para él y un casco para el pasajero, respetar las normas de tránsito y '
        'los límites de velocidad, y no llevar más de un pasajero. El pasajero debe usar el casco durante todo el '
        'viaje, ir sentado y sujetarse bien. Antes de subir, comprueba que la placa y la moto coincidan con las de '
        'la app.',
  ),
  (
    titulo: 'Precio y pago',
    texto:
        'El precio se muestra antes de pedir el viaje. Se paga directamente al conductor al llegar al destino, en '
        'efectivo o con el QR de su banca móvil. El descuento para estudiantes de la UAP, cuando esté disponible, '
        'se aplica solo con la matrícula vigente verificada por la administración.',
  ),
  (
    titulo: 'Cancelaciones y conducta',
    texto:
        'Puedes cancelar mientras se busca conductor o antes de iniciar el viaje. Las cancelaciones repetidas, '
        'el trato ofensivo, el acoso, viajar bajo efectos del alcohol o dañar la moto pueden llevar a la '
        'suspensión o eliminación de la cuenta.',
  ),
  (
    titulo: 'Conductores',
    texto:
        'Para conducir en UNITAXI se necesita licencia de categoría M vigente, carnet de identidad y los datos de '
        'la moto. La administración puede pedir otros documentos (SOAT, RUAT) y suspender a quien no los tenga '
        'vigentes o reciba quejas graves.',
  ),
  (
    titulo: 'Calificaciones y comentarios',
    texto:
        'Al terminar un viaje puedes calificar al conductor. Los comentarios deben ser respetuosos; la '
        'administración puede quitar los que sean ofensivos.',
  ),
  (
    titulo: 'Privacidad',
    texto:
        'Usamos tu ubicación solo mientras pides o realizas un viaje. Las fotos de tu carnet y de tu licencia se '
        'leen con Gemini (inteligencia artificial de Google) al momento de registrarte y quedan guardadas en el '
        'servidor de UNITAXI, donde solo las ve la administración. Más detalles en Políticas de privacidad.',
  ),
  (
    titulo: 'Versión de prueba',
    texto:
        'Esta es una versión de prueba de UNITAXI: el servicio puede cambiar o interrumpirse y estos términos se '
        'pueden actualizar. Si sigues usando la app después de un cambio, aceptas los términos nuevos.',
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
