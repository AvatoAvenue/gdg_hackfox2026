import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/services/firebase_service.dart';
import 'core/services/maps_service.dart';
import 'core/services/gemini_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => FirebaseService()),
        Provider(create: (_) => MapsService()),
        Provider(create: (_) => GeminiService()),
      ],
      child: const TijuanaSinBarrerasApp(),
    ),
  );
}
