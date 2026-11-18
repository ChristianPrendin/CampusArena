import 'package:campus_arena/core/elo/elo_calculator.dart';
import 'package:campus_arena/core/scoring/ping_pong_scoring_strategy.dart';
import 'package:campus_arena/core/scoring/scoring_strategy.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const strategy = PingPongScoringStrategy();

  PingPongResult result({
    List<String> winnerIds = const ['w'],
    required List<int> sets,
    required List<int> opponentSets,
  }) => PingPongResult(
    winnerIds: winnerIds,
    sets: sets,
    opponentSets: opponentSets,
  );

  group('validateResult', () {
    test('accepts a legal best-of-3', () {
      final v = strategy.validateResult(
        result(sets: [11, 9, 11], opponentSets: [7, 11, 5]),
      );
      expect(v.isValid, isTrue);
    });

    test('accepts a deuce set (12-10)', () {
      final v = strategy.validateResult(result(sets: [12], opponentSets: [10]));
      expect(v.isValid, isTrue);
    });

    test('accepts a 21-point game', () {
      final v = strategy.validateResult(result(sets: [21], opponentSets: [19]));
      expect(v.isValid, isTrue);
    });

    test('rejects a set won by a single point (11-10)', () {
      final v = strategy.validateResult(result(sets: [11], opponentSets: [10]));
      expect(v.error, ScoringError.setNotDecisive);
    });

    test('rejects a set whose winner is below 11 (5-3)', () {
      final v = strategy.validateResult(result(sets: [5], opponentSets: [3]));
      expect(v.error, ScoringError.setNotDecisive);
    });

    test('rejects a tied set', () {
      final v = strategy.validateResult(
        result(sets: [11, 11, 11], opponentSets: [8, 11, 6]),
      );
      expect(v.error, ScoringError.tiedSet);
    });

    test('accepts straight-sets wins (even set counts: 2-0, 3-1)', () {
      final bestOf3 = strategy.validateResult(
        result(sets: [11, 11], opponentSets: [8, 6]),
      );
      expect(bestOf3.isValid, isTrue);

      final bestOf5 = strategy.validateResult(
        result(sets: [11, 9, 11, 11], opponentSets: [7, 11, 5, 8]),
      );
      expect(bestOf5.isValid, isTrue);
    });

    test('rejects empty and length-mismatched results', () {
      expect(
        strategy.validateResult(result(sets: [], opponentSets: [])).error,
        ScoringError.malformedResult,
      );
      expect(
        strategy.validateResult(result(sets: [11], opponentSets: [8, 6])).error,
        ScoringError.malformedResult,
      );
    });

    test('rejects a non-winner-first result (sets side lost more sets)', () {
      final v = strategy.validateResult(
        result(sets: [8, 9, 7], opponentSets: [11, 11, 11]),
      );
      expect(v.error, ScoringError.winnerMismatch);
    });

    test('rejects an empty winnerIds', () {
      final v = strategy.validateResult(
        result(winnerIds: const [], sets: [11], opponentSets: [8]),
      );
      expect(v.error, ScoringError.winnerMismatch);
    });
  });

  group('composeResult', () {
    test('orients a "you win" score winner-first with your uids', () {
      final r = strategy.composeResult(
        yourPoints: [11, 9, 11],
        opponentPoints: [7, 11, 5],
        yourUids: ['you'],
        opponentUids: ['opp'],
      );
      expect(r, isNotNull);
      expect(r!.winnerIds, ['you']);
      expect(r.sets, [11, 9, 11]);
      expect(r.opponentSets, [7, 11, 5]);
      expect(strategy.validateResult(r).isValid, isTrue);
    });

    test('orients a "you lose" score winner-first with opponent uids', () {
      final r = strategy.composeResult(
        yourPoints: [7, 11, 5],
        opponentPoints: [11, 9, 11],
        yourUids: ['you'],
        opponentUids: ['opp'],
      );
      expect(r!.winnerIds, ['opp']);
      expect(r.sets, [11, 9, 11]); // winner's points
      expect(r.opponentSets, [7, 11, 5]);
    });

    test('returns null when the set tally is level', () {
      final r = strategy.composeResult(
        yourPoints: [11, 5],
        opponentPoints: [5, 11],
        yourUids: ['you'],
        opponentUids: ['opp'],
      );
      expect(r, isNull);
    });
  });

  group('computeMatchOutcome', () {
    final winning = result(
      winnerIds: const ['you'],
      sets: [11, 9, 11],
      opponentSets: [7, 11, 5],
    );

    test('is a win from the winner side', () {
      final o = strategy.computeMatchOutcome(winning, perspectiveUid: 'you');
      expect(o.outcome, EloOutcome.win);
      expect(o.winnerIds, ['you']);
    });

    test('is a loss from the opponent side', () {
      final o = strategy.computeMatchOutcome(winning, perspectiveUid: 'opp');
      expect(o.outcome, EloOutcome.loss);
    });

    test('resolves doubles by team membership', () {
      final doubles = result(
        winnerIds: const ['a', 'b'],
        sets: [11],
        opponentSets: [8],
      );
      expect(
        strategy.computeMatchOutcome(doubles, perspectiveUid: 'a').outcome,
        EloOutcome.win,
      );
      expect(
        strategy.computeMatchOutcome(doubles, perspectiveUid: 'c').outcome,
        EloOutcome.loss,
      );
    });
  });
}
