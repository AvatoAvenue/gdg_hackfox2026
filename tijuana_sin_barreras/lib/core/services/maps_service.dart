import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../constants/api_keys.dart';
import '../models/place_models.dart';

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
  }) async {
    final uri = Uri.parse(
        'https://routes.googleapis.com/directions/v2:computeRoutes');

    final body = jsonEncode({
      'origin': {
        'location': {
          'latLng': {
            'latitude': origin.latitude,
            'longitude': origin.longitude
          }
        }
      },
      'destination': {
        'location': {
          'latLng': {
            'latitude': destination.latitude,
            'longitude': destination.longitude
          }
        }
      },
      'travelMode': 'WALK',
      'computeAlternativeRoutes': false,
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

  List<LatLng> decodePolyline(String encoded) {
    final result = <LatLng>[];
    int index = 0;
    int lat = 0, lng = 0;

    while (index < encoded.length) {
      int shift = 0, result0 = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result0 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result0 & 1) != 0 ? ~(result0 >> 1) : result0 >> 1;

      shift = 0;
      result0 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result0 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result0 & 1) != 0 ? ~(result0 >> 1) : result0 >> 1;

      result.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return result;
  }
}
