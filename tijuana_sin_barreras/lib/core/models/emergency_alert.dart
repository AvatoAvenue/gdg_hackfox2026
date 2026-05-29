import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyAlert {
  final String id;
  final double lat;
  final double lng;
  final String? userId;
  final String? userName;
  final DateTime createdAt;
  final bool active;

  const EmergencyAlert({
    required this.id,
    required this.lat,
    required this.lng,
    this.userId,
    this.userName,
    required this.createdAt,
    required this.active,
  });

  factory EmergencyAlert.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data()!;
    return EmergencyAlert(
      id: doc.id,
      lat: (d['lat'] as num).toDouble(),
      lng: (d['lng'] as num).toDouble(),
      userId: d['userId'] as String?,
      userName: d['userName'] as String?,
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      active: d['active'] as bool? ?? false,
    );
  }
}
