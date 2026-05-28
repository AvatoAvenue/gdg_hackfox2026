import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const TextTheme textTheme = TextTheme(
    headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.onSurface),
    headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.onSurface),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.onSurface),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.onSurface),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.onSurface),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.muted),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
  );
}
