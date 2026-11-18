import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/core/scoring/foosball_scoring_strategy.dart';
import 'package:campus_arena/core/scoring/ping_pong_scoring_strategy.dart';
import 'package:campus_arena/core/scoring/scoring_strategy_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const factory = ScoringStrategyFactory();

  test('dispatches ping_pong to the set-based strategy', () {
    expect(factory.forSport(SportIds.pingPong), isA<PingPongScoringStrategy>());
  });

  test('dispatches foosball to the goal-based strategy', () {
    expect(factory.forSport(SportIds.foosball), isA<FoosballScoringStrategy>());
  });

  test('throws on an unknown sportId', () {
    expect(
      () => factory.forSport('chess'),
      throwsA(isA<UnsupportedSportException>()),
    );
  });

  test('throws on a known-but-unenabled sport (padel)', () {
    expect(
      () => factory.forSport(SportIds.padel),
      throwsA(isA<UnsupportedSportException>()),
    );
  });
}
