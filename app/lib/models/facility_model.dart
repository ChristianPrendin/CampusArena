import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class Coordinates extends Equatable {
  final double latitude;
  final double longitude;

  const Coordinates({required this.latitude, required this.longitude});

  @override
  List<Object?> get props => [latitude, longitude];
}

class FacilityModel extends Equatable {
  final String facilityId;
  final String name;
  final String sportId;
  final Coordinates coordinates;
  final String qrCode;
  final String fallbackCode;
  final bool isOutdoor;
  final String status; // 'free' | 'occupied' | 'queued'
  final String? currentMatchId;
  final String? kingOfTableUid;
  final int kingOfTableWins;
  final int queueTailPosition;
  final DateTime? freedAt;

  const FacilityModel({
    required this.facilityId,
    required this.name,
    required this.sportId,
    required this.coordinates,
    required this.qrCode,
    required this.fallbackCode,
    required this.isOutdoor,
    required this.status,
    this.currentMatchId,
    this.kingOfTableUid,
    required this.kingOfTableWins,
    required this.queueTailPosition,
    this.freedAt,
  });

  FacilityModel copyWith({
    String? facilityId,
    String? name,
    String? sportId,
    Coordinates? coordinates,
    String? qrCode,
    String? fallbackCode,
    bool? isOutdoor,
    String? status,
    String? currentMatchId,
    String? kingOfTableUid,
    int? kingOfTableWins,
    int? queueTailPosition,
    DateTime? freedAt,
  }) {
    return FacilityModel(
      facilityId: facilityId ?? this.facilityId,
      name: name ?? this.name,
      sportId: sportId ?? this.sportId,
      coordinates: coordinates ?? this.coordinates,
      qrCode: qrCode ?? this.qrCode,
      fallbackCode: fallbackCode ?? this.fallbackCode,
      isOutdoor: isOutdoor ?? this.isOutdoor,
      status: status ?? this.status,
      currentMatchId: currentMatchId ?? this.currentMatchId,
      kingOfTableUid: kingOfTableUid ?? this.kingOfTableUid,
      kingOfTableWins: kingOfTableWins ?? this.kingOfTableWins,
      queueTailPosition: queueTailPosition ?? this.queueTailPosition,
      freedAt: freedAt ?? this.freedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sportId': sportId,
      'coordinates': GeoPoint(coordinates.latitude, coordinates.longitude),
      'qrCode': qrCode,
      'fallbackCode': fallbackCode,
      'isOutdoor': isOutdoor,
      'status': status,
      'currentMatchId': currentMatchId,
      'kingOfTableUid': kingOfTableUid,
      'kingOfTableWins': kingOfTableWins,
      'queueTailPosition': queueTailPosition,
      'freedAt': freedAt != null ? Timestamp.fromDate(freedAt!) : null,
    };
  }

  factory FacilityModel.fromMap(Map<String, dynamic> map, String documentId) {
    final geoPoint = map['coordinates'] as GeoPoint? ?? const GeoPoint(0, 0);
    return FacilityModel(
      facilityId: documentId,
      name: map['name'] as String? ?? '',
      sportId: map['sportId'] as String? ?? '',
      coordinates: Coordinates(
        latitude: geoPoint.latitude,
        longitude: geoPoint.longitude,
      ),
      qrCode: map['qrCode'] as String? ?? '',
      fallbackCode: map['fallbackCode'] as String? ?? '',
      isOutdoor: map['isOutdoor'] as bool? ?? false,
      status: map['status'] as String? ?? 'free',
      currentMatchId: map['currentMatchId'] as String?,
      kingOfTableUid: map['kingOfTableUid'] as String?,
      // Firestore may hand numeric fields back as double (`as int` would throw
      // and blank the facility stream), so coerce through num.
      kingOfTableWins: (map['kingOfTableWins'] as num?)?.toInt() ?? 0,
      queueTailPosition: (map['queueTailPosition'] as num?)?.toInt() ?? 0,
      freedAt: (map['freedAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  List<Object?> get props => [
    facilityId,
    name,
    sportId,
    coordinates,
    qrCode,
    fallbackCode,
    isOutdoor,
    status,
    currentMatchId,
    kingOfTableUid,
    kingOfTableWins,
    queueTailPosition,
    freedAt,
  ];
}

class QueueEntryModel extends Equatable {
  final String uid;
  final String facilityId;
  final int position;
  final DateTime joinedAt;

  const QueueEntryModel({
    required this.uid,
    required this.facilityId,
    required this.position,
    required this.joinedAt,
  });

  QueueEntryModel copyWith({
    String? uid,
    String? facilityId,
    int? position,
    DateTime? joinedAt,
  }) {
    return QueueEntryModel(
      uid: uid ?? this.uid,
      facilityId: facilityId ?? this.facilityId,
      position: position ?? this.position,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': uid, // Mapped to userId in Firestore schema
      'position': position,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  factory QueueEntryModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
    String facilityId,
  ) {
    return QueueEntryModel(
      uid: documentId,
      facilityId: facilityId,
      // Firestore may hand numeric fields back as double (`as int` would throw
      // and drop the queue entry), so coerce through num like the facility
      // fields above.
      position: (map['position'] as num?)?.toInt() ?? 0,
      joinedAt: (map['joinedAt'] as Timestamp? ?? Timestamp.now()).toDate(),
    );
  }

  @override
  List<Object?> get props => [uid, facilityId, position, joinedAt];
}
