import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class RatingModel extends Equatable {
  final String ratingId;
  final String ownerType; // 'user' | 'pair'
  final String ownerId;
  final List<String>? memberUids;
  final String sportId; // 'ping_pong' | 'foosball' | 'padel'
  final String? degreeProgram;
  final int elo;
  final int matchesPlayed;
  final DateTime lastMatchAt;

  const RatingModel({
    required this.ratingId,
    required this.ownerType,
    required this.ownerId,
    this.memberUids,
    required this.sportId,
    this.degreeProgram,
    required this.elo,
    required this.matchesPlayed,
    required this.lastMatchAt,
  });

  RatingModel copyWith({
    String? ratingId,
    String? ownerType,
    String? ownerId,
    List<String>? memberUids,
    String? sportId,
    String? degreeProgram,
    int? elo,
    int? matchesPlayed,
    DateTime? lastMatchAt,
  }) {
    return RatingModel(
      ratingId: ratingId ?? this.ratingId,
      ownerType: ownerType ?? this.ownerType,
      ownerId: ownerId ?? this.ownerId,
      memberUids: memberUids ?? this.memberUids,
      sportId: sportId ?? this.sportId,
      degreeProgram: degreeProgram ?? this.degreeProgram,
      elo: elo ?? this.elo,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      lastMatchAt: lastMatchAt ?? this.lastMatchAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerType': ownerType,
      'ownerId': ownerId,
      'memberUids': memberUids,
      'sportId': sportId,
      'degreeProgram': degreeProgram,
      'elo': elo,
      'matchesPlayed': matchesPlayed,
      'lastMatchAt': Timestamp.fromDate(lastMatchAt),
    };
  }

  factory RatingModel.fromMap(Map<String, dynamic> map, String documentId) {
    return RatingModel(
      ratingId: documentId,
      ownerType: map['ownerType'] as String? ?? 'user',
      ownerId: map['ownerId'] as String? ?? '',
      memberUids: map['memberUids'] != null
          ? List<String>.from(map['memberUids'] as Iterable)
          : null,
      sportId: map['sportId'] as String? ?? '',
      degreeProgram: map['degreeProgram'] as String?,
      elo: (map['elo'] as num? ?? 1200).toInt(),
      matchesPlayed: map['matchesPlayed'] as int? ?? 0,
      lastMatchAt: (map['lastMatchAt'] as Timestamp? ?? Timestamp.now())
          .toDate(),
    );
  }

  @override
  List<Object?> get props => [
    ratingId,
    ownerType,
    ownerId,
    memberUids,
    sportId,
    degreeProgram,
    elo,
    matchesPlayed,
    lastMatchAt,
  ];
}
