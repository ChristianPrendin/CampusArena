import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class TournamentModel extends Equatable {
  final String tournamentId;
  final String name;
  final String sportId;
  final String facilityId;
  final String organizerId;
  final int maxParticipants;

  /// Denormalized registered-participant count, maintained atomically inside
  /// `registerParticipant`'s transaction and reconciled at seeding. Lets the
  /// browser feed show `n/max` without a per-card participants subcollection
  /// read (the detail/bracket screens still use the live roster).
  final int participantCount;
  final String
  status; // 'registering' | 'seeded' | 'active' | 'completed' | 'cancelled'
  final Map<String, List<String>> bracket; // round -> list of matchIds
  final String? winnerUid;
  final double eloMultiplier;
  final DateTime registrationDeadline;
  final DateTime scheduledAt;
  final DateTime createdAt;

  const TournamentModel({
    required this.tournamentId,
    required this.name,
    required this.sportId,
    required this.facilityId,
    required this.organizerId,
    required this.maxParticipants,
    this.participantCount = 0,
    required this.status,
    required this.bracket,
    this.winnerUid,
    required this.eloMultiplier,
    required this.registrationDeadline,
    required this.scheduledAt,
    required this.createdAt,
  });

  TournamentModel copyWith({
    String? tournamentId,
    String? name,
    String? sportId,
    String? facilityId,
    String? organizerId,
    int? maxParticipants,
    int? participantCount,
    String? status,
    Map<String, List<String>>? bracket,
    String? winnerUid,
    double? eloMultiplier,
    DateTime? registrationDeadline,
    DateTime? scheduledAt,
    DateTime? createdAt,
  }) {
    return TournamentModel(
      tournamentId: tournamentId ?? this.tournamentId,
      name: name ?? this.name,
      sportId: sportId ?? this.sportId,
      facilityId: facilityId ?? this.facilityId,
      organizerId: organizerId ?? this.organizerId,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      participantCount: participantCount ?? this.participantCount,
      status: status ?? this.status,
      bracket: bracket ?? this.bracket,
      winnerUid: winnerUid ?? this.winnerUid,
      eloMultiplier: eloMultiplier ?? this.eloMultiplier,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sportId': sportId,
      'facilityId': facilityId,
      'organizerId': organizerId,
      'maxParticipants': maxParticipants,
      'participantCount': participantCount,
      'status': status,
      'bracket': bracket,
      'winnerUid': winnerUid,
      'eloMultiplier': eloMultiplier,
      'registrationDeadline': Timestamp.fromDate(registrationDeadline),
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TournamentModel.fromMap(Map<String, dynamic> map, String documentId) {
    final bracketMap = map['bracket'] as Map? ?? const {};
    final bracket = bracketMap.map(
      (key, value) => MapEntry(
        key as String,
        List<String>.from(value as Iterable? ?? const []),
      ),
    );

    return TournamentModel(
      tournamentId: documentId,
      name: map['name'] as String? ?? '',
      sportId: map['sportId'] as String? ?? '',
      facilityId: map['facilityId'] as String? ?? '',
      organizerId: map['organizerId'] as String? ?? '',
      maxParticipants: map['maxParticipants'] as int? ?? 8,
      participantCount: (map['participantCount'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? 'registering',
      bracket: bracket,
      winnerUid: map['winnerUid'] as String?,
      eloMultiplier: (map['eloMultiplier'] as num? ?? 1.5).toDouble(),
      registrationDeadline:
          (map['registrationDeadline'] as Timestamp? ?? Timestamp.now())
              .toDate(),
      scheduledAt: (map['scheduledAt'] as Timestamp? ?? Timestamp.now())
          .toDate(),
      createdAt: (map['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
    );
  }

  @override
  List<Object?> get props => [
    tournamentId,
    name,
    sportId,
    facilityId,
    organizerId,
    maxParticipants,
    participantCount,
    status,
    bracket,
    winnerUid,
    eloMultiplier,
    registrationDeadline,
    scheduledAt,
    createdAt,
  ];
}

/// How an `eliminated` participant left the bracket, when the elimination was an
/// organizer action (a derived confirmed-match loss stores no reason). Keeps an
/// organizer-declared win (`advanced`) distinguishable in the data from a
/// no-show/withdrawal (`forfeit`), which the engine would otherwise read
/// identically.
class EliminationReason {
  const EliminationReason._();
  static const String forfeit = 'forfeit';
  static const String advanced = 'advanced';
}

class TournamentParticipantModel extends Equatable {
  final String uid;
  final int seed;
  final bool eliminated;

  /// Why this participant was eliminated by an organizer action — one of
  /// [EliminationReason]. Null when not eliminated, or when the elimination is
  /// derived from a confirmed bracket match rather than written by the organizer.
  final String? eliminationReason;

  const TournamentParticipantModel({
    required this.uid,
    required this.seed,
    required this.eliminated,
    this.eliminationReason,
  });

  TournamentParticipantModel copyWith({
    String? uid,
    int? seed,
    bool? eliminated,
    String? eliminationReason,
  }) {
    return TournamentParticipantModel(
      uid: uid ?? this.uid,
      seed: seed ?? this.seed,
      eliminated: eliminated ?? this.eliminated,
      eliminationReason: eliminationReason ?? this.eliminationReason,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'seed': seed,
      'eliminated': eliminated,
      if (eliminationReason != null) 'eliminationReason': eliminationReason,
    };
  }

  factory TournamentParticipantModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return TournamentParticipantModel(
      uid: documentId,
      seed: map['seed'] as int? ?? 0,
      eliminated: map['eliminated'] as bool? ?? false,
      eliminationReason: map['eliminationReason'] as String?,
    );
  }

  @override
  List<Object?> get props => [uid, seed, eliminated, eliminationReason];
}
