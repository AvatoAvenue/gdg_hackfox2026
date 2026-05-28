import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF1A73E8);    // Google Blue — WCAG AA sobre blanco
  static const secondary = Color(0xFF34A853);  // Google Green — accesible
  static const warning = Color(0xFFF9AB00);    // Amarillo barreras
  static const danger = Color(0xFFEA4335);     // Rojo urgente
  static const surface = Color(0xFFF8F9FA);
  static const onSurface = Color(0xFF202124);
  static const muted = Color(0xFF5F6368);

  // Colores de marcadores por tipo de barrera
  static const barrierRamp = Color(0xFFF9AB00);
  static const barrierSidewalk = Color(0xFFEA4335);
  static const barrierSignal = Color(0xFF9334E6);
  static const barrierOther = Color(0xFF5F6368);
  static const barrierResolved = Color(0xFF34A853);
}
