import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart' show IconData, Icons;

/// Iconos de la app, una sola familia: estilo iOS de linea (CupertinoIcons), la misma de la barra
/// inferior, de Perfil y del panel. Los nombres siguen a los de Font Awesome que se usaban antes,
/// asi cada pantalla solo cambio FontAwesomeIcons por Iconos. Excepciones (iOS no los trae): la
/// moto, el billete del pago en efectivo y la huella, de Material redondeado. Los logos de Google y
/// WhatsApp siguen con Font Awesome (son marcas).
class Iconos {
  Iconos._();

  // Motos y vehiculos.
  static const IconData motorcycle = Icons.two_wheeler_rounded;
  static const IconData carSide = Icons.two_wheeler_rounded;
  static const IconData bus = CupertinoIcons.bus;

  // Dinero y pago.
  static const IconData moneyBill = Icons.payments_outlined;
  static const IconData moneyBillWave = Icons.payments_outlined;
  static const IconData moneyBill1 = Icons.payments_outlined;
  static const IconData wallet = CupertinoIcons.creditcard;
  static const IconData creditCard = CupertinoIcons.creditcard;
  static const IconData solidCreditCard = CupertinoIcons.creditcard_fill;
  static const IconData qrcode = CupertinoIcons.qrcode;

  // Mapa, lugares y ruta.
  static const IconData locationDot = CupertinoIcons.location_solid;
  static const IconData locationCrosshairs = CupertinoIcons.location_fill;
  static const IconData route = CupertinoIcons.map;
  static const IconData road = CupertinoIcons.map;
  static const IconData earthAmericas = CupertinoIcons.globe;
  static const IconData globe = CupertinoIcons.globe;
  static const IconData layerGroup = CupertinoIcons.square_stack_3d_up;
  static const IconData flag = CupertinoIcons.flag;
  static const IconData flagCheckered = CupertinoIcons.flag_fill;
  static const IconData house = CupertinoIcons.house;
  static const IconData hospital = CupertinoIcons.bandage;
  static const IconData briefcase = CupertinoIcons.briefcase;
  static const IconData graduationCap = CupertinoIcons.book;
  static const IconData basketShopping = CupertinoIcons.cart;
  static const IconData bagShopping = CupertinoIcons.bag;
  static const IconData personWalking = CupertinoIcons.person;
  static const IconData handPointer = CupertinoIcons.hand_point_right;

  // Paquetes.
  static const IconData box = CupertinoIcons.cube_box;
  static const IconData boxOpen = CupertinoIcons.cube_box;

  // Personas y documentos.
  static const IconData user = CupertinoIcons.person;
  static const IconData solidUser = CupertinoIcons.person_fill;
  static const IconData userGroup = CupertinoIcons.person_2;
  static const IconData userCheck = CupertinoIcons.person_crop_circle_badge_checkmark;
  static const IconData userXmark = CupertinoIcons.person_crop_circle_badge_xmark;
  static const IconData userShield = CupertinoIcons.checkmark_shield;
  static const IconData idCard = CupertinoIcons.person_crop_rectangle;
  static const IconData idBadge = CupertinoIcons.person_crop_rectangle;
  static const IconData solidIdBadge = CupertinoIcons.person_crop_rectangle_fill;
  static const IconData filePdf = CupertinoIcons.doc_text;
  static const IconData fileArrowUp = CupertinoIcons.arrow_up_doc;
  static const IconData fileCircleExclamation = CupertinoIcons.exclamationmark_square;
  static const IconData image = CupertinoIcons.photo;
  static const IconData camera = CupertinoIcons.camera;
  static const IconData cakeCandles = CupertinoIcons.gift;
  static const IconData calendar = CupertinoIcons.calendar;
  static const IconData hashtag = CupertinoIcons.number;
  static const IconData at = CupertinoIcons.at;
  static const IconData envelope = CupertinoIcons.envelope;
  static const IconData envelopeOpenText = CupertinoIcons.envelope_open;
  static const IconData mobileScreenButton = CupertinoIcons.device_phone_portrait;

