import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tijuana_sin_barreras/core/models/route_result.dart';
import 'package:tijuana_sin_barreras/core/services/geo_utils.dart';

void main() {
  group('GeoUtils', () {
    test('haversine entre punto y sí mismo es 0', () {
      const p = LatLng(32.5149, -117.0382);
      expect(GeoUtils.haversineMeters(p, p), closeTo(0, 0.01));
    });

    test('haversine ~111 km por grado de latitud', () {
      const a = LatLng(32.0, -117.0);
      const b = LatLng(33.0, -117.0);
      // ~111.2 km por grado de latitud.
      expect(GeoUtils.haversineMeters(a, b), closeTo(111195, 500));
    });

    test('punto sobre el segmento da distancia ~0', () {
      const a = LatLng(32.50, -117.00);
      const b = LatLng(32.52, -117.00);
      const mid = LatLng(32.51, -117.00);
      expect(GeoUtils.pointToSegmentMeters(mid, a, b), closeTo(0, 2));
    });

    test('punto alejado de la polilínea da distancia grande', () {
      final poly = [
        const LatLng(32.50, -117.00),
        const LatLng(32.52, -117.00),
      ];
      // ~0.01° de longitud ≈ 940 m a esta latitud.
      const off = LatLng(32.51, -117.01);
      final d = GeoUtils.pointToPolylineMeters(off, poly);
      expect(d, greaterThan(700));
      expect(d, lessThan(1100));
    });

    test('perpendicularOffset desplaza la distancia pedida', () {
      const origin = LatLng(32.51, -117.00);
      const from = LatLng(32.50, -117.00); // tramo norte-sur
      const to = LatLng(32.52, -117.00);
      final left = GeoUtils.perpendicularOffset(origin, from, to, 100, 1);
      final d = GeoUtils.haversineMeters(origin, left);
      expect(d, closeTo(100, 5));
      // Tramo vertical → desplazamiento perpendicular cambia la longitud.
      expect(left.latitude, closeTo(origin.latitude, 1e-6));
      expect(left.longitude, isNot(closeTo(origin.longitude, 1e-6)));
    });
  });

  group('RouteOption.weightForType', () {
    test('barreras bloqueantes pesan más que las informativas', () {
      expect(RouteOption.weightForType('Escalón sin rampa'),
          greaterThan(RouteOption.weightForType('Semáforo sin sonido')));
      expect(RouteOption.weightForType('Rampa faltante'), 3.0);
      expect(RouteOption.weightForType('Tipo desconocido'), 2.0);
    });
  });
}
