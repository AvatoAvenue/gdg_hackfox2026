import 'package:cloud_firestore/cloud_firestore.dart';

class BarrierReport {
  final String id;
  final double lat;
  final double lng;
  final String type;
  final String description;
  final String? photoUrl;
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
    this.photoUrl,
    this.geminiAnalysis,
    required this.reportedAt,
    this.status = 'pending',
    this.userId,
    this.verifiedBy,
    this.verifiedAt,
  });

  factory BarrierReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BarrierReport(
      id: doc.id,
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      type: data['type'] as String? ?? 'Otro',
      description: data['description'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
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
        'photoUrl': photoUrl,
        'geminiAnalysis': geminiAnalysis,
        'reportedAt': Timestamp.fromDate(reportedAt),
        'status': status,
        'userId': userId,
        'verifiedBy': verifiedBy,
        'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      };
}
