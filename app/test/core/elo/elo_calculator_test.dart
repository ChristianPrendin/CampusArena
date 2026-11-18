import 'package:campus_arena/core/elo/elo_calculator.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = EloCalculator();

  group('pairIdFromUids', () {
    test('sorts member UIDs and joins with underscore', () {
      expect(pairIdFromUids(['u2', 'u1']), 'u1_u2');
      expect(pairIdFromUids(['u1', 'u2']), 'u1_u2');
    });

    test('is deterministic and order-independent', () {
      expect(pairIdFromUids(['b', 'a']), pairIdFromUids(['a', 'b']));
      expect(pairIdFromUids(['b', 'a']), pairIdFromUids(['b', 'a']));
    });

    test('does not mutate the input list', () {
      final uids = ['u2', 'u1'];
      pairIdFromUids(uids);
      expect(uids, ['u2', 'u1']);
    });

    test('is squad-size-agnostic', () {
      expect(pairIdFromUids(['u3', 'u1', 'u2']), 'u1_u2_u3');
    });

    test('matches the RatingRepository convention (single canonical impl)', () {
      for (final uids in [
        ['u2', 'u1'],
        ['alice', 'bob'],
        ['zz', 'aa', 'mm'],
      ]) {
        expect(pairIdFromUids(uids), RatingRepository.pairId(uids));
      }
    });
  });

  group('expectedScore', () {
    test('equal ratings give 0.5', () {
      expect(calculator.expectedScore(elo: 1200, opponentElo: 1200), 0.5);
    });

    test('a 400-point advantage gives ~0.909', () {
      expect(
        calculator.expectedScore(elo: 1600, opponentElo: 1200),
        closeTo(0.909, 0.001),
      );
    });

    test('the two sides always sum to 1', () {
      for (final (a, b) in [(1200, 1200), (1200, 1350), (1000, 1800)]) {
        expect(
          calculator.expectedScore(elo: a, opponentElo: b) +
              calculator.expectedScore(elo: b, opponentElo: a),
          closeTo(1, 1e-12),
        );
      }
    });
  });

  group('provisional K switch', () {
    test('K=32 while matchesPlayed < 10, K=16 from the 10th onward', () {
      expect(calculator.kFactor(0), 32);
      expect(calculator.kFactor(9), 32);
      expect(calculator.kFactor(10), 16);
      expect(calculator.kFactor(11), 16);
    });

    test('the 10th match itself is still rated at K=32', () {
      // matchesPlayed is the pre-match count: 9 played means this is the 10th.
      final update = calculator.computeUpdate(
        eloA: 1200,
        matchesPlayedA: 9,
        eloB: 1200,
        matchesPlayedB: 9,
        outcomeA: EloOutcome.win,
      );
      expect(update.deltaA, 16); // 32 * 0.5
    });

    test('each side moves by its own K when only one is provisional', () {
      final update = calculator.computeUpdate(
        eloA: 1200,
        matchesPlayedA: 0,
        eloB: 1200,
        matchesPlayedB: 50,
        outcomeA: EloOutcome.win,
      );
      expect(update.deltaA, 16); // provisional K=32
      expect(update.deltaB, -8); // established K=16
    });
  });

  group('computeUpdate', () {
    test('equal established players exchange 8 points on a win', () {
      final update = calculator.computeUpdate(
        eloA: 1200,
        matchesPlayedA: 10,
        eloB: 1200,
        matchesPlayedB: 10,
        outcomeA: EloOutcome.win,
      );
      expect(
        update,
        const EloUpdate(deltaA: 8, deltaB: -8, newEloA: 1208, newEloB: 1192),
      );
    });

    test('an upset win pays more than an expected win', () {
      final upset = calculator.computeUpdate(
        eloA: 1200,
        matchesPlayedA: 0,
        eloB: 1400,
        matchesPlayedB: 0,
        outcomeA: EloOutcome.win,
      );
      final expected = calculator.computeUpdate(
        eloA: 1400,
        matchesPlayedA: 0,
        eloB: 1200,
        matchesPlayedB: 0,
        outcomeA: EloOutcome.win,
      );
      expect(upset.deltaA, 24);
      expect(expected.deltaA, 8);
    });

    test('is zero-sum under equal K across rating gaps', () {
      for (final gap in [0, 100, 200, 300, 400]) {
        for (final outcome in EloOutcome.values) {
          final update = calculator.computeUpdate(
            eloA: 1200,
            matchesPlayedA: 0,
            eloB: 1200 + gap,
            matchesPlayedB: 0,
            outcomeA: outcome,
          );
          expect(update.deltaB, -update.deltaA);
        }
      }
    });
  });

  group('ties', () {
    test('a tie between equal ratings moves nobody', () {
      final update = calculator.computeUpdate(
        eloA: 1200,
        matchesPlayedA: 0,
        eloB: 1200,
        matchesPlayedB: 0,
        outcomeA: EloOutcome.tie,
      );
      expect(
        update,
        const EloUpdate(deltaA: 0, deltaB: 0, newEloA: 1200, newEloB: 1200),
      );
    });

    test('a tie pays the underdog and costs the favourite', () {
      final update = calculator.computeUpdate(
        eloA: 1200,
        matchesPlayedA: 0,
        eloB: 1400,
        matchesPlayedB: 0,
        outcomeA: EloOutcome.tie,
      );
      expect(update.deltaA, 8);
      expect(update.deltaB, -8);
    });
  });

  group('tournament multiplier', () {
    test('defaults to 1.0 (a standard match is unscaled)', () {
      final update = calculator.computeUpdate(
        eloA: 1200,
        matchesPlayedA: 0,
        eloB: 1200,
        matchesPlayedB: 0,
        outcomeA: EloOutcome.win,
      );
      expect(update.deltaA, 16);
    });

    test('μ=1.5 scales the exchange by 1.5', () {
      final update = calculator.computeUpdate(
        eloA: 1200,
        matchesPlayedA: 0,
        eloB: 1200,
        matchesPlayedB: 0,
        outcomeA: EloOutcome.win,
        multiplier: EloCalculator.defaultTournamentMultiplier,
      );
      expect(update.deltaA, 24); // 32 * 1.5 * 0.5
      expect(update.deltaB, -24);
    });

    test('μ is a free parameter, not hardcoded to 1.5', () {
      final update = calculator.computeUpdate(
        eloA: 1200,
        matchesPlayedA: 10,
        eloB: 1200,
        matchesPlayedB: 10,
        outcomeA: EloOutcome.win,
        multiplier: 2.0,
      );
      expect(update.deltaA, 16); // 16 * 2.0 * 0.5
    });

    test('the seed default is 1.5', () {
      expect(EloCalculator.defaultTournamentMultiplier, 1.5);
    });
  });

  group('doubles (pair as its own rated entity)', () {
    test('a fresh pair is provisional regardless of its members\' history', () {
      // Pair rating: 1200, 0 matches — even if both members are veterans on
      // their singles ratings, the pair entity's own counter drives K.
      final update = calculator.computeUpdate(
        eloA: 1200,
        matchesPlayedA: 0,
        eloB: 1350,
        matchesPlayedB: 12,
        outcomeA: EloOutcome.win,
      );
      expect(update.deltaA, 23); // K=32 on the pair's own provisional phase
      expect(update.deltaB, -11); // K=16 for the established pair
    });

    test(
      'the update is computed from the pair values, not member averages',
      () {
        // Two pairs whose hypothetical member averages differ wildly produce
        // the same exchange as long as the pair entities' values are equal.
        final update = calculator.computeUpdate(
          eloA: 1200,
          matchesPlayedA: 3,
          eloB: 1200,
          matchesPlayedB: 3,
          outcomeA: EloOutcome.win,
        );
        expect(update.deltaA, 16);
        expect(update.newEloA, 1216);
        expect(update.newEloB, 1184);
      },
    );
  });

  group('lazy inactivity decay', () {
    final now = DateTime.utc(2026, 7, 4);

    test('no decay within the 30-day grace period', () {
      expect(
        calculator.decayedElo(
          elo: 1400,
          lastMatchAt: now.subtract(const Duration(days: 30)),
          now: now,
        ),
        1400,
      );
    });

    test('erodes 1 point per idle day past the grace period', () {
      expect(
        calculator.decayedElo(
          elo: 1400,
          lastMatchAt: now.subtract(const Duration(days: 31)),
          now: now,
        ),
        1399,
      );
      expect(
        calculator.decayedElo(
          elo: 1400,
          lastMatchAt: now.subtract(const Duration(days: 45)),
          now: now,
        ),
        1385,
      );
    });

    test('partial days do not count', () {
      expect(
        calculator.decayedElo(
          elo: 1400,
          lastMatchAt: now.subtract(const Duration(days: 30, hours: 23)),
          now: now,
        ),
        1400,
      );
    });

    test('never drops below the 1200 baseline', () {
      expect(
        calculator.decayedElo(
          elo: 1210,
          lastMatchAt: now.subtract(const Duration(days: 60)),
          now: now,
        ),
        1200,
      );
      expect(
        calculator.decayedElo(
          elo: 1500,
          lastMatchAt: now.subtract(const Duration(days: 400)),
          now: now,
        ),
        1200,
      );
    });

    test('ratings at or below the baseline are untouched', () {
      final aYearAgo = now.subtract(const Duration(days: 365));
      expect(
        calculator.decayedElo(elo: 1200, lastMatchAt: aYearAgo, now: now),
        1200,
      );
      expect(
        calculator.decayedElo(elo: 1100, lastMatchAt: aYearAgo, now: now),
        1100,
      );
    });

    test('a future lastMatchAt never inflates or decays', () {
      expect(
        calculator.decayedElo(
          elo: 1400,
          lastMatchAt: now.add(const Duration(days: 5)),
          now: now,
        ),
        1400,
      );
    });

    test('is a pure read-time transform: deterministic, nothing persisted', () {
      final lastMatchAt = now.subtract(const Duration(days: 40));
      final first = calculator.decayedElo(
        elo: 1400,
        lastMatchAt: lastMatchAt,
        now: now,
      );
      final second = calculator.decayedElo(
        elo: 1400,
        lastMatchAt: lastMatchAt,
        now: now,
      );
      // Repeated reads at the same instant agree; the stored value (the
      // input) is what every read starts from, so decay never compounds.
      expect(first, 1390);
      expect(second, first);
      // A later read decays further from the same stored inputs.
      expect(
        calculator.decayedElo(
          elo: 1400,
          lastMatchAt: lastMatchAt,
          now: now.add(const Duration(days: 10)),
        ),
        1380,
      );
    });

    test('grace period and rate are configurable', () {
      const fast = EloCalculator(decayGraceDays: 10, decayPointsPerDay: 5);
      expect(
        fast.decayedElo(
          elo: 1300,
          lastMatchAt: now.subtract(const Duration(days: 12)),
          now: now,
        ),
        1290,
      );
    });
  });
}
