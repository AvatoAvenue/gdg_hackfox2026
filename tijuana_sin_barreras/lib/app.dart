import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_text_styles.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/profile_screen.dart';
import 'features/home/home_screen.dart';
import 'features/map/map_screen.dart';
import 'features/report/report_barrier_screen.dart';
import 'features/routing/route_screen.dart';

class TijuanaSinBarrerasApp extends StatelessWidget {
  const TijuanaSinBarrerasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Senda',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,

          // --- Primary: brand teal ---
          primary: AppColors.brandActive,
          onPrimary: Colors.white,
          primaryContainer: AppColors.surfacePositive,
          onPrimaryContainer: AppColors.darkDeep,

          // --- Secondary: deep teal (hover/active) ---
          secondary: AppColors.brandHover,
          onSecondary: Colors.white,
          secondaryContainer: AppColors.surfaceNeutral,
          onSecondaryContainer: AppColors.darkDeep,

          // --- Tertiary: passive teal (decorative) ---
          tertiary: AppColors.brandPassive,
          onTertiary: AppColors.darkDeep,
          tertiaryContainer: AppColors.surfaceNeutral,
          onTertiaryContainer: AppColors.darkDeep,

          // --- Error ---
          error: AppColors.error,
          onError: Colors.white,
          errorContainer: Color(0xFFFFDAD6),
          onErrorContainer: Color(0xFF410002),

          // --- Surfaces ---
          surface: AppColors.surfaceNeutral,
          onSurface: AppColors.darkDeep,
          surfaceContainerHighest: AppColors.surfacePositive,
          onSurfaceVariant: AppColors.darkMid,

          // --- Outline ---
          outline: AppColors.darkMid,
          outlineVariant: AppColors.brandPassive,

          // --- Inverse ---
          inverseSurface: AppColors.darkDeep,
          onInverseSurface: Colors.white,
          inversePrimary: AppColors.brandPassive,

          shadow: Colors.black,
          scrim: Colors.black,
        ),
        textTheme: AppTextStyles.textTheme,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: AppColors.darkDeep,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandActive,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.brandActive,
            side: const BorderSide(color: AppColors.brandActive),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceNeutral,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.brandPassive),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.brandActive, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceNeutral,
          selectedColor: AppColors.brandActive,
          labelStyle: const TextStyle(color: AppColors.darkDeep),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.brandActive,
          foregroundColor: Colors.white,
        ),
        scaffoldBackgroundColor: AppColors.surfaceNeutral,
      ),
      initialRoute: '/',
      routes: {
        '/': (ctx) => const HomeScreen(),
        '/login': (ctx) => const LoginScreen(),
        '/profile': (ctx) => const ProfileScreen(),
        '/map': (ctx) => const MapScreen(),
        '/report': (ctx) => const ReportBarrierScreen(),
        '/route': (ctx) => const RouteScreen(),
      },
    );
  }
}
