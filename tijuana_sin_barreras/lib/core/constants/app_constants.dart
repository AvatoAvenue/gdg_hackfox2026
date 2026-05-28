class AppConstants {
  // Tijuana centro geográfico
  static const double tijuanaLat = 32.5149;
  static const double tijuanaLng = -117.0382;

  static const List<String> barrierTypes = [
    'Rampa faltante',
    'Banqueta dañada',
    'Semáforo sin sonido',
    'Obstáculo en paso peatonal',
    'Sin rebaje de banqueta',
    'Escalón sin rampa',
    'Estacionamiento en banqueta',
    'Otro',
  ];

  static const Map<String, String> barrierTypeEmoji = {
    'Rampa faltante': '♿',
    'Banqueta dañada': '⚠️',
    'Semáforo sin sonido': '🔊',
    'Obstáculo en paso peatonal': '🚧',
    'Sin rebaje de banqueta': '🪜',
    'Escalón sin rampa': '🪜',
    'Estacionamiento en banqueta': '🚗',
    'Otro': '📍',
  };

  // Lugares de referencia para demos
  static const List<String> demoLocations = [
    'Centro Cívico, Tijuana',
    'Hospital General de Tijuana',
    'IMSS Tijuana',
    'Parque Teniente Guerrero',
    'Zona Río Tijuana',
    'Mercado Hidalgo',
  ];
}
