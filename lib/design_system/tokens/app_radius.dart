import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  // Micro (inputs, chips, small elements)
  static const double xs   = 8.0;
  // Buttons / Interactive elements
  static const double sm   = 12.0;
  // Cards / Standard containers
  static const double md   = 16.0;
  // Large containers / Dialogs
  static const double lg   = 20.0;
  // Sheets / Bottom Nav / Hero sections
  static const double xl   = 28.0;
  // Fully rounded (avatars, pill buttons)
  static const double full = 999.0;

  static const BorderRadius xsBorder   = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smBorder   = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdBorder   = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgBorder   = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlBorder   = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius fullBorder = BorderRadius.all(Radius.circular(full));
}
