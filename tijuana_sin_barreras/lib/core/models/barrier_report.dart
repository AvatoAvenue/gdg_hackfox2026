import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

class BarrierReport {
  final String id;
  final double lat;
  final double lng;
  final String type;
  final String description;

  /// Foto codificada en base64 y guardada dentro del documento de Firestore.
  /// Se usa este enfoque en vez de Firebase Storage (que requiere plan Blaze).
  final String? photoBase64;
  final String? geminiAnalysis;
  final DateTime reportedAt;
  final String status;
  final String? userId;
  final String? verifiedBy;
  final DateTime? verifiedAt;

  const BarrierReport({
    required this.id,
    required this.lat,
    required this.lng,
    required this.type,
    required this.description,
    this.photoBase64,
    this.geminiAnalysis,
    required this.reportedAt,
    this.status = 'pending',
    this.userId,
    this.verifiedBy,
    this.verifiedAt,
  });

  /// Bytes decodificados de la foto, listos para `Image.memory`. Null si no hay
  /// foto o si el contenido no es base64 válido.
  Uint8List? get photoBytes {
    if (photoBase64 == null || photoBase64!.isEmpty) return null;
    try {
      return base64Decode(photoBase64!);
    } catch (_) {
      return null;
    }
  }

  factory BarrierReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BarrierReport(
      id: doc.id,
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      type: data['type'] as String? ?? 'Otro',
      description: data['description'] as String? ?? '',
      photoBase64: data['photoBase64'] as String?,
      geminiAnalysis: data['geminiAnalysis'] as String?,
      reportedAt: data['reportedAt'] != null
          ? (data['reportedAt'] as Timestamp).toDate()
          : DateTime.now(),
      status: data['status'] as String? ?? 'pending',
      userId: data['userId'] as String?,
      verifiedBy: data['verifiedBy'] as String?,
      verifiedAt: data['verifiedAt'] != null
          ? (data['verifiedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lng': lng,
        'type': type,
        'description': description,
        'photoBase64': photoBase64,
        'geminiAnalysis': geminiAnalysis,
        'reportedAt': Timestamp.fromDate(reportedAt),
        'status': status,
        'userId': userId,
        'verifiedBy': verifiedBy,
        'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      };
}
