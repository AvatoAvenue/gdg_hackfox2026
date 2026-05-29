import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../constants/api_keys.dart';

/// Resultado de validar una foto contra el tipo de barrera que el usuario
/// seleccionó. Indica si la imagen realmente corresponde a ese obstáculo.
class BarrierPhotoValidation {
  /// `true` si la foto corresponde al tipo de barrera seleccionado.
  final bool matches;

  /// Tipo de barrera que Gemini detectó realmente en la imagen.
  final String detectedType;

  /// Confianza de la detección, de 0 a 100.
  final int confidence;

  /// Mensaje breve para mostrar al usuario explicando la decisión.
  final String message;

  /// Análisis formateado de la barrera ("[riesgo] descripción → acción"),
  /// listo para guardarse en el reporte. Null si no se pudo generar.
  final String? analysis;

  const BarrierPhotoValidation({
    required this.matches,
    required this.detectedType,
    required this.confidence,
    required this.message,
    this.analysis,
  });
}

class GeminiService {
  String get _apiKey => ApiKeys.geminiApiKey;
  static const _model = 'gemini-2.5-flash';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Pide a Gemini que confirme si la imagen corresponde al [expectedType]
  /// seleccionado por el usuario, y de paso analiza la barrera. Devuelve null
  /// si la API falla o no responde.
  Future<BarrierPhotoValidation?> validateBarrierPhoto(
    Uint8List bytes,
    String expectedType,
  ) async {
    final base64Image = base64Encode(bytes);

    final uri = Uri.parse('$_baseUrl/$_model:generateContent?key=$_apiKey');
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text': '''Eres un inspector ESTRICTO de accesibilidad urbana en Tijuana, México.
Un usuario subió una foto y la clasificó como la barrera: "$expectedType".

Tu trabajo es VERIFICAR, no asumir. Sé escéptico.

Paso 1 — ¿La imagen es una foto real de la vía pública (calle, banqueta, cruce, rampa, etc.)?
Si la imagen NO es una foto real de un entorno urbano —por ejemplo: dibujos, ilustraciones, capturas de pantalla, memes, texto, logotipos, personas, mascotas, comida, interiores, objetos sin relación con la calle, o imágenes generadas/ficticias— entonces "es_via_publica" = false, "coincide" = false y "confianza" baja (menor a 30).

Paso 2 — Solo si es_via_publica = true: ¿la imagen muestra REALMENTE la barrera "$expectedType"?
Marca "coincide" = true ÚNICAMENTE si estás seguro de que la imagen contiene exactamente ese tipo de barrera. Si muestra otra barrera, ponla en "tipo_detectado" y "coincide" = false. Ante la duda, "coincide" = false.

Responde ÚNICAMENTE con JSON válido, sin texto adicional ni markdown:
{"es_via_publica": true|false, "coincide": true|false, "tipo_detectado": "qué muestra realmente la imagen", "confianza": 0-100, "mensaje": "explicación breve en 1 oración de por qué coincide o no", "riesgo": "Alto|Medio|Bajo", "accion": "acción municipal recomendada en 1 oración", "descripcion": "descripción breve en 1-2 oraciones"}'''
            },
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 320,
        // gemini-2.5-flash activa "thinking" por defecto, que consume el
        // presupuesto de tokens. Lo desactivamos para asegurar la respuesta.
        'thinkingConfig': {'thinkingBudget': 0},
      }
    });

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;

    final text = candidates[0]['content']['parts'][0]['text'] as String;
    return _parseValidation(text.trim(), expectedType);
  }

  BarrierPhotoValidation? _parseValidation(String raw, String expectedType) {
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}') + 1;
      if (start < 0 || end <= start) return null;

      final parsed =
          jsonDecode(raw.substring(start, end)) as Map<String, dynamic>;

      final confianza = parsed['confianza'];
      final confidence = (confianza is num
              ? confianza.toInt()
              : int.tryParse('$confianza') ?? 0)
          .clamp(0, 100);

      // Gemini puede devolver booleanos como bool o como texto ("true").
      final isPublicScene = _asBool(parsed['es_via_publica'], orElse: true);
      final saysCoincide = _asBool(parsed['coincide']);

      // Solo consideramos que coincide si es una foto real de la vía pública,
      // Gemini afirma que coincide y la confianza es suficientemente alta.
      final matches = isPublicScene && saysCoincide && confidence >= 50;

      // Si ni siquiera es una foto de la vía pública, no guardamos un análisis
      // de barrera (sería inventado).
      String? analysis;
      if (isPublicScene) {
        final riesgo = parsed['riesgo']?.toString() ?? '';
        final descripcion = parsed['descripcion']?.toString() ?? '';
        final accion = parsed['accion']?.toString() ?? '';
        if (descripcion.isNotEmpty || accion.isNotEmpty) {
          analysis = '[$riesgo] $descripcion\n→ $accion';
        }
      }

      final detectedType = isPublicScene
          ? (parsed['tipo_detectado']?.toString() ?? expectedType)
          : 'No es una foto de la vía pública';

      return BarrierPhotoValidation(
        matches: matches,
        detectedType: detectedType,
        confidence: confidence,
        message: parsed['mensaje']?.toString() ?? '',
        analysis: analysis,
      );
    } catch (_) {
      return null;
    }
  }

  /// Interpreta un valor de Gemini como booleano, ya venga como bool o texto.
  bool _asBool(dynamic value, {bool orElse = false}) {
    if (value is bool) return value;
    if (value is String) return value.trim().toLowerCase() == 'true';
    return orElse;
  }

  Future<String?> getAssistantResponse(String message) async {
    final uri = Uri.parse('$_baseUrl/$_model:generateContent?key=$_apiKey');

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text':
                  '''Eres el asistente de "Tijuana Sin Barreras". Ayudas a personas con discapacidad a moverse en Tijuana.
Responde en español de forma breve (máximo 3 oraciones) y práctica.
Pregunta del usuario: $message'''
            }
          ]
        }
      ],
      'generationConfig': {
        'maxOutputTokens': 150,
        'temperature': 0.5,
        'thinkingConfig': {'thinkingBudget': 0},
      },
    });

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        return candidates[0]['content']['parts'][0]['text'] as String;
      }
    }
    return null;
  }
}
