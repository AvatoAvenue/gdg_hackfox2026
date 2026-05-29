import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Predicción de autocompletado (Places API New — `places:autocomplete`).
class PlaceSuggestion {
  final String placeId;
  final String mainText; // p. ej. "Hospital General de Tijuana"
  final String secondaryText; // p. ej. "Av. Centenario, Zona Río..."
  final String fullText;

  const PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final prediction = json['placePrediction'] as Map<String, dynamic>?;
    if (prediction == null) {
      return const PlaceSuggestion(
        placeId: '',
        mainText: '',
        secondaryText: '',
        fullText: '',
      );
    }
    final structured =
        prediction['structuredFormat'] as Map<String, dynamic>?;
    final main = structured?['mainText'] as Map<String, dynamic>?;
    final secondary = structured?['secondaryText'] as Map<String, dynamic>?;
    final text = prediction['text'] as Map<String, dynamic>?;
    final fullText = (text?['text'] as String?) ?? '';

    return PlaceSuggestion(
      placeId: (prediction['placeId'] as String?) ?? '',
      mainText: (main?['text'] as String?) ?? fullText,
      secondaryText: (secondary?['text'] as String?) ?? '',
      fullText: fullText,
    );
  }

  bool get isValid => placeId.isNotEmpty;
}

/// Lugar resuelto con coordenadas (Places API New — `places/{id}` details).
/// Es lo que se usa para alimentar a Routes API (compute routes).
class PlaceResult {
  final String placeId;
  final String name;
  final String address;
  final LatLng latLng;

  const PlaceResult({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latLng,
  });

  factory PlaceResult.fromJson(String placeId, Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>?;
    final displayName = json['displayName'] as Map<String, dynamic>?;
    return PlaceResult(
      placeId: placeId,
      name: (displayName?['text'] as String?) ??
          (json['formattedAddress'] as String?) ??
          'Lugar',
      address: (json['formattedAddress'] as String?) ?? '',
      latLng: LatLng(
        (location?['latitude'] as num?)?.toDouble() ?? 0,
        (location?['longitude'] as num?)?.toDouble() ?? 0,
      ),
    );
  }
}
