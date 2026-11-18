// Pure profile-stats derivation — no Flutter, no Firestore. Everything here
// is top-level and side-effect-free so `deriveProfileStats` can run through
// `compute()` in a real Isolate (the project's designated rubric Isolate,
// `brain/project_description.md` §4.3).

import 'package:equatable/equatable.dart';

import '../../core/constants.dart';
import '../../models/match_model.dart';

/// Minimum confirmed head-to-head singles matches against one specific
/// opponent before the Black Beast / Favorite Victim labels may surface
/// (Decision Log rule).
const int kFunStatMinMatchups = 3;

/// Message passed into the isolate: the raw match window plus whose
/// perspective to derive from. Matches are passed unfiltered — the derivation
/// applies its own per-metric filters (stats: confirmed; trend: rated for
/// [uid]; fun stats: confirmed singles).
class ProfileDerivationInput {
  const ProfileDerivationInput({required this.uid, required this.matches});

  final String uid;
  final List<MatchModel> matches;
}

/// Isolate message for a *team* (pair) derivation: the deterministic [pairId]
/// (the trend + ELO-map key for doubles matches) and its two [memberUids] (a
/// pair won a match iff both appear in `winnerIds`). Matches are the pair's
/// doubles matches, passed unfiltered — the derivation applies its own filters.
class TeamDerivationInput {
  const TeamDerivationInput({
    required this.pairId,
    required this.memberUids,
    required this.matches,
  });

  final String pairId;
  final List<String> memberUids;
  final List<MatchModel> matches;
}

/// One point of the personal ELO trend: the rating right after a confirmed
/// match (`eloBefore[uid] + eloDeltas[uid]`) at that match's confirmation.
/// The series' first point is instead the baseline — the rating *going into*
/// the first rated match, at its start.
class TrendPoint extends Equatable {
  const TrendPoint({required this.confirmedAt, required this.elo});

  final DateTime confirmedAt;
  final int elo;

  @override
  List<Object?> get props => [confirmedAt, elo];
}

/// Aggregate record for one sport over the confirmed matches in the window.
class SportStats extends Equatable {
  const SportStats({
    this.games = 0,
    this.wins = 0,
    this.losses = 0,
    this.winRate = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
  });

  static const SportStats empty = SportStats();

  final int games;
  final int wins;
  final int losses;

  /// wins / games in [0, 1]; 0 when no games.
  final double winRate;

  /// Consecutive wins ending at the most recent confirmed match; 0 if it was
  /// a loss.
  final int currentStreak;

  /// Longest consecutive-win run within the window.
  final int bestStreak;

  @override
  List<Object?> get props => [
    games,
    wins,
    losses,
    winRate,
    currentStreak,
    bestStreak,
  ];
}

/// Head-to-head record against one opponent, from the profile owner's
/// perspective.
class OpponentTally extends Equatable {
  const OpponentTally({
    required this.opponentUid,
    required this.wins,
    required this.losses,
  });

  final String opponentUid;
  final int wins;
  final int losses;

  int get matchups => wins + losses;

  @override
  List<Object?> get props => [opponentUid, wins, losses];
}

/// The gated fun-stat labels for one sport. Either side is null when no
/// opponent passes the [kFunStatMinMatchups] gate (or the tally would be 0).
class SportFunStats extends Equatable {
  const SportFunStats({this.blackBeast, this.favoriteVictim});

  static const SportFunStats empty = SportFunStats();

  /// The opponent who beat the profile owner most.
  final OpponentTally? blackBeast;

  /// The opponent the profile owner beat most.
  final OpponentTally? favoriteVictim;

  @override
  List<Object?> get props => [blackBeast, favoriteVictim];
}

/// Everything the profile screen derives from the match window, keyed by
/// sportId. Sports with no matches are simply absent — the `*For` accessors
/// fall back to empty values.
class ProfileDerivation extends Equatable {
  const ProfileDerivation({
    this.statsBySport = const {},
    this.trendBySport = const {},
    this.funStatsBySport = const {},
  });

  static const ProfileDerivation empty = ProfileDerivation();

  final Map<String, SportStats> statsBySport;
  final Map<String, List<TrendPoint>> trendBySport;
  final Map<String, SportFunStats> funStatsBySport;

  SportStats statsFor(String sportId) =>
      statsBySport[sportId] ?? SportStats.empty;

  List<TrendPoint> trendFor(String sportId) =>
      trendBySport[sportId] ?? const [];

  SportFunStats funStatsFor(String sportId) =>
      funStatsBySport[sportId] ?? SportFunStats.empty;

  @override
  List<Object?> get props => [statsBySport, trendBySport, funStatsBySport];
}

/// Derives per-sport stats, ELO trend series, and fun-stat labels for
/// [ProfileDerivationInput.uid]. Top-level and pure by contract: it is the
/// `compute()` entry point.
ProfileDerivation deriveProfileStats(ProfileDerivationInput input) {
  final bySport = <String, List<MatchModel>>{};
  for (final match in input.matches) {
    if (match.state != MatchStates.confirmed) continue;
    bySport.putIfAbsent(match.sportId, () => []).add(match);
  }

  final statsBySport = <String, SportStats>{};
  final trendBySport = <String, List<TrendPoint>>{};
  final funStatsBySport = <String, SportFunStats>{};

  for (final entry in bySport.entries) {
    // Chronological order drives streaks and the trend series alike.
    final confirmed = [...entry.value]
      ..sort(
        (a, b) => (a.confirmedAt ?? a.startedAt).compareTo(
          b.confirmedAt ?? b.startedAt,
        ),
      );
    statsBySport[entry.key] = _sportStats(
      confirmed,
      (m) => _wonBy(m, input.uid),
    );
    trendBySport[entry.key] = _trendSeries(confirmed, input.uid);
    funStatsBySport[entry.key] = _funStats(confirmed, input.uid);
  }

  return ProfileDerivation(
    statsBySport: statsBySport,
    trendBySport: trendBySport,
    funStatsBySport: funStatsBySport,
  );
}

