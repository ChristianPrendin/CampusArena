import 'package:equatable/equatable.dart';

import '../../../models/achievement_def_model.dart';
import '../../../models/match_model.dart';

/// The phase of the result flow, derived from the streamed match doc (plus the
/// transient action phases the cubit emits while a write is in flight). One
/// deep-linkable flow renders the phase-appropriate view — never three orphan
/// screens.
enum ResultPhase {
  /// Streaming the match doc for the first time.
  loading,

  /// Match `occupied` — this device enters the score.
  scoreEntry,

  /// A submit write is in flight.
  submitting,

  /// `awaitingConfirmation`, submitted by me — waiting on the opponent.
  awaitingOpponent,

  /// `awaitingConfirmation`, submitted by the opponent — I confirm or dispute.
  review,

  /// A confirm write is in flight.
  confirming,

  /// A dispute write is in flight.
  disputing,

  /// `confirmed` — the ELO summary.
  summary,

  /// `disputed` / `unconfirmed` / `abandoned` — a terminal non-confirmed close.
  closed,

  /// A load or action write failed; [ResultState.errorKind] says which.
  error,
}

/// Which terminal close was reached, so the closed view picks distinct copy.
enum ResultClosedKind { disputed, unconfirmed, abandoned }

/// What failed, so `retry()` re-derives the right phase and the view explains.
enum ResultErrorKind { load, submit, confirm, dispute }

/// The rating change for the current user's side, shown on the summary screen.
class EloSummary extends Equatable {
  const EloSummary({
    required this.isWin,
    required this.oldElo,
    required this.newElo,
    required this.delta,
    required this.isSingles,
    this.rank,
  });

  final bool isWin;
  final int oldElo;
  final int newElo;
  final int delta;

  /// Rank is a user-rating concept, so the "new campus rank" pill is shown for
  /// singles only; null for doubles or while it is still loading.
  final int? rank;

  /// Singles → the pill applies; doubles → it is omitted.
  final bool isSingles;

  EloSummary copyWith({int? rank}) => EloSummary(
    isWin: isWin,
    oldElo: oldElo,
    newElo: newElo,
    delta: delta,
    isSingles: isSingles,
    rank: rank ?? this.rank,
  );

  @override
  List<Object?> get props => [isWin, oldElo, newElo, delta, rank, isSingles];
}

class ResultState extends Equatable {
  const ResultState({
    this.phase = ResultPhase.loading,
    this.match,
    this.players = const {},
    this.summary,
    this.closedKind,
    this.errorKind,
    this.newBadges = const [],
  });

  final ResultPhase phase;

  /// The streamed match doc; null until the first emission.
  final MatchModel? match;

  /// uid → best-effort display name for the review/summary cards.
  final Map<String, String> players;

  /// Computed once the match is `confirmed`.
  final EloSummary? summary;

  final ResultClosedKind? closedKind;
  final ResultErrorKind? errorKind;

  /// Badges this confirming user just unlocked, resolved to their definitions
  /// for the client-local unlock reveal on the summary. Empty when confirming
  /// earned nothing (or when this device didn't run the confirm write).
  final List<AchievementDefModel> newBadges;

  ResultState copyWith({
    ResultPhase? phase,
    MatchModel? match,
    Map<String, String>? players,
    EloSummary? summary,
    ResultClosedKind? closedKind,
    ResultErrorKind? errorKind,
    List<AchievementDefModel>? newBadges,
  }) {
    return ResultState(
      phase: phase ?? this.phase,
      match: match ?? this.match,
      players: players ?? this.players,
      summary: summary ?? this.summary,
      closedKind: closedKind ?? this.closedKind,
      errorKind: errorKind ?? this.errorKind,
      newBadges: newBadges ?? this.newBadges,
    );
  }

  @override
  List<Object?> get props => [
    phase,
    match,
    players,
    summary,
    closedKind,
    errorKind,
    newBadges,
  ];
}
