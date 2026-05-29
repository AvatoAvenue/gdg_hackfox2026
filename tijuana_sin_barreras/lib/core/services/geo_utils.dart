import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Utilidades geométricas para medir distancias entre puntos y rutas.
///
/// Se usan para decidir qué obstáculos (barreras) caen "sobre" una ruta
/// peatonal: si una barrera está a menos de X metros de la polilínea, la ruta
/// la atraviesa y debe penalizarse.
///
/// Para distancias cortas (centenares de metros, dentro de una ciudad) se usa
/// una proyección equirectangular local a metros, lo bastante precisa y mucho
/// más barata que geodésicas exactas.
class GeoUtils {
  static const double earthRadius = 6371000; // metros

  static double _rad(double deg) => deg * math.pi / 180;

  /// Distancia geodésica aproximada (Haversine) entre dos coordenadas, en metros.
  static double haversineMeters(LatLng a, LatLng b) {
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * earthRadius * math.asin(math.min(1.0, math.sqrt(h)));
  }

  /// Distancia mínima, en metros, del punto [p] al segmento [a]–[b].
  static double pointToSegmentMeters(LatLng p, LatLng a, LatLng b) {
    final refLat = _rad(a.latitude);
    double x(LatLng q) => _rad(q.longitude) * math.cos(refLat) * earthRadius;
    double y(LatLng q) => _rad(q.latitude) * earthRadius;

    final px = x(p), py = y(p);
    final ax = x(a), ay = y(a);
    final bx = x(b), by = y(b);

    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    double t = len2 == 0 ? 0 : ((px - ax) * dx + (py - ay) * dy) / len2;
    t = t.clamp(0.0, 1.0);

    final cx = ax + t * dx, cy = ay + t * dy;
    final ex = px - cx, ey = py - cy;
    return math.sqrt(ex * ex + ey * ey);
  }

  /// Distancia mínima, en metros, del punto [p] a una polilínea [poly].
  static double pointToPolylineMeters(LatLng p, List<LatLng> poly) {
    if (poly.isEmpty) return double.infinity;
    if (poly.length == 1) return haversineMeters(p, poly.first);
    double best = double.infinity;
    for (var i = 0; i < poly.length - 1; i++) {
      final d = pointToSegmentMeters(p, poly[i], poly[i + 1]);
      if (d < best) best = d;
    }
    return best;
  }

  /// Punto medio aproximado de una polilínea (por índice, no por longitud).
  static LatLng midpointOf(List<LatLng> poly) {
    if (poly.isEmpty) return const LatLng(0, 0);
    return poly[poly.length ~/ 2];
  }

  /// Devuelve un punto desplazado [meters] metros desde [origin] en el rumbo
  /// perpendicular a la dirección [from]→[to]. [side] = 1 (izquierda) o -1
  /// (derecha). Se usa para generar waypoints de desvío alrededor de un
  /// obstáculo.
  static LatLng perpendicularOffset(
    LatLng origin,
    LatLng from,
    LatLng to,
    double meters,
    int side,
  ) {
    // Dirección del tramo en metros locales.
    final refLat = _rad(origin.latitude);
    final dirX = _rad(to.longitude - from.longitude) *
        math.cos(refLat) *
        earthRadius;
    final dirY = _rad(to.latitude - from.latitude) * earthRadius;
    final len = math.sqrt(dirX * dirX + dirY * dirY);
    if (len == 0) return origin;

    // Perpendicular unitaria (rotación 90°) por el lado indicado.
    final nx = (-dirY / len) * side;
    final ny = (dirX / len) * side;

    // De metros locales de vuelta a grados.
    final dLng =
        (nx * meters) / (earthRadius * math.cos(refLat)) * 180 / math.pi;
    final dLat = (ny * meters) / earthRadius * 180 / math.pi;
    return LatLng(origin.latitude + dLat, origin.longitude + dLng);
  }
}
