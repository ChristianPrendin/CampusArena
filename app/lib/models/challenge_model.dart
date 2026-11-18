import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ChallengeModel extends Equatable {
  final String challengeId;
  final String fromUserId;
  final String toUserId;
  final String sportId;
  final String status; // 'pending' | 'accepted' | 'declined' | 'expired'
  final String? matchId;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const ChallengeModel({
    required this.challengeId,
    required this.fromUserId,
    required this.toUserId,
    required this.sportId,
    required this.status,
    this.matchId,
    required this.createdAt,
    this.respondedAt,
  });

  ChallengeModel copyWith({
    String? challengeId,
    String? fromUserId,
    String? toUserId,
    String? sportId,
    String? status,
    String? matchId,
    DateTime? createdAt,
    DateTime? respondedAt,
  }) {
    return ChallengeModel(
      challengeId: challengeId ?? this.challengeId,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      sportId: sportId ?? this.sportId,
      status: status ?? this.status,
      matchId: matchId ?? this.matchId,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'sportId': sportId,
      'status': status,
      'matchId': matchId,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null
          ? Timestamp.fromDate(respondedAt!)
          : null,
    };
  }

  factory ChallengeModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ChallengeModel(
      challengeId: documentId,
      fromUserId: map['fromUserId'] as String? ?? '',
      toUserId: map['toUserId'] as String? ?? '',
      sportId: map['sportId'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      matchId: map['matchId'] as String?,
      createdAt: (map['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      respondedAt: (map['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  List<Object?> get props => [
    challengeId,
    fromUserId,
    toUserId,
    sportId,
    status,
    matchId,
    createdAt,
    respondedAt,
  ];
}
