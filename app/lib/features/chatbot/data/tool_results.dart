import 'package:equatable/equatable.dart';

/// Typed result of [ChatbotToolsService.getEmptyTables] /
/// [ChatbotToolsService.getFacilitiesByStatus] — one row per facility so the
/// UI can render a [FacilityStatusCard] without re-parsing strings.
class FacilityToolResult extends Equatable {
  final String facilityId;
  final String name;
  final String sportId;
  final String status;
  final int queueLength;

  const FacilityToolResult({
    required this.facilityId,
    required this.name,
    required this.sportId,
    required this.status,
    required this.queueLength,
  });

  @override
  List<Object?> get props => [facilityId, name, sportId, status, queueLength];
}

/// Typed result of [ChatbotToolsService.getTournamentsToday].
class TournamentToolResult extends Equatable {
  final String tournamentId;
  final String name;
  final String sportId;
  final String status;
  final DateTime scheduledAt;
  final int participantCount;
  final int maxParticipants;

  const TournamentToolResult({
    required this.tournamentId,
    required this.name,
    required this.sportId,
    required this.status,
    required this.scheduledAt,
    required this.participantCount,
    required this.maxParticipants,
  });

  @override
  List<Object?> get props => [
    tournamentId,
    name,
    sportId,
    status,
    scheduledAt,
    participantCount,
    maxParticipants,
  ];
}

/// Typed result of [ChatbotToolsService.getUserQueuePosition].
class QueuePositionToolResult extends Equatable {
  final String facilityId;
  final String facilityName;
  final int position;

  const QueuePositionToolResult({
    required this.facilityId,
    required this.facilityName,
    required this.position,
  });

  @override
  List<Object?> get props => [facilityId, facilityName, position];
}

/// Typed result of [ChatbotToolsService.getUserEloAndRank].
class EloRankToolResult extends Equatable {
  final String sportId;
  final int elo;
  final int? rank;
  final int matchesPlayed;

  const EloRankToolResult({
    required this.sportId,
    required this.elo,
    required this.rank,
    required this.matchesPlayed,
  });

  @override
  List<Object?> get props => [sportId, elo, rank, matchesPlayed];
}
