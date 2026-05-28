import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/barrier_report.dart';

class FirebaseService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  Future<void> signInAnonymously() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  String? get currentUserId => _auth.currentUser?.uid;

  Stream<List<BarrierReport>> getBarriers() {
    return _db
        .collection('barriers')
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(BarrierReport.fromFirestore).toList());
  }

  Future<String> uploadBarrierPhoto(File photo) async {
    final id = _uuid.v4();
    final ref = _storage.ref('barriers/$id.jpg');
    await ref.putFile(photo, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<String> submitBarrierReport({
    required double lat,
    required double lng,
    required String type,
    required String description,
    String? photoUrl,
    String? geminiAnalysis,
  }) async {
    await signInAnonymously();
    final doc = await _db.collection('barriers').add({
      'lat': lat,
      'lng': lng,
      'type': type,
      'description': description,
      'photoUrl': photoUrl,
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
}