/// Per-sport stats + ELO trend for a *team* (pair). The pair is its own rated
/// entity: it won a match iff both members are in `winnerIds`, and its trend
/// reads the pairId-keyed `eloBefore`/`eloDeltas`. Fun stats (a per-opponent
/// singles concept) don't apply, so [ProfileDerivation.funStatsBySport] is empty.
ProfileDerivation deriveTeamStats(TeamDerivationInput input) {
  final bySport = <String, List<MatchModel>>{};
  for (final match in input.matches) {
    if (match.state != MatchStates.confirmed) continue;
    bySport.putIfAbsent(match.sportId, () => []).add(match);
  }

  final statsBySport = <String, SportStats>{};
  final trendBySport = <String, List<TrendPoint>>{};
  bool won(MatchModel m) =>
      input.memberUids.isNotEmpty &&
      input.memberUids.every((u) => m.result?.winnerIds.contains(u) ?? false);

  for (final entry in bySport.entries) {
    final confirmed = [...entry.value]
      ..sort(
        (a, b) => (a.confirmedAt ?? a.startedAt).compareTo(
          b.confirmedAt ?? b.startedAt,
        ),
      );
    statsBySport[entry.key] = _sportStats(confirmed, won);
    trendBySport[entry.key] = _trendSeries(confirmed, input.pairId);
  }

  return ProfileDerivation(
    statsBySport: statsBySport,
    trendBySport: trendBySport,
  );
}

bool _wonBy(MatchModel match, String uid) =>
    match.result?.winnerIds.contains(uid) ?? false;

/// [confirmed] must be confirmed matches of one sport, chronological. [won]
/// decides whether the profiled entity (a user or a pair) won each match.
SportStats _sportStats(
  List<MatchModel> confirmed,
  bool Function(MatchModel) won,
) {
  var wins = 0;
  var run = 0;
  var best = 0;
  for (final match in confirmed) {
    if (won(match)) {
      wins++;
      run++;
      if (run > best) best = run;
    } else {
      run = 0;
    }
  }
  final games = confirmed.length;
  return SportStats(
    games: games,
    wins: wins,
    losses: games - wins,
    winRate: games == 0 ? 0 : wins / games,
    currentStreak: run,
    bestStreak: best,
  );
}

/// ELO trend for the entity keyed by [entityKey] (a uid for singles, a pairId
/// for a team): only matches whose `eloBefore`/`eloDeltas` maps contain that
/// key. A singles pass therefore drops doubles matches (keyed by pairId) by
/// construction, and vice-versa.
///
/// The series is prefixed with the baseline rating going into the first rated
/// match (`eloBefore`, i.e. the 1200 seed today) so the chart starts where the
/// entity actually started — and a single rated match already draws a line.
List<TrendPoint> _trendSeries(List<MatchModel> confirmed, String entityKey) {
  final rated = [
    for (final match in confirmed)
      if (match.eloBefore?.containsKey(entityKey) == true &&
          match.eloDeltas?.containsKey(entityKey) == true)
        match,
  ];
  if (rated.isEmpty) return const [];
  final first = rated.first;
  return [
    TrendPoint(confirmedAt: first.startedAt, elo: first.eloBefore![entityKey]!),
    for (final match in rated)
      TrendPoint(
        confirmedAt: match.confirmedAt ?? match.startedAt,
        elo: match.eloBefore![entityKey]! + match.eloDeltas![entityKey]!,
      ),
  ];
}

/// Head-to-head tallies over confirmed singles matches, then the
/// [kFunStatMinMatchups] gate. Ties resolve to the lexicographically first
/// opponent uid so the result is deterministic.
SportFunStats _funStats(List<MatchModel> confirmed, String uid) {
  final wins = <String, int>{};
  final losses = <String, int>{};
  for (final match in confirmed) {
    if (match.mode != 'singles') continue;
    if (!match.playerUids.contains(uid)) continue;
    final others = match.playerUids.where((p) => p != uid);
    if (others.length != 1) continue;
    final opponent = others.first;
    if (_wonBy(match, uid)) {
      wins[opponent] = (wins[opponent] ?? 0) + 1;
    } else {
      losses[opponent] = (losses[opponent] ?? 0) + 1;
    }
  }

  final opponents = {...wins.keys, ...losses.keys}.toList()..sort();
  OpponentTally? blackBeast;
  OpponentTally? favoriteVictim;
  for (final opponent in opponents) {
    final tally = OpponentTally(
      opponentUid: opponent,
      wins: wins[opponent] ?? 0,
      losses: losses[opponent] ?? 0,
    );
    if (tally.matchups < kFunStatMinMatchups) continue;
    if (tally.losses > 0 && tally.losses > (blackBeast?.losses ?? 0)) {
      blackBeast = tally;
    }
    if (tally.wins > 0 && tally.wins > (favoriteVictim?.wins ?? 0)) {
      favoriteVictim = tally;
    }
  }
  return SportFunStats(blackBeast: blackBeast, favoriteVictim: favoriteVictim);
}
