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
      title: 'Tijuana Sin Barreras',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        textTheme: AppTextStyles.textTheme,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
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
