import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tijuana_sin_barreras/core/constants/app_colors.dart';

void main() {
  testWidgets('AppColors define colores accesibles', (WidgetTester tester) async {
    expect(AppColors.primary, const Color(0xFF1A73E8));
    expect(AppColors.secondary, const Color(0xFF34A853));
    expect(AppColors.danger, const Color(0xFFEA4335));
  });
}
