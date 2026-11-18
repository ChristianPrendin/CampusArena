import 'package:flutter/foundation.dart';

import '../../../core/constants.dart';
import '../../../repositories/facility_repository.dart';
import '../../../repositories/queue_repository.dart';
import '../../../repositories/rating_repository.dart';
import '../../../repositories/tournament_repository.dart';
import 'tool_results.dart';

/// Read-only tool layer over the existing repositories. Every method here is
/// a single bounded (`limit`-ed) one-shot query — never a listener — so the
/// chatbot never adds a persistent Firestore subscription on top of the ones
/// the rest of the app already holds (Spark tier read-quota discipline).
///
/// The chatbot vertical never touches Firestore directly; it only calls
/// through these existing repositories, mirroring the rest of the app.
class ChatbotToolsService {
  ChatbotToolsService({
    FacilityRepository? facilityRepository,
    TournamentRepository? tournamentRepository,
    QueueRepository? queueRepository,
    RatingRepository? ratingRepository,
  }) : _facilityRepository = facilityRepository ?? FacilityRepository(),
       _tournamentRepository = tournamentRepository ?? TournamentRepository(),
       _queueRepository = queueRepository ?? QueueRepository(),
       _ratingRepository = ratingRepository ?? RatingRepository();

  final FacilityRepository _facilityRepository;
  final TournamentRepository _tournamentRepository;
  final QueueRepository _queueRepository;
  final RatingRepository _ratingRepository;

  /// Max rows any tool call may return. Keeps every read bounded regardless
  /// of how large `facilities`/`tournaments` grow.
  static const int maxResults = 25;

  /// Facilities currently free (`status == free`), i.e. "empty tables".
  Future<List<FacilityToolResult>> getEmptyTables() {
    return getFacilitiesByStatus(FacilityStatus.free);
  }

  /// Facilities matching an arbitrary [status] (`free` | `occupied` |
  /// `queued`), each enriched with its live queue length.
  Future<List<FacilityToolResult>> getFacilitiesByStatus(String status) async {
    final facilities = await _facilityRepository.getFacilitiesByStatus(
      status,
      limit: maxResults,
    );

    // Enrich each facility with its queue length concurrently — the per-row
    // reads are independent, so fan them out (still ≤ maxResults) rather than
    // paying one sequential round-trip each.
    final queueLengths = await Future.wait(
      facilities.map((f) => _queueRepository.getQueueLength(f.facilityId)),
    );

    return [
      for (var i = 0; i < facilities.length; i++)
        FacilityToolResult(
          facilityId: facilities[i].facilityId,
          name: facilities[i].name,
          sportId: facilities[i].sportId,
          status: facilities[i].status,
          queueLength: queueLengths[i],
        ),
    ];
  }

  /// Tournaments whose `scheduledAt` falls within the device-local calendar
  /// day of [now] (defaults to [DateTime.now]).
  Future<List<TournamentToolResult>> getTournamentsToday({
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));

    final tournaments = await _tournamentRepository.getTournamentsInWindow(
      start,
      end,
      limit: maxResults,
    );

    // Fan out the participant-count reads (independent, still ≤ maxResults)
    // instead of one sequential round-trip per tournament.
    final participantCounts = await Future.wait(
      tournaments.map(
        (t) => _tournamentRepository.getParticipantCount(t.tournamentId),
      ),
    );

    return [
      for (var i = 0; i < tournaments.length; i++)
        TournamentToolResult(
          tournamentId: tournaments[i].tournamentId,
          name: tournaments[i].name,
          sportId: tournaments[i].sportId,
          status: tournaments[i].status,
          scheduledAt: tournaments[i].scheduledAt,
          participantCount: participantCounts[i],
          maxParticipants: tournaments[i].maxParticipants,
        ),
    ];
  }

  /// Where [uid] currently sits in a facility queue, if anywhere.
  Future<QueuePositionToolResult?> getUserQueuePosition(String uid) async {
    final entry = await _queueRepository.getUserQueueEntry(uid);
    if (entry == null) return null;

    final facility = await _facilityRepository.getFacility(entry.facilityId);
    return QueuePositionToolResult(
      facilityId: entry.facilityId,
      facilityName: facility?.name ?? entry.facilityId,
      position: entry.position,
    );
  }

  /// [uid]'s ELO and campus rank for [sportId].
  Future<EloRankToolResult?> getUserEloAndRank({
    required String uid,
    required String sportId,
  }) async {
    final rating = await _ratingRepository.getUserRating(uid, sportId);
    if (rating == null) return null;

    // Rank is a nice-to-have on top of the ELO the user actually asked about,
    // and it is the only part of this tool that needs a composite index. Don't
    // let a missing index (or any other rank-query failure) take down the
    // whole chat turn — [EloRankToolResult.rank] is already nullable.
    int? rank;
    try {
      rank = await _ratingRepository.getUserRank(
        sportId: sportId,
        elo: rating.elo,
      );
    } catch (e) {
      debugPrint(
        '[ArenaAssistant] rank lookup failed, continuing without it: $e',
      );
      rank = null;
    }

    return EloRankToolResult(
      sportId: sportId,
      elo: rating.elo,
      rank: rank,
      matchesPlayed: rating.matchesPlayed,
    );
  }

  /// Static explainer — no repository call. Kept here (rather than inline in
  /// the intent matcher) so both the LLM system prompt and the rule-based
  /// fallback can share exactly the same explanation text.
  String explainHowEloWorks() {
    return 'CampusArena ELO starts every player at 1200. After each confirmed '
        'match, the winner gains points and the loser loses points based on '
        'the ELO difference between the two players (beating a higher-rated '
        'opponent earns more than beating a lower-rated one). The K-factor '
        '(how much a single match can move your rating) is 32 for your '
        'first 10 matches in a sport, then drops to 16 once you are '
        'established. Ratings are tracked separately per sport (Ping Pong, '
        'Foosball). Ratings can also lazily decay after long inactivity.';
  }
}
