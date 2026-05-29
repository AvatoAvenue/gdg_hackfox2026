import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'barrier_report.dart';

/// Una alternativa de ruta devuelta por Routes API, ya decodificada y puntuada
/// según cuántos obstáculos activos atraviesa.
class RouteOption {
  final List<LatLng> points;
  final int distanceMeters;
  final int durationSeconds;

  /// Barreras activas que caen dentro del radio de evasión de esta ruta.
  final List<BarrierReport> obstaclesOnRoute;

  /// Penalización acumulada: suma de pesos de severidad de los obstáculos.
  /// Cuanto mayor, peor (más/peores barreras sobre la ruta).
  final double obstaclePenalty;

  /// True si esta opción se construyó con un waypoint de desvío propio (no es
  /// una alternativa nativa de Google).
  final bool isDetour;

  const RouteOption({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.obstaclesOnRoute,
    required this.obstaclePenalty,
    this.isDetour = false,
  });

  int get durationMinutes => durationSeconds ~/ 60;
  double get distanceKm => distanceMeters / 1000.0;

  /// Peso de severidad por tipo de barrera. Las que bloquean físicamente el
  /// paso de una silla de ruedas pesan más que las informativas.
  static double weightForType(String type) {
    switch (type) {
      case 'Escalón sin rampa':
      case 'Sin rebaje de banqueta':
      case 'Rampa faltante':
      case 'Obstáculo en paso peatonal':
        return 3.0;
      case 'Banqueta dañada':
      case 'Estacionamiento en banqueta':
        return 2.0;
      case 'Semáforo sin sonido':
        return 1.0;
      default:
        return 2.0;
    }
  }
}

/// Resultado completo del cálculo de ruta evitando obstáculos.
class RouteResult {
  /// Ruta elegida (la de menor penalización por obstáculos).
  final RouteOption best;

  /// Ruta que Google propone por defecto (la primera/principal). Sirve de
  /// referencia para reportar cuántos obstáculos se evitaron al elegir [best].
  final RouteOption defaultOption;

  /// Todas las alternativas evaluadas.
  final List<RouteOption> all;

  /// Barreras activas cercanas a cualquier ruta (para dibujarlas en el mapa).
  final List<BarrierReport> nearbyBarriers;

  const RouteResult({
    required this.best,
    required this.defaultOption,
    required this.all,
    required this.nearbyBarriers,
  });

  /// Barreras que la ruta por defecto atravesaba pero la ruta elegida esquiva.
  List<BarrierReport> get avoidedBarriers {
    final bestIds = best.obstaclesOnRoute.map((b) => b.id).toSet();
    return defaultOption.obstaclesOnRoute
        .where((b) => !bestIds.contains(b.id))
        .toList();
  }

  /// Obstáculos que la ruta elegida no pudo evitar.
  List<BarrierReport> get remainingBarriers => best.obstaclesOnRoute;

  /// True si se eligió una ruta distinta a la propuesta por defecto.
  bool get didReroute =>
      best.isDetour || !identical(best, defaultOption);
}
