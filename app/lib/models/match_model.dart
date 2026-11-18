import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../core/constants.dart';

abstract class MatchResult extends Equatable {
  final List<String> winnerIds;

  const MatchResult({required this.winnerIds});

  Map<String, dynamic> toMap();

  @override
  List<Object?> get props => [winnerIds];
}

class PingPongResult extends MatchResult {
  final List<int> sets;
  final List<int> opponentSets;

  const PingPongResult({
    required super.winnerIds,
    required this.sets,
    required this.opponentSets,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'winnerIds': winnerIds,
      'score': {'sets': sets, 'opponentSets': opponentSets},
    };
  }

  factory PingPongResult.fromMap(Map<String, dynamic> map) {
    final score = map['score'] as Map? ?? const {};
    return PingPongResult(
      winnerIds: List<String>.from(map['winnerIds'] as Iterable? ?? const []),
      sets: List<int>.from(score['sets'] as Iterable? ?? const []),
      opponentSets: List<int>.from(
        score['opponentSets'] as Iterable? ?? const [],
      ),
    );
  }

  @override
  List<Object?> get props => [winnerIds, sets, opponentSets];
}

class FoosballResult extends MatchResult {
  final int goals;
  final int opponentGoals;

  const FoosballResult({
    required super.winnerIds,
    required this.goals,
    required this.opponentGoals,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'winnerIds': winnerIds,
      'score': {'goals': goals, 'opponentGoals': opponentGoals},
    };
  }

