// Maps a `sportId` to its `ScoringStrategy`. The single place that knows the
// sport→strategy wiring; callers stay sport-agnostic. Adding a sport = add one
// case here plus the new strategy class — no interface change (§2.3).

import '../constants.dart';
import 'foosball_scoring_strategy.dart';
import 'ping_pong_scoring_strategy.dart';
import 'scoring_strategy.dart';

/// Thrown when no [ScoringStrategy] is registered for a sportId — either an
/// unknown id or one not yet enabled (e.g. `padel`, a Phase 6 stretch).
class UnsupportedSportException implements Exception {
  const UnsupportedSportException(this.sportId);

  final String sportId;

  @override
  String toString() =>
      'UnsupportedSportException: no ScoringStrategy for sportId "$sportId"';
}

class ScoringStrategyFactory {
  const ScoringStrategyFactory();

  /// Returns the strategy for [sportId], or throws [UnsupportedSportException].
  ScoringStrategy forSport(String sportId) {
    switch (sportId) {
      case SportIds.pingPong:
        return const PingPongScoringStrategy();
      case SportIds.foosball:
        return const FoosballScoringStrategy();
      default:
        throw UnsupportedSportException(sportId);
    }
  }
}
