import 'package:flutter/material.dart';

class AppColors {
  // --- Structural darks (navbar, sidebar, body text) ---
  static const darkDeep = Color(0xFF1A2B3C);
  static const darkMid = Color(0xFF2A3D4F);

  // --- Brand teal ramp ---
  static const brandActive = Color(0xFF289F91);   // interactive elements
  static const brandHover = Color(0xFF1C7269);    // hover / active state
  static const brandPassive = Color(0xFFA0D3CD);  // decorative / disabled

  // --- Light backgrounds ---
  static const surfacePositive = Color(0xFFE1F5EE); // chips, success states, highlighted rows
  static const surfaceNeutral = Color(0xFFE8F7F5);  // page bg, inputs

  // --- Semantic states (not covered by the 7-color brand ramp) ---
  static const warning = Color(0xFFF5A623);
  static const success = Color(0xFF3BAA6E);
  static const error = Color(0xFFE24B4A);

  // --- Aliases so existing screens compile without changes ---
  static const primary = brandActive;
  static const secondary = success;
  static const danger = error;
  static const surface = surfaceNeutral;
  static const onSurface = darkDeep;
  static const muted = darkMid;

  // --- Barrier map marker colors ---
  static const barrierRamp = warning;
  static const barrierSidewalk = error;
  static const barrierSignal = Color(0xFF9334E6);
  static const barrierOther = darkMid;
  static const barrierResolved = success;
}
