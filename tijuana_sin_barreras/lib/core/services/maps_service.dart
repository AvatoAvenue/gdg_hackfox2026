import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../constants/api_keys.dart';
import '../models/barrier_report.dart';
import '../models/place_models.dart';
import '../models/route_result.dart';
import 'geo_utils.dart';

class MapsService {
  String get _mapsKey => ApiKeys.googleMapsKey;
  static const _uuid = Uuid();

  // Centro de Tijuana — sesga búsquedas y rutas a la zona.
  static const _tijuanaLat = 32.5149;
  static const _tijuanaLng = -117.0382;

  /// Token de sesión para agrupar autocomplete + details (facturación Google).
  /// Genera uno al empezar a escribir y deséchalo tras elegir un lugar.
  String newSessionToken() => _uuid.v4();

  // ---------------------------------------------------------------------------
  // AUTOCOMPLETE — Places API (New). Soporta CORS → funciona en web y Android.
  // ---------------------------------------------------------------------------

  /// Devuelve predicciones cercanas a Tijuana para el texto del usuario.
  Future<List<PlaceSuggestion>> autocompletePlaces(
    String input, {
    String? sessionToken,
  }) async {
    if (input.trim().isEmpty) return [];

    final uri = Uri.parse('https://places.googleapis.com/v1/places:autocomplete');
    final body = jsonEncode({
      'input': input,
      'languageCode': 'es',
      'regionCode': 'mx',
      'locationBias': {
        'circle': {
          'center': {'latitude': _tijuanaLat, 'longitude': _tijuanaLng},
          'radius': 30000.0, // 30 km — área metropolitana de Tijuana
        },
      },
      if (sessionToken != null) 'sessionToken': sessionToken,
    });

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _mapsKey,
      },
      body: body,
    );

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final suggestions = data['suggestions'] as List?;
    if (suggestions == null) return [];

    return suggestions
        .map((s) => PlaceSuggestion.fromJson(s as Map<String, dynamic>))
        .where((s) => s.isValid)
        .toList();
  }

  /// Resuelve un placeId a coordenadas (Place Details New).
  /// Usa el mismo sessionToken del autocomplete para cerrar la sesión.
  Future<PlaceResult?> getPlaceDetails(
    String placeId, {
    String? sessionToken,
  }) async {
    final uri = Uri.parse(
      'https://places.googleapis.com/v1/places/$placeId'
      '?languageCode=es&regionCode=mx'
      '${sessionToken != null ? '&sessionToken=$sessionToken' : ''}',
    );

    final response = await http.get(
      uri,
      headers: {
        'X-Goog-Api-Key': _mapsKey,
        'X-Goog-FieldMask': 'id,location,displayName,formattedAddress',
      },
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return PlaceResult.fromJson(placeId, data);
  }

  /// Búsqueda de texto (Text Search New) — fallback si el usuario escribe
  /// y presiona "calcular" sin elegir una sugerencia de la lista.
  Future<PlaceResult?> searchText(String query) async {
    if (query.trim().isEmpty) return null;

    final uri = Uri.parse('https://places.googleapis.com/v1/places:searchText');
    final body = jsonEncode({
      'textQuery': query,
      'languageCode': 'es',
      'regionCode': 'mx',
      'maxResultCount': 1,
      'locationBias': {
        'circle': {
          'center': {'latitude': _tijuanaLat, 'longitude': _tijuanaLng},
          'radius': 30000.0,
        },
      },
    });

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _mapsKey,
        'X-Goog-FieldMask':
            'places.id,places.location,places.displayName,places.formattedAddress',
      },
      body: body,
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final places = data['places'] as List?;
    if (places == null || places.isEmpty) return null;

    final place = places.first as Map<String, dynamic>;
    final id = (place['id'] as String?) ?? '';
    return PlaceResult.fromJson(id, place);
  }

  // ---------------------------------------------------------------------------
  // ROUTES — Routes API v2 (compute routes, modo peatonal).
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getAccessibleRoute({
    required LatLng origin,
    required LatLng destination,
  }) {
    return _computeRoutes(origin: origin, destination: destination);
  }

  /// Llamada cruda a Routes API (modo peatonal). Soporta rutas alternativas y
  /// un waypoint intermedio opcional (para forzar desvíos alrededor de
  /// obstáculos). Devuelve el JSON completo o null si falla.
  Future<Map<String, dynamic>?> _computeRoutes({
    required LatLng origin,
    required LatLng destination,
    bool alternatives = false,
    LatLng? intermediate,
  }) async {
    final uri = Uri.parse(
        'https://routes.googleapis.com/directions/v2:computeRoutes');

    Map<String, dynamic> wpoint(LatLng p) => {
          'location': {
            'latLng': {'latitude': p.latitude, 'longitude': p.longitude}
          }
        };

    final body = jsonEncode({
      'origin': wpoint(origin),
      'destination': wpoint(destination),
      if (intermediate != null) 'intermediates': [wpoint(intermediate)],
      'travelMode': 'WALK',
      // Las rutas alternativas no se permiten junto con waypoints intermedios.
      'computeAlternativeRoutes': intermediate == null && alternatives,
      'languageCode': 'es-MX',
    });

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _mapsKey,
        'X-Goog-FieldMask':
            'routes.duration,routes.distanceMeters,routes.polyline,routes.legs',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // RUTEO QUE EVITA OBSTÁCULOS
  // ---------------------------------------------------------------------------

  /// Calcula la mejor ruta peatonal entre [origin] y [destination] evitando, en
  /// lo posible, las [barriers] activas.
  ///
  /// Estrategia:
  /// 1. Pide a Routes API varias alternativas (`computeAlternativeRoutes`).
  /// 2. Puntúa cada alternativa según cuántos obstáculos atraviesa (dentro de
  ///    [avoidRadiusMeters]) y la severidad de cada uno.
  /// 3. Elige la de menor penalización (desempate por distancia).
  /// 4. Si la mejor aún toca obstáculos, intenta un desvío añadiendo un
  ///    waypoint perpendicular que rodee el peor obstáculo, y lo adopta solo si
  ///    mejora de verdad sin alargar la ruta de forma absurda.
  Future<RouteResult?> getRoutesAvoidingBarriers({
    required LatLng origin,
    required LatLng destination,
    required List<BarrierReport> barriers,
    double avoidRadiusMeters = 30,
    bool tryDetour = true,
  }) async {
    final data = await _computeRoutes(
      origin: origin,
      destination: destination,
      alternatives: true,
    );

    final routes = data?['routes'] as List?;
    if (routes == null || routes.isEmpty) return null;

    final options = routes
        .map((r) => _optionFromJson(
              r as Map<String, dynamic>,
              barriers,
              avoidRadiusMeters,
            ))
        .whereType<RouteOption>()
        .toList();

    if (options.isEmpty) return null;

    // La primera ruta es la principal/recomendada por Google.
    final defaultOption = options.first;

    // Mejor = menor penalización; desempate por menor distancia.
    final sorted = [...options]..sort((a, b) {
        final p = a.obstaclePenalty.compareTo(b.obstaclePenalty);
        return p != 0 ? p : a.distanceMeters.compareTo(b.distanceMeters);
      });
    var best = sorted.first;

    // Desvío con waypoint si la mejor alternativa todavía cruza obstáculos.
    if (tryDetour && best.obstaclesOnRoute.isNotEmpty) {
      final detour = await _tryDetourAround(
        origin: origin,
        destination: destination,
        barriers: barriers,
        avoidRadiusMeters: avoidRadiusMeters,
        target: best,
      );
      if (detour != null &&
          detour.obstaclePenalty < best.obstaclePenalty &&
          detour.distanceMeters <= best.distanceMeters * 2.5) {
        best = detour;
      }
    }

    // Barreras a dibujar: las que están cerca (radio ampliado) de cualquier ruta.
    final displayRadius = avoidRadiusMeters * 3;
    final allPolys = [
      best.points,
      for (final o in options) o.points,
    ];
    final nearby = barriers.where((b) {
      final p = LatLng(b.lat, b.lng);
      return allPolys
          .any((poly) => GeoUtils.pointToPolylineMeters(p, poly) <= displayRadius);
    }).toList();

    return RouteResult(
      best: best,
      defaultOption: defaultOption,
      all: options,
      nearbyBarriers: nearby,
    );
  }

  /// Intenta rodear el obstáculo más grave de [target] generando waypoints
  /// perpendiculares a ambos lados. Devuelve la mejor ruta con desvío o null.
  Future<RouteOption?> _tryDetourAround({
    required LatLng origin,
    required LatLng destination,
    required List<BarrierReport> barriers,
    required double avoidRadiusMeters,
    required RouteOption target,
  }) async {
    // Obstáculo de mayor peso sobre la ruta.
    final worst = [...target.obstaclesOnRoute]..sort((a, b) =>
        RouteOption.weightForType(b.type)
            .compareTo(RouteOption.weightForType(a.type)));
    final obstacle = LatLng(worst.first.lat, worst.first.lng);

    // Tramo de la polilínea más cercano al obstáculo, para orientar la normal.
    final poly = target.points;
    var segIdx = 0;
    var bestD = double.infinity;
    for (var i = 0; i < poly.length - 1; i++) {
      final d = GeoUtils.pointToSegmentMeters(obstacle, poly[i], poly[i + 1]);
      if (d < bestD) {
        bestD = d;
        segIdx = i;
      }
    }
    final from = poly[segIdx];
    final to = poly[segIdx + 1];

    // Probar desvío a ambos lados; quedarse con el mejor que de verdad mejore.
    final offset = avoidRadiusMeters * 4;
    RouteOption? bestDetour;
    for (final side in [1, -1]) {
      final waypoint =
          GeoUtils.perpendicularOffset(obstacle, from, to, offset, side);
      final data = await _computeRoutes(
        origin: origin,
        destination: destination,
        intermediate: waypoint,
      );
      final routes = data?['routes'] as List?;
      if (routes == null || routes.isEmpty) continue;
      final opt = _optionFromJson(
        routes.first as Map<String, dynamic>,
        barriers,
        avoidRadiusMeters,
        isDetour: true,
      );
      if (opt == null) continue;
      if (bestDetour == null ||
          opt.obstaclePenalty < bestDetour.obstaclePenalty) {
        bestDetour = opt;
      }
    }
    return bestDetour;
  }

  /// Convierte una ruta del JSON de Routes API en [RouteOption], decodificando
  /// la polilínea y midiendo qué obstáculos atraviesa.
  RouteOption? _optionFromJson(
    Map<String, dynamic> route,
    List<BarrierReport> barriers,
    double avoidRadiusMeters, {
    bool isDetour = false,
  }) {
    final encoded = route['polyline']?['encodedPolyline'] as String?;
    if (encoded == null) return null;
    final points = decodePolyline(encoded);
    if (points.isEmpty) return null;

    final distanceM = (route['distanceMeters'] as num?)?.toInt() ?? 0;
    final durationS =
        int.tryParse(((route['duration'] as String?) ?? '0s').replaceAll('s', '')) ??
            0;

    final onRoute = <BarrierReport>[];
    double penalty = 0;
    for (final b in barriers) {
      final d = GeoUtils.pointToPolylineMeters(LatLng(b.lat, b.lng), points);
      if (d <= avoidRadiusMeters) {
        onRoute.add(b);
        penalty += RouteOption.weightForType(b.type);
      }
    }

    return RouteOption(
      points: points,
      distanceMeters: distanceM,
      durationSeconds: durationS,
      obstaclesOnRoute: onRoute,
      obstaclePenalty: penalty,
      isDetour: isDetour,
    );
  }

  /// Decodifica un polyline codificado de Google a una lista de puntos.
  ///
  /// IMPORTANTE: usa aritmética (multiplicación/división) en lugar de
  /// operadores de bits (`<<`, `>>`, `&`, `~`). En Flutter Web los `int` son
  /// números de JavaScript y los operadores de bits truncan a 32 bits: cuando
  /// `shift` llega a 30, `(b & 0x1f) << shift` desborda y corrompe las
  /// coordenadas (la ruta se dibuja como una línea horizontal). La aritmética
  /// es segura hasta 2^53, así que funciona igual en web y en móvil.
  List<LatLng> decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0, lng = 0;

    while (index < encoded.length) {
      int shift = 0, result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result += (b & 0x1f) * (1 << shift);
        shift += 5;
      } while (b >= 0x20);
      lat += result.isOdd ? -(result ~/ 2) - 1 : result ~/ 2;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result += (b & 0x1f) * (1 << shift);
        shift += 5;
      } while (b >= 0x20);
      lng += result.isOdd ? -(result ~/ 2) - 1 : result ~/ 2;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