  // Comunicacion y ayuda.
  static const IconData phone = CupertinoIcons.phone;
  static const IconData message = CupertinoIcons.chat_bubble;
  static const IconData commentDots = CupertinoIcons.chat_bubble_text;
  static const IconData paperPlane = CupertinoIcons.paperplane;
  static const IconData shareNodes = CupertinoIcons.share;
  static const IconData headset = CupertinoIcons.question_circle;
  static const IconData bell = CupertinoIcons.bell;
  static const IconData volumeHigh = CupertinoIcons.speaker_2;
  static const IconData volumeXmark = CupertinoIcons.speaker_slash;
  static const IconData wifi = CupertinoIcons.wifi;

  // Seguridad y cuenta.
  static const IconData lock = CupertinoIcons.lock;
  static const IconData key = CupertinoIcons.lock_rotation;
  static const IconData shieldHalved = CupertinoIcons.shield_lefthalf_fill;
  static const IconData fingerprint = Icons.fingerprint_rounded;
  static const IconData eye = CupertinoIcons.eye;
  static const IconData eyeSlash = CupertinoIcons.eye_slash;
  static const IconData powerOff = CupertinoIcons.power;
  static const IconData rightFromBracket = CupertinoIcons.square_arrow_right;

  // Estados y avisos.
  static const IconData check = CupertinoIcons.checkmark;
  static const IconData circleCheck = CupertinoIcons.checkmark_circle;
  static const IconData solidCircleCheck = CupertinoIcons.checkmark_circle_fill;
  static const IconData circleXmark = CupertinoIcons.xmark_circle;
  static const IconData circleExclamation = CupertinoIcons.exclamationmark_circle;
  static const IconData circleInfo = CupertinoIcons.info_circle;
  static const IconData triangleExclamation = CupertinoIcons.exclamationmark_triangle;
  static const IconData clock = CupertinoIcons.clock;
  static const IconData clockRotateLeft = CupertinoIcons.clock;
  static const IconData hourglassHalf = CupertinoIcons.hourglass;
  static const IconData star = CupertinoIcons.star;
  static const IconData solidStar = CupertinoIcons.star_fill;
  static const IconData starHalfStroke = CupertinoIcons.star_lefthalf_fill;
  static const IconData solidSquare = CupertinoIcons.square_fill;
  static const IconData circulo = CupertinoIcons.circle_fill;

  // Acciones y navegacion.
  static const IconData xmark = CupertinoIcons.xmark;
  static const IconData plus = CupertinoIcons.plus;
  static const IconData pen = CupertinoIcons.pencil;
  static const IconData trashCan = CupertinoIcons.trash;
  static const IconData copy = CupertinoIcons.doc_on_doc;
  static const IconData download = CupertinoIcons.square_arrow_down;
  static const IconData magnifyingGlass = CupertinoIcons.search;
  static const IconData magnifyingGlassPlus = CupertinoIcons.zoom_in;
  static const IconData rotateLeft = CupertinoIcons.rotate_left;
  static const IconData rotateRight = CupertinoIcons.rotate_right;
  static const IconData arrowsRotate = CupertinoIcons.arrow_2_circlepath;
  static const IconData play = CupertinoIcons.play_fill;
  static const IconData listUl = CupertinoIcons.list_bullet;
  static const IconData arrowLeft = CupertinoIcons.arrow_left;
  static const IconData arrowRight = CupertinoIcons.arrow_right;
  static const IconData chevronLeft = CupertinoIcons.chevron_left;
  static const IconData chevronRight = CupertinoIcons.chevron_right;
  static const IconData chevronUp = CupertinoIcons.chevron_up;
  static const IconData chevronDown = CupertinoIcons.chevron_down;
}
