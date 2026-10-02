import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart' show IconData, Icons;

/// Iconos del panel, estilo iOS (CupertinoIcons, como la app de pasajeros y conductores), definidos
/// en un solo lugar. Los nombres siguen a los de Font Awesome que se usaban antes, asi cada pantalla
/// solo cambio FontAwesomeIcons por Iconos. Las motos (iOS no trae) usan el icono de moto de Material.
class Iconos {
  Iconos._();

  // Motos: conductores, flota y taxis.
  static const IconData motorcycle = Icons.two_wheeler_rounded;
  static const IconData carSide = Icons.two_wheeler_rounded;
  static const IconData taxi = Icons.two_wheeler_rounded;

  static const IconData arrowDownWideShort = CupertinoIcons.arrow_down;
  static const IconData arrowsRotate = CupertinoIcons.arrow_2_circlepath;
  static const IconData arrowUp = CupertinoIcons.arrow_up;
  static const IconData bars = CupertinoIcons.bars;
  static const IconData calendar = CupertinoIcons.calendar;
  static const IconData camera = CupertinoIcons.camera;
  static const IconData check = CupertinoIcons.checkmark;
  static const IconData chevronLeft = CupertinoIcons.chevron_left;
  static const IconData chevronRight = CupertinoIcons.chevron_right;
  static const IconData circle = CupertinoIcons.circle_fill;
  static const IconData circleCheck = CupertinoIcons.checkmark_circle;
  static const IconData circleExclamation = CupertinoIcons.exclamationmark_circle;
  static const IconData circleInfo = CupertinoIcons.info_circle;
  static const IconData clipboardCheck = CupertinoIcons.checkmark_seal;
  static const IconData clock = CupertinoIcons.clock;
  static const IconData commentSlash = CupertinoIcons.minus_circle;
  static const IconData crosshairs = CupertinoIcons.scope;
  static const IconData download = CupertinoIcons.square_arrow_down;
  static const IconData drawPolygon = Icons.polyline_rounded;
  static const IconData eraser = CupertinoIcons.delete_left;
  static const IconData eye = CupertinoIcons.eye;
  static const IconData eyeSlash = CupertinoIcons.eye_slash;
  static const IconData fileArrowUp = CupertinoIcons.arrow_up_doc;
  static const IconData fileCsv = CupertinoIcons.doc_plaintext;
  static const IconData fileExcel = CupertinoIcons.table;
  static const IconData filePdf = CupertinoIcons.doc_text_fill;
  static const IconData filter = CupertinoIcons.line_horizontal_3_decrease;
  static const IconData filterCircleXmark = CupertinoIcons.xmark_circle;
  static const IconData floppyDisk = CupertinoIcons.floppy_disk;
  static const IconData folderOpen = CupertinoIcons.folder;
  static const IconData folderPlus = CupertinoIcons.folder_badge_plus;
  static const IconData folderTree = CupertinoIcons.folder_fill;
  static const IconData gaugeHigh = CupertinoIcons.speedometer;
  static const IconData gear = CupertinoIcons.gear_alt_fill;
  static const IconData house = CupertinoIcons.house_fill;
  static const IconData idBadge = CupertinoIcons.person_crop_rectangle;
  static const IconData idCard = CupertinoIcons.person_crop_rectangle;
  static const IconData idCardClip = CupertinoIcons.doc_person;
  static const IconData layerGroup = CupertinoIcons.square_stack_3d_up;
  static const IconData locationDot = CupertinoIcons.location_solid;
  static const IconData lock = CupertinoIcons.lock;
  static const IconData magnifyingGlass = CupertinoIcons.search;
  static const IconData map = CupertinoIcons.map;
  static const IconData mapLocationDot = CupertinoIcons.map_pin_ellipse;
  static const IconData penToSquare = CupertinoIcons.square_pencil;
  static const IconData plugCircleXmark = CupertinoIcons.wifi_slash;
  static const IconData plus = CupertinoIcons.plus;
  static const IconData powerOff = CupertinoIcons.power;
  static const IconData qrcode = CupertinoIcons.qrcode;
  static const IconData rightToBracket = CupertinoIcons.square_arrow_right;
  static const IconData rotateLeft = CupertinoIcons.rotate_left;
  static const IconData rotateRight = CupertinoIcons.rotate_right;
  static const IconData route = Icons.route_rounded;
  static const IconData solidComments = CupertinoIcons.chat_bubble_2_fill;
  static const IconData solidFolder = CupertinoIcons.folder_fill;
  static const IconData solidIdBadge = CupertinoIcons.person_crop_rectangle_fill;
  static const IconData solidStar = CupertinoIcons.star_fill;
  static const IconData sort = CupertinoIcons.arrow_up_arrow_down;
  static const IconData sortDown = CupertinoIcons.sort_down;
  static const IconData sortUp = CupertinoIcons.sort_up;
  static const IconData star = CupertinoIcons.star;
  static const IconData starHalfStroke = CupertinoIcons.star_lefthalf_fill;
  static const IconData trashCan = CupertinoIcons.trash;
  static const IconData triangleExclamation = CupertinoIcons.exclamationmark_triangle;
  static const IconData unlock = CupertinoIcons.lock_open;
  static const IconData unlockKeyhole = CupertinoIcons.lock_open;
  static const IconData upRightFromSquare = CupertinoIcons.arrow_up_right_square;
  static const IconData user = CupertinoIcons.person;
  static const IconData userCheck = CupertinoIcons.person_crop_circle_badge_checkmark;
  static const IconData userGear = CupertinoIcons.person_crop_circle_fill;
  static const IconData userPen = CupertinoIcons.square_pencil;
  static const IconData userPlus = CupertinoIcons.person_add;
  static const IconData users = CupertinoIcons.person_2;
  static const IconData userShield = CupertinoIcons.person_crop_circle;
  static const IconData userSlash = CupertinoIcons.person_crop_circle_badge_minus;
  static const IconData userXmark = CupertinoIcons.person_crop_circle_badge_xmark;
  static const IconData xmark = CupertinoIcons.xmark;

  // Nuevos (2026-10-02).
  static const IconData envelope = CupertinoIcons.envelope_badge;
  static const IconData eliminarPermanente = CupertinoIcons.trash_slash;
}
