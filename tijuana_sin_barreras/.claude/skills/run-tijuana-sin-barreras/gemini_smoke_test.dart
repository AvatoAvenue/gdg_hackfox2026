// ignore_for_file: avoid_print
// Harness de extremo a extremo del flujo de validación de fotos con Gemini.
// Ejecuta el código REAL de la app (GeminiService) contra la API en vivo,
// usando la API key de .env, con dos imágenes de fixture:
//   • fixtures/real_barrier.jpg -> foto real de banqueta dañada (DEBE coincidir)
//   • fixtures/not_street.jpg   -> foto de un gato (NO vía pública, NO coincide)
//
// Correr desde la raíz del paquete (tijuana_sin_barreras/):
//   flutter test .claude/skills/run-tijuana-sin-barreras/gemini_smoke_test.dart
//
// NOTAS (lecciones aprendidas):
//  • La RED funciona normalmente en `flutter test` cuando se usa `test()` plano
//    (no `testWidgets`): el binding que bloquea HTTP solo se instala si se
//    inicializa. No hace falta tocar HttpOverrides.
//  • Carga .env con `dotenv.testLoad` (lee del disco), NO `dotenv.load`, que
//    usa rootBundle y requeriría el binding.
//  • gemini-2.5-flash tiene límite de cuota free-tier (RPM). Bajo uso intenso
//    devuelve 429 y `validateBarrierPhoto` retorna null. Por eso reintentamos
//    con backoff. Si aún falla, espera ~60s y reintenta; no lo corras en bucle.
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tijuana_sin_barreras/core/services/gemini_service.dart';

const _skillDir = '.claude/skills/run-tijuana-sin-barreras';

/// Llama a validateBarrierPhoto reintentando si devuelve null (típicamente un
/// 429 por cuota free-tier). Hasta 3 intentos con espera creciente.
Future<BarrierPhotoValidation?> _validateWithRetry(
    Uint8List bytes, String type) async {
  final svc = GeminiService();
  for (var attempt = 1; attempt <= 3; attempt++) {
    final v = await svc.validateBarrierPhoto(bytes, type);
    if (v != null) return v;
    if (attempt < 3) {
      print('  (intento $attempt devolvió null — posible 429; esperando...)');
      await Future.delayed(Duration(seconds: 20 * attempt));
    }
  }
  return null;
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: File('.env').readAsStringSync());
  });

  test('foto real de banqueta dañada COINCIDE', () async {
    final bytes = await File('$_skillDir/fixtures/real_barrier.jpg').readAsBytes();
    final v = await _validateWithRetry(bytes, 'Banqueta dañada');

    expect(v, isNotNull,
        reason: 'Gemini no respondió tras reintentos. Revisa GEMINI_API_KEY '
            'en .env, o espera ~60s si es límite de cuota (429).');
    print('\n[REAL] matches=${v!.matches}  confianza=${v.confidence}'
        '\n  tipo_detectado: ${v.detectedType}'
        '\n  mensaje: ${v.message}'
        '\n  analysis: ${v.analysis}\n');
    expect(v.matches, isTrue);
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('imagen ficticia (gato) NO coincide (no es vía pública)', () async {
    final bytes = await File('$_skillDir/fixtures/not_street.jpg').readAsBytes();
    final v = await _validateWithRetry(bytes, 'Banqueta dañada');

    expect(v, isNotNull,
        reason: 'Gemini no respondió tras reintentos. Revisa GEMINI_API_KEY '
            'en .env, o espera ~60s si es límite de cuota (429).');
    print('\n[FAKE] matches=${v!.matches}  confianza=${v.confidence}'
        '\n  tipo_detectado: ${v.detectedType}'
        '\n  mensaje: ${v.message}'
        '\n  analysis: ${v.analysis}\n');
    expect(v.matches, isFalse);
  }, timeout: const Timeout(Duration(seconds: 120)));
}
