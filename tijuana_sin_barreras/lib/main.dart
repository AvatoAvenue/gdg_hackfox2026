import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/services/firebase_service.dart';
import 'core/services/maps_service.dart';
import 'core/services/gemini_service.dart';
import 'core/services/tts_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final tts = TtsService();
  await tts.init();

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => FirebaseService()),
        Provider(create: (_) => MapsService()),
        Provider(create: (_) => GeminiService()),
        Provider<TtsService>.value(value: tts),
      ],
      child: const TijuanaSinBarrerasApp(),
    ),
  );
}
