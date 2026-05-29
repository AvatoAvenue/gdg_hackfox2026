import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/firebase_service.dart';

/// Abre el flujo de reporte de barrera, exigiendo sesión iniciada.
///
/// Si el usuario ya tiene sesión, navega directo a `/report`. Si no, muestra un
/// aviso, lo envía al login y, tras un inicio de sesión exitoso, continúa hacia
/// `/report`. La sesión la conserva Firebase Auth hasta que el usuario cierre
/// sesión, así que solo se pide login una vez.
///
/// Usado por todos los botones "Reportar" (home, mapa y ruta) para que el
/// comportamiento sea idéntico en toda la app.
Future<void> openReportGuarded(BuildContext context) async {
  final firebase = context.read<FirebaseService>();
  if (firebase.isSignedIn) {
    Navigator.pushNamed(context, '/report');
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Inicia sesión para reportar una barrera.')),
  );
  final loggedIn = await Navigator.pushNamed(context, '/login');
  if (loggedIn == true && context.mounted) {
    Navigator.pushNamed(context, '/report');
  }
}
