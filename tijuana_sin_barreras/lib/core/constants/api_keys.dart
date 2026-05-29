/// Claves de API leídas desde el archivo `.env` (ver `.env.example`).
///
/// Requiere que `dotenv.load()` se haya ejecutado en `main()` antes de
/// acceder a cualquiera de estos getters.
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeys {
  ApiKeys._();

  static String get googleMapsKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
}
