import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_keys.dart';

class GeminiService {
  String get _apiKey => ApiKeys.geminiApiKey;
  static const _model = 'gemini-1.5-flash';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  Future<String?> analyzeBarrierPhoto(File photo) async {
    final bytes = await photo.readAsBytes();
    final base64Image = base64Encode(bytes);

    final uri = Uri.parse('$_baseUrl/$_model:generateContent?key=$_apiKey');
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text': '''Eres un experto en accesibilidad urbana de Tijuana, México.
Analiza esta imagen e identifica la barrera de accesibilidad.
Responde ÚNICAMENTE con JSON válido, sin texto adicional:
{"tipo": "nombre del tipo de barrera", "riesgo": "Alto|Medio|Bajo", "accion": "acción municipal recomendada en 1 oración", "descripcion": "descripción breve en 1-2 oraciones"}'''
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
        'maxOutputTokens': 256,
      }
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
        final text =
            candidates[0]['content']['parts'][0]['text'] as String;
        return _formatGeminiResponse(text.trim());
      }
    }
    return null;
  }

  String _formatGeminiResponse(String raw) {
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}') + 1;
      if (start >= 0 && end > start) {
        final jsonStr = raw.substring(start, end);
        final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
        final riesgo = parsed['riesgo'] ?? '';
        final descripcion = parsed['descripcion'] ?? '';
        final accion = parsed['accion'] ?? '';
        return '[$riesgo] $descripcion\n→ $accion';
      }
    } catch (_) {}
    return raw;
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
      'generationConfig': {'maxOutputTokens': 150, 'temperature': 0.5},
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
