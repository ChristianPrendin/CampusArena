import 'package:campus_arena/core/elo/elo_calculator.dart';
import 'package:campus_arena/core/scoring/foosball_scoring_strategy.dart';
import 'package:campus_arena/core/scoring/scoring_strategy.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const strategy = FoosballScoringStrategy();

  FoosballResult result({
    List<String> winnerIds = const ['w'],
    required int goals,
    required int opponentGoals,
  }) => FoosballResult(
    winnerIds: winnerIds,
    goals: goals,
    opponentGoals: opponentGoals,
  );

  group('validateResult', () {
    test('accepts a decisive game', () {
      expect(
        strategy.validateResult(result(goals: 10, opponentGoals: 7)).isValid,
        isTrue,
      );
    });

    test('rejects a tie', () {
      expect(
        strategy.validateResult(result(goals: 5, opponentGoals: 5)).error,
        ScoringError.tiedGame,
      );
    });

    test('rejects a negative goal count', () {
      expect(
        strategy.validateResult(result(goals: -1, opponentGoals: 5)).error,
        ScoringError.negativeScore,
      );
    });

    test('rejects a non-winner-first result', () {
      expect(
        strategy.validateResult(result(goals: 3, opponentGoals: 7)).error,
        ScoringError.winnerMismatch,
      );
    });

    test('rejects an empty winnerIds', () {
      expect(
        strategy
            .validateResult(
              result(winnerIds: const [], goals: 10, opponentGoals: 7),
            )
            .error,
        ScoringError.winnerMismatch,
      );
    });
  });

  group('composeResult', () {
    test('orients a "you win" score winner-first with your uids', () {
      final r = strategy.composeResult(
        yourGoals: 10,
        opponentGoals: 7,
        yourUids: ['you'],
        opponentUids: ['opp'],
      );
      expect(r!.winnerIds, ['you']);
      expect(r.goals, 10);
      expect(r.opponentGoals, 7);
      expect(strategy.validateResult(r).isValid, isTrue);
    });

    test('orients a "you lose" score winner-first with opponent uids', () {
      final r = strategy.composeResult(
        yourGoals: 3,
        opponentGoals: 8,
        yourUids: ['you'],
        opponentUids: ['opp'],
      );
      expect(r!.winnerIds, ['opp']);
      expect(r.goals, 8);
      expect(r.opponentGoals, 3);
    });

    test('returns null on a tie', () {
      final r = strategy.composeResult(
        yourGoals: 5,
        opponentGoals: 5,
        yourUids: ['you'],
        opponentUids: ['opp'],
      );
      expect(r, isNull);
    });
  });

  group('computeMatchOutcome', () {
    final game = result(winnerIds: const ['you'], goals: 10, opponentGoals: 7);

    test('is a win from the winner side', () {
      final o = strategy.computeMatchOutcome(game, perspectiveUid: 'you');
      expect(o.outcome, EloOutcome.win);
      expect(o.winnerIds, ['you']);
    });

    test('is a loss from the opponent side', () {
      expect(
        strategy.computeMatchOutcome(game, perspectiveUid: 'opp').outcome,
        EloOutcome.loss,
      );
    });
  });
}
