import 'package:firebase_auth/firebase_auth.dart';

/// Traduce los códigos de error de Firebase Auth a mensajes en español.
String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'El correo no tiene un formato válido.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con este correo.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu internet.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento.';
      default:
        return error.message ?? 'Ocurrió un error de autenticación.';
    }
  }
  return 'Ocurrió un error inesperado. Intenta de nuevo.';
}
