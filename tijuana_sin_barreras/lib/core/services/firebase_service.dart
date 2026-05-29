import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../constants/demo_barriers.dart';
import '../models/barrier_report.dart';
import '../models/emergency_alert.dart';
import '../models/user_profile.dart';

class FirebaseService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();

  // ---------------------------------------------------------------------------
  // AUTH — Google Sign-In + email/password
  // ---------------------------------------------------------------------------

  /// Stream del estado de sesión (úsalo para decidir login vs. home).
  Stream<User?> get authState => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;
  bool get isSignedIn => _auth.currentUser != null;

  /// Inicio de sesión con Google. Devuelve null si el usuario cancela.
  ///
  /// - **Web**: usa `signInWithPopup` de Firebase (el plugin google_sign_in
  ///   no soporta `signIn()` en web). No requiere SHA-1.
  /// - **Android**: usa el plugin google_sign_in. Requiere SHA-1 registrado
  ///   en Firebase Console y el google-services.json actualizado.
  Future<UserProfile?> signInWithGoogle() async {
    if (kIsWeb) {
      final cred = await _auth.signInWithPopup(GoogleAuthProvider());
      if (cred.user == null) return null;
      return _ensureProfile(cred.user!, displayName: cred.user!.displayName);
    }

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // cancelado por el usuario
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    return _ensureProfile(cred.user!, displayName: cred.user!.displayName);
  }

  /// Registro con correo y contraseña. Crea también el perfil en Firestore.
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user!.updateDisplayName(displayName.trim());
    return _ensureProfile(cred.user!, displayName: displayName.trim());
  }

  /// Inicio de sesión con correo y contraseña.
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _ensureProfile(cred.user!);
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    if (!kIsWeb) await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // PERFILES — colección /users/{uid} con rol ciudadano | moderador
  // ---------------------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  /// Crea el perfil si no existe (rol = ciudadano). Idempotente.
  Future<UserProfile> _ensureProfile(User user, {String? displayName}) async {
    final ref = _userDoc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return UserProfile.fromFirestore(snap);

    final profile = UserProfile(
      uid: user.uid,
      email: user.email,
      displayName: displayName ?? user.displayName ?? 'Ciudadano',
      createdAt: DateTime.now(),
    );
    await ref.set(profile.toCreateMap());
    return profile;
  }

  /// Perfil del usuario actual (null si no hay sesión o es anónimo sin perfil).
  Future<UserProfile?> getCurrentProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;
    final snap = await _userDoc(uid).get();
    return snap.exists ? UserProfile.fromFirestore(snap) : null;
  }

  /// Stream reactivo del perfil del usuario actual.
  Stream<UserProfile?> watchCurrentProfile() {
    final uid = currentUserId;
    if (uid == null) return Stream.value(null);
    return _userDoc(uid).snapshots().map(
          (snap) => snap.exists ? UserProfile.fromFirestore(snap) : null,
        );
  }

  Future<bool> get isModerator async =>
      (await getCurrentProfile())?.isModerator ?? false;

  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _userDoc(uid).update({
      if (displayName != null) 'displayName': displayName.trim(),
      if (photoUrl != null) 'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // BARRERAS
  // ---------------------------------------------------------------------------

  Stream<List<BarrierReport>> getBarriers() {
    return _db
        .collection('barriers')
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(BarrierReport.fromFirestore).toList());
  }

  /// Lectura puntual (no stream) de las barreras activas — las que aún
  /// obstaculizan el paso (estado distinto de `resolved`). Se usa al calcular
  /// una ruta para saber qué obstáculos evitar.
  Future<List<BarrierReport>> getActiveBarriersOnce() async {
    final snap = await _db.collection('barriers').get();
    return snap.docs
        .map(BarrierReport.fromFirestore)
        .where((b) => b.status != 'resolved')
        .toList();
  }

  Future<String> submitBarrierReport({
    required double lat,
    required double lng,
    required String type,
    required String description,
    String? photoBase64,
    String? geminiAnalysis,
  }) async {
    if (!isSignedIn) {
      throw StateError('Inicia sesión para reportar una barrera.');
    }
    final doc = await _db.collection('barriers').add({
      'lat': lat,
      'lng': lng,
      'type': type,
      'description': description,
      'photoBase64': photoBase64,
      'geminiAnalysis': geminiAnalysis,
      'reportedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
      'userId': currentUserId,
    });
    return doc.id;
  }

  Future<void> updateGeminiAnalysis(String barrierId, String analysis) async {
    await _db.collection('barriers').doc(barrierId).update({
      'geminiAnalysis': analysis,
    });
  }

  /// Verificación de una barrera por un moderador.
  /// Las reglas de Firestore exigen rol `moderador` para que esto funcione.
  /// [status] debe ser 'verified', 'resolved' o 'pending'.
  Future<void> moderateBarrier(String barrierId, String status) async {
    await _db.collection('barriers').doc(barrierId).update({
      'status': status,
      'verifiedBy': currentUserId,
      'verifiedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // DATOS DE DEMO — obstáculos de ejemplo para probar el ruteo
  // ---------------------------------------------------------------------------

  /// Siembra los obstáculos de ejemplo de [DemoBarriers] en Firestore.
  ///
  /// Escribe EXACTAMENTE los mismos campos que [submitBarrierReport] (la ruta
  /// que ya pasa las reglas de seguridad): `status: 'pending'` y
  /// `userId: currentUserId`, sin campos extra. Lo único distinto es que usa
  /// IDs de documento estables (`demo-XX`) en vez de IDs autogenerados, para
  /// que volver a sembrar sea idempotente y se puedan borrar después.
  ///
  /// Devuelve cuántos se escribieron. Requiere sesión iniciada.
  Future<int> seedDemoBarriers() async {
    if (!isSignedIn) {
      throw StateError('Inicia sesión para sembrar obstáculos de demo.');
    }
    final batch = _db.batch();
    for (final b in DemoBarriers.all) {
      final ref = _db.collection('barriers').doc(b.id);
      batch.set(ref, {
        'lat': b.lat,
        'lng': b.lng,
        'type': b.type,
        'description': b.description,
        'photoBase64': null,
        'geminiAnalysis': null,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'userId': currentUserId,
      });
    }
    await batch.commit();
    return DemoBarriers.all.length;
  }

  /// Borra los obstáculos de demo por sus IDs estables (`demo-XX`).
  /// Devuelve cuántos borró.
  Future<int> clearDemoBarriers() async {
    if (!isSignedIn) {
      throw StateError('Inicia sesión para borrar obstáculos de demo.');
    }
    final batch = _db.batch();
    for (final b in DemoBarriers.all) {
      batch.delete(_db.collection('barriers').doc(b.id));
    }
    await batch.commit();
    return DemoBarriers.all.length;
  }

  // ---------------------------------------------------------------------------
  // ALERTAS DE EMERGENCIA SOS
  // ---------------------------------------------------------------------------

  /// Crea una alerta SOS activa con la ubicación del usuario.
  /// Devuelve el ID del documento creado.
  Future<String> sendEmergencyAlert({
    required double lat,
    required double lng,
    String? userName,
  }) async {
    if (!isSignedIn) {
      throw StateError('Inicia sesión para enviar una alerta de emergencia.');
    }
    final doc = await _db.collection('emergency_alerts').add({
      'lat': lat,
      'lng': lng,
      'userId': currentUserId,
      'userName': userName,
      'createdAt': FieldValue.serverTimestamp(),
      'active': true,
    });
    return doc.id;
  }

  /// Stream de alertas SOS activas de las últimas 2 horas.
  Stream<List<EmergencyAlert>> getActiveEmergencyAlerts() {
    return _db
        .collection('emergency_alerts')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final cutoff = DateTime.now().subtract(const Duration(hours: 2));
      return snap.docs
          .map(EmergencyAlert.fromFirestore)
          .where((a) => a.createdAt.isAfter(cutoff))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  /// Desactiva la alerta SOS del usuario (cancela la emergencia).
  Future<void> cancelEmergencyAlert(String alertId) async {
    await _db.collection('emergency_alerts').doc(alertId).update({
      'active': false,
    });
  }
}
