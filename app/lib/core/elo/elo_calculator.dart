// Pure Dart ELO engine — no Flutter, no Firestore. Spec:
// `brain/project_description.md` §0 (Decision Log) + §3.1.
//
// The engine is entity-agnostic: a "side" is any rated entity's plain values
// (elo, matchesPlayed) read off a `RatingModel`. Singles pass user ratings,
// doubles pass pair ratings — a pair is its own rated entity with its own
// ELO and provisional counter, never an average of its members' singles
// ratings. Persistence belongs to the caller (the confirmResult transaction).

import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../constants.dart';

/// Deterministic pair identity from member UIDs: sorted, underscore-joined,
/// so the same players always resolve to one rated entity regardless of
/// argument order (see `brain/project_description.md` §0 — a pair is its own
/// rated entity). Squad-size-agnostic: works for any member count.
///
/// This is the single canonical implementation; `RatingRepository.pairId`
/// delegates here. Do not introduce a second convention.
String pairIdFromUids(List<String> memberUids) {
  final sorted = [...memberUids]..sort();
  return sorted.join('_');
}

/// Match outcome from side A's perspective.
enum EloOutcome {
  win(1.0),
  tie(0.5),
  loss(0.0);

  const EloOutcome(this.score);

  /// Actual score `S` in the ELO update formula.
  final double score;

  /// The same outcome seen from the other side.
  EloOutcome get inverted => switch (this) {
    win => loss,
    tie => tie,
    loss => win,
  };
}

/// A computed rating exchange between two rated entities.
///
/// Deltas are already rounded and signed; `newEloX = eloX + deltaX`. Under
/// equal K-factors the exchange is zero-sum; when one side is provisional
/// and the other established the deltas differ by design (each side moves
/// by its own K).
class EloUpdate extends Equatable {
  const EloUpdate({
    required this.deltaA,
    required this.deltaB,
    required this.newEloA,
    required this.newEloB,
  });

  final int deltaA;
  final int deltaB;
  final int newEloA;
  final int newEloB;

  @override
  List<Object?> get props => [deltaA, deltaB, newEloA, newEloB];
}

/// Stateless ELO arithmetic with the decision-log defaults: 1200 baseline,
/// K=32 while `matchesPlayed < 10` (this K switch *is* the provisional
/// phase — no separate flag), K=16 after, lazy inactivity decay after 30
/// idle days eroding only gains above the baseline.
class EloCalculator {
  const EloCalculator({
    this.baselineElo = kInitialElo,
    this.provisionalMatchCount = 10,
    this.provisionalK = 32,
    this.establishedK = 16,
    this.decayGraceDays = 30,
    this.decayPointsPerDay = 1,
  });

  /// Default tournament multiplier μ (see task board Phase 4 🟡). The actual
  /// value applied to a match comes from `TournamentModel.eloMultiplier`;
  /// this is only the seed default.
  static const double defaultTournamentMultiplier = 1.5;

  final int baselineElo;
  final int provisionalMatchCount;
  final int provisionalK;
  final int establishedK;
  final int decayGraceDays;

  /// Points eroded per idle day beyond [decayGraceDays]. Engine default, not
  /// a decision-log value — the spec fixes only "gradual" and the baseline.
  final int decayPointsPerDay;

  /// Standard ELO expected score: `1 / (1 + 10^((Rb - Ra) / 400))`.
  double expectedScore({required int elo, required int opponentElo}) =>
      1 / (1 + math.pow(10, (opponentElo - elo) / 400));

  /// [matchesPlayed] is the entity's count *before* the match being rated,
  /// so the 10th match itself is still played at K=32.
  int kFactor(int matchesPlayed) =>
      matchesPlayed < provisionalMatchCount ? provisionalK : establishedK;

  /// Rates one match between two entities: `R' = R + K·μ·(S − E)` per side,
  /// each side with its own K. [outcomeA] is from side A's perspective;
  /// [multiplier] is μ (1.0 for standard matches, the tournament's
  /// `eloMultiplier` for tournament matches).
  EloUpdate computeUpdate({
    required int eloA,
    required int matchesPlayedA,
    required int eloB,
    required int matchesPlayedB,
    required EloOutcome outcomeA,
    double multiplier = 1.0,
  }) {
    final expectedA = expectedScore(elo: eloA, opponentElo: eloB);
    final deltaA =
        (kFactor(matchesPlayedA) * multiplier * (outcomeA.score - expectedA))
            .round();
    final deltaB =
        (kFactor(matchesPlayedB) *
                multiplier *
                (outcomeA.inverted.score - (1 - expectedA)))
            .round();
    return EloUpdate(
      deltaA: deltaA,
      deltaB: deltaB,
      newEloA: eloA + deltaA,
      newEloB: eloB + deltaB,
    );
  }

  /// Effective ELO after lazy inactivity decay, computed at read time from
  /// [lastMatchAt] — never persisted (see `brain/firestore_schema.md`:
  /// `lastMatchAt` is the only stored input). Decay starts after
  /// [decayGraceDays] idle days and erodes only gains above [baselineElo];
  /// ratings at or below the baseline are untouched.
  int decayedElo({
    required int elo,
    required DateTime lastMatchAt,
    DateTime? now,
  }) {
    if (elo <= baselineElo) return elo;
    final idleDays = (now ?? DateTime.now()).difference(lastMatchAt).inDays;
    if (idleDays <= decayGraceDays) return elo;
    final decayed = elo - (idleDays - decayGraceDays) * decayPointsPerDay;
    return math.max(baselineElo, decayed);
  }
}