  factory FoosballResult.fromMap(Map<String, dynamic> map) {
    final score = map['score'] as Map? ?? const {};
    return FoosballResult(
      winnerIds: List<String>.from(map['winnerIds'] as Iterable? ?? const []),
      goals: score['goals'] as int? ?? 0,
      opponentGoals: score['opponentGoals'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [winnerIds, goals, opponentGoals];
}

class GenericMatchResult extends MatchResult {
  final Map<String, dynamic> score;

  const GenericMatchResult({required super.winnerIds, required this.score});

  @override
  Map<String, dynamic> toMap() {
    return {'winnerIds': winnerIds, 'score': score};
  }

  factory GenericMatchResult.fromMap(Map<String, dynamic> map) {
    return GenericMatchResult(
      winnerIds: List<String>.from(map['winnerIds'] as Iterable? ?? const []),
      score: Map<String, dynamic>.from(map['score'] as Map? ?? const {}),
    );
  }

  @override
  List<Object?> get props => [winnerIds, score];
}

class MatchModel extends Equatable {
  final String matchId;
  final String facilityId;
  final String sportId;
  final String mode; // 'singles' | 'doubles'
  final List<String> playerUids;
  final String? team1PairId;
  final String? team2PairId;
  final String
  state; // 'occupied' | 'awaitingConfirmation' | 'confirmed' | 'disputed' | 'unconfirmed' | 'abandoned'
  final String? submittedByUid;
  final MatchResult? result;
  final Map<String, int>? eloBefore;
  final Map<String, int>? eloDeltas;
  final String? tournamentId;
  final String? tournamentRound;
  final double? gpsDistanceMeters;
  final DateTime startedAt;
  final DateTime? confirmedAt;

  const MatchModel({
    required this.matchId,
    required this.facilityId,
    required this.sportId,
    required this.mode,
    required this.playerUids,
    this.team1PairId,
    this.team2PairId,
    required this.state,
    this.submittedByUid,
    this.result,
    this.eloBefore,
    this.eloDeltas,
    this.tournamentId,
    this.tournamentRound,
    this.gpsDistanceMeters,
    required this.startedAt,
    this.confirmedAt,
  });

  MatchModel copyWith({
    String? matchId,
    String? facilityId,
    String? sportId,
    String? mode,
    List<String>? playerUids,
    String? team1PairId,
    String? team2PairId,
    String? state,
    String? submittedByUid,
    MatchResult? result,
    Map<String, int>? eloBefore,
    Map<String, int>? eloDeltas,
    String? tournamentId,
    String? tournamentRound,
    double? gpsDistanceMeters,
    DateTime? startedAt,
    DateTime? confirmedAt,
  }) {
    return MatchModel(
      matchId: matchId ?? this.matchId,
      facilityId: facilityId ?? this.facilityId,
      sportId: sportId ?? this.sportId,
      mode: mode ?? this.mode,
      playerUids: playerUids ?? this.playerUids,
      team1PairId: team1PairId ?? this.team1PairId,
      team2PairId: team2PairId ?? this.team2PairId,
      state: state ?? this.state,
      submittedByUid: submittedByUid ?? this.submittedByUid,
      result: result ?? this.result,
      eloBefore: eloBefore ?? this.eloBefore,
      eloDeltas: eloDeltas ?? this.eloDeltas,
      tournamentId: tournamentId ?? this.tournamentId,
      tournamentRound: tournamentRound ?? this.tournamentRound,
      gpsDistanceMeters: gpsDistanceMeters ?? this.gpsDistanceMeters,
      startedAt: startedAt ?? this.startedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'facilityId': facilityId,
      'sportId': sportId,
      'mode': mode,
      'playerUids': playerUids,
      'team1PairId': team1PairId,
      'team2PairId': team2PairId,
      'state': state,
      'submittedByUid': submittedByUid,
      'result': result?.toMap(),
      'eloBefore': eloBefore,
      'eloDeltas': eloDeltas,
      'tournamentId': tournamentId,
      'tournamentRound': tournamentRound,
      'gpsDistanceMeters': gpsDistanceMeters,
      'startedAt': Timestamp.fromDate(startedAt),
      'confirmedAt': confirmedAt != null
          ? Timestamp.fromDate(confirmedAt!)
          : null,
    };
  }

  factory MatchModel.fromMap(Map<String, dynamic> map, String documentId) {
    final sportId = map['sportId'] as String? ?? '';
    return MatchModel(
      matchId: documentId,
      facilityId: map['facilityId'] as String? ?? '',
      sportId: sportId,
      mode: map['mode'] as String? ?? 'singles',
      playerUids: List<String>.from(map['playerUids'] as Iterable? ?? const []),
      team1PairId: map['team1PairId'] as String?,
      team2PairId: map['team2PairId'] as String?,
      state: map['state'] as String? ?? 'occupied',
      submittedByUid: map['submittedByUid'] as String?,
      result: _parseResult(map['result'] as Map<String, dynamic>?, sportId),
      eloBefore: map['eloBefore'] != null
          ? Map<String, int>.from(map['eloBefore'] as Map)
          : null,
      eloDeltas: map['eloDeltas'] != null
          ? Map<String, int>.from(map['eloDeltas'] as Map)
          : null,
      tournamentId: map['tournamentId'] as String?,
      tournamentRound: map['tournamentRound'] as String?,
      gpsDistanceMeters: (map['gpsDistanceMeters'] as num?)?.toDouble(),
      startedAt: (map['startedAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      confirmedAt: (map['confirmedAt'] as Timestamp?)?.toDate(),
    );
  }

  static MatchResult? _parseResult(
    Map<String, dynamic>? resultMap,
    String sportId,
  ) {
    if (resultMap == null) return null;
    if (sportId == SportIds.pingPong) {
      return PingPongResult.fromMap(resultMap);
    } else if (sportId == SportIds.foosball) {
      return FoosballResult.fromMap(resultMap);
    } else {
      return GenericMatchResult.fromMap(resultMap);
    }
  }

  @override
  List<Object?> get props => [
    matchId,
    facilityId,
    sportId,
    mode,
    playerUids,
    team1PairId,
    team2PairId,
    state,
    submittedByUid,
    result,
    eloBefore,
    eloDeltas,
    tournamentId,
    tournamentRound,
    gpsDistanceMeters,
    startedAt,
    confirmedAt,
  ];
}
