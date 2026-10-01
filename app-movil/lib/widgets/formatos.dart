import 'package:flutter/services.dart';

/// Pasa a mayusculas lo que se escribe (la ñ pasa a Ñ).
class MayusculasFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue anterior, TextEditingValue nuevo) =>
      nuevo.copyWith(text: nuevo.text.toUpperCase());
}

/// Formatos de los campos del registro y del perfil, iguales a los que valida el backend
/// (ReglasRegistro).
class Formatos {
  /// Celular boliviano: 8 digitos que empiezan con 6 o 7.
  static final celular = RegExp(r'^[67]\d{7}$');

  /// Marca de la moto: solo letras en mayusculas (con espacios entre palabras).
  static final marca = RegExp(r'^[A-ZÑ]+( [A-ZÑ]+)*$');

  /// Modelo: letras y numeros (con espacio o guion entre ellos).
  static final modelo = RegExp(r'^[A-Za-z0-9Ññ]+([ -][A-Za-z0-9Ññ]+)*$');

  /// Color: solo letras.
  static final color = RegExp(r'^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+( [A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+)*$');

  static final soloDigitos = FilteringTextInputFormatter.digitsOnly;

  static final letrasMayusculas = [FilteringTextInputFormatter.allow(RegExp('[A-Za-zÑñ ]')), MayusculasFormatter()];

  static final alfanumerico = [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9Ññ -]')), MayusculasFormatter()];

  /// Solo letras (con tildes), en mayusculas: nombres, apellidos y color.
  static final letras = [FilteringTextInputFormatter.allow(RegExp('[A-Za-zÁÉÍÓÚÜÑáéíóúüñ ]')), MayusculasFormatter()];
}
