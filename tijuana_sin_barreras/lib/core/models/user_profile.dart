import 'package:cloud_firestore/cloud_firestore.dart';

/// Roles de cuenta en Tijuana Sin Barreras.
/// - [ciudadano]: reporta barreras (rol por defecto).
/// - [moderador]: además puede verificar/resolver barreras reportadas.
class UserRole {
  static const String ciudadano = 'ciudadano';
  static const String moderador = 'moderador';

  static const List<String> all = [ciudadano, moderador];

  static bool isValid(String role) => all.contains(role);
}

/// Perfil de usuario almacenado en Firestore `/users/{uid}`.
class UserProfile {
  final String uid;
  final String? email;
  final String displayName;
  final String role;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.uid,
    required this.displayName,
    this.email,
    this.role = UserRole.ciudadano,
    this.photoUrl,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isModerator => role == UserRole.moderador;
  bool get isAnonymous => email == null;

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      email: data['email'] as String?,
      displayName: data['displayName'] as String? ?? 'Ciudadano',
      role: data['role'] as String? ?? UserRole.ciudadano,
      photoUrl: data['photoUrl'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Datos para crear el documento de perfil.
  /// El rol SIEMPRE se crea como `ciudadano`; el ascenso a `moderador`
  /// se hace manualmente desde Firebase Console (lo refuerzan las reglas).
  Map<String, dynamic> toCreateMap() => {
        'email': email,
        'displayName': displayName,
        'role': UserRole.ciudadano,
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
