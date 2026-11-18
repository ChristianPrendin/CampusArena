import 'package:campus_arena/core/achievements/achievement_evaluator.dart';
import 'package:campus_arena/models/achievement_def_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The canonical 6 seeded definitions (workaholic at 15, per the seed edit).
const _defs = <AchievementDefModel>[
  AchievementDefModel(
    achievementId: AchievementIds.firstVictory,
    nameKey: 'achievement_first_victory_name',
    descriptionKey: 'achievement_first_victory_desc',
    iconAsset: 'assets/badges/first_victory.png',
    condition: AchievementConditions.firstVictory,
  ),
  AchievementDefModel(
    achievementId: AchievementIds.streak5,
    nameKey: 'achievement_streak_5_name',
    descriptionKey: 'achievement_streak_5_desc',
    iconAsset: 'assets/badges/streak_5.png',
    condition: AchievementConditions.winStreak,
    threshold: 5,
  ),
  AchievementDefModel(
    achievementId: AchievementIds.giantSlayer,
    nameKey: 'achievement_giant_slayer_name',
    descriptionKey: 'achievement_giant_slayer_desc',
    iconAsset: 'assets/badges/giant_slayer.png',
    condition: AchievementConditions.giantSlayer,
    threshold: 200,
  ),
  AchievementDefModel(
    achievementId: AchievementIds.explorer,
    nameKey: 'achievement_explorer_name',
    descriptionKey: 'achievement_explorer_desc',
    iconAsset: 'assets/badges/explorer.png',
    condition: AchievementConditions.explorer,
  ),
  AchievementDefModel(
    achievementId: AchievementIds.tournamentChampion,
    nameKey: 'achievement_tournament_champion_name',
    descriptionKey: 'achievement_tournament_champion_desc',
    iconAsset: 'assets/badges/tournament_champion.png',
    condition: AchievementConditions.tournamentChampion,
  ),
  AchievementDefModel(
    achievementId: AchievementIds.workaholic,
    nameKey: 'achievement_workaholic_name',
    descriptionKey: 'achievement_workaholic_desc',
    iconAsset: 'assets/badges/workaholic.png',
    condition: AchievementConditions.monthlyCount,
    threshold: 15,
  ),
];

ConfirmedMatchRecord _rec({
  bool won = true,
  String sport = 'ping_pong',
  String facility = 'f1',
  required DateTime at,
}) => ConfirmedMatchRecord(
  won: won,
  sportId: sport,
  facilityId: facility,
  playedAt: at,
);

AchievementContext _ctx({
  bool won = true,
  String sport = 'ping_pong',
  String facility = 'f1',
  DateTime? playedAt,
  int ownElo = 1200,
  int oppElo = 1200,
  List<ConfirmedMatchRecord> prior = const [],
  Set<String> allFacilities = const {'f1'},
  Set<String> currentBadges = const {},
}) => AchievementContext(
  playerUid: 'me',
  wonThisMatch: won,
  sportId: sport,
  facilityId: facility,
  playedAt: playedAt ?? DateTime(2026, 7, 9, 12),
  ownEloBefore: ownElo,
  opponentEloBefore: oppElo,
  priorConfirmedMatches: prior,
  allFacilityIds: allFacilities,
  currentBadges: currentBadges,
  defs: _defs,
);

void main() {
  const evaluator = AchievementEvaluator();

  group('first_victory', () {
    test('awarded on the first ranked win (no prior wins)', () {
      final earned = evaluator.evaluate(_ctx(won: true, prior: const []));
      expect(earned, contains(AchievementIds.firstVictory));
    });

    test('not awarded on a loss', () {
      final earned = evaluator.evaluate(_ctx(won: false));
      expect(earned, isNot(contains(AchievementIds.firstVictory)));
    });

    test('not awarded when a prior win exists (even another sport)', () {
      final earned = evaluator.evaluate(
        _ctx(
          prior: [_rec(won: true, sport: 'foosball', at: DateTime(2026, 7, 1))],
        ),
      );
      expect(earned, isNot(contains(AchievementIds.firstVictory)));
    });
  });

  group('win_streak (threshold 5)', () {
    List<ConfirmedMatchRecord> wins(int n) => [
      for (var i = 0; i < n; i++) _rec(won: true, at: DateTime(2026, 7, i + 1)),
    ];

    test('4 prior wins + this win = 5 → awarded (boundary)', () {
      final earned = evaluator.evaluate(_ctx(won: true, prior: wins(4)));
      expect(earned, contains(AchievementIds.streak5));
    });

    test('3 prior wins + this win = 4 → not awarded (boundary)', () {
      final earned = evaluator.evaluate(_ctx(won: true, prior: wins(3)));
      expect(earned, isNot(contains(AchievementIds.streak5)));
    });

    test('a loss inside the run resets the streak', () {
      // W W W L W (this) → only 2 trailing wins.
      final prior = [
        _rec(won: true, at: DateTime(2026, 7, 1)),
        _rec(won: true, at: DateTime(2026, 7, 2)),
        _rec(won: true, at: DateTime(2026, 7, 3)),
        _rec(won: false, at: DateTime(2026, 7, 4)),
        _rec(won: true, at: DateTime(2026, 7, 5)),
      ];
      final earned = evaluator.evaluate(_ctx(won: true, prior: prior));
      expect(earned, isNot(contains(AchievementIds.streak5)));
    });

    test('only same-sport wins count toward the streak', () {
      // 4 foosball wins don't help a ping_pong streak.
      final prior = [
        for (var i = 0; i < 4; i++)
          _rec(won: true, sport: 'foosball', at: DateTime(2026, 7, i + 1)),
      ];
      final earned = evaluator.evaluate(
        _ctx(won: true, sport: 'ping_pong', prior: prior),
      );
      expect(earned, isNot(contains(AchievementIds.streak5)));
    });

    test('not awarded on a loss regardless of prior wins', () {
      final earned = evaluator.evaluate(_ctx(won: false, prior: wins(10)));
      expect(earned, isNot(contains(AchievementIds.streak5)));
    });
  });

  group('giant_slayer (threshold 200)', () {
    test('opponent exactly 200 above → awarded (boundary)', () {
      final earned = evaluator.evaluate(
        _ctx(won: true, ownElo: 1000, oppElo: 1200),
      );
      expect(earned, contains(AchievementIds.giantSlayer));
    });

    test('opponent 199 above → not awarded (boundary)', () {
      final earned = evaluator.evaluate(
        _ctx(won: true, ownElo: 1000, oppElo: 1199),
      );
      expect(earned, isNot(contains(AchievementIds.giantSlayer)));
    });

    test('not awarded when you beat a weaker opponent', () {
      final earned = evaluator.evaluate(
        _ctx(won: true, ownElo: 1500, oppElo: 1200),
      );
      expect(earned, isNot(contains(AchievementIds.giantSlayer)));
    });

    test('not awarded on a loss to a giant', () {
      final earned = evaluator.evaluate(
        _ctx(won: false, ownElo: 1000, oppElo: 1400),
      );
      expect(earned, isNot(contains(AchievementIds.giantSlayer)));
    });
  });

  group('workaholic (monthly_count 15)', () {
    List<ConfirmedMatchRecord> inMonth(int n) => [
      for (var i = 0; i < n; i++)
        _rec(won: i.isEven, at: DateTime(2026, 7, (i % 27) + 1)),
    ];

    test('14 prior this month + this one = 15 → awarded (boundary)', () {
      final earned = evaluator.evaluate(
        _ctx(prior: inMonth(14), playedAt: DateTime(2026, 7, 28)),
      );
      expect(earned, contains(AchievementIds.workaholic));
    });

    test('13 prior this month + this one = 14 → not awarded (boundary)', () {
      final earned = evaluator.evaluate(
        _ctx(prior: inMonth(13), playedAt: DateTime(2026, 7, 28)),
      );
      expect(earned, isNot(contains(AchievementIds.workaholic)));
    });

    test('matches in other months do not count', () {
      final prior = [
        for (var i = 0; i < 20; i++)
          _rec(won: true, at: DateTime(2026, 6, (i % 27) + 1)), // June
      ];
      final earned = evaluator.evaluate(
        _ctx(prior: prior, playedAt: DateTime(2026, 7, 15)),
      );
      expect(earned, isNot(contains(AchievementIds.workaholic)));
    });

    test('counts across sports (it is total games)', () {
      final prior = [
        for (var i = 0; i < 14; i++)
          _rec(
            won: true,
            sport: i.isEven ? 'ping_pong' : 'foosball',
            at: DateTime(2026, 7, (i % 27) + 1),
          ),
      ];
      final earned = evaluator.evaluate(
        _ctx(prior: prior, playedAt: DateTime(2026, 7, 28)),
      );
      expect(earned, contains(AchievementIds.workaholic));
    });
  });

  group('explorer', () {
    test('awarded when this match completes every facility', () {
      final prior = [
        _rec(facility: 'f1', at: DateTime(2026, 7, 1)),
        _rec(facility: 'f2', at: DateTime(2026, 7, 2)),
      ];
      final earned = evaluator.evaluate(
        _ctx(facility: 'f3', prior: prior, allFacilities: {'f1', 'f2', 'f3'}),
      );
      expect(earned, contains(AchievementIds.explorer));
    });

    test('not awarded while a facility is still unvisited (partial)', () {
      final prior = [_rec(facility: 'f1', at: DateTime(2026, 7, 1))];
      final earned = evaluator.evaluate(
        _ctx(facility: 'f2', prior: prior, allFacilities: {'f1', 'f2', 'f3'}),
      );
      expect(earned, isNot(contains(AchievementIds.explorer)));
    });

    test('awarded to the loser too (playing everywhere, not winning)', () {
      final prior = [
        _rec(won: false, facility: 'f1', at: DateTime(2026, 7, 1)),
      ];
      final earned = evaluator.evaluate(
        _ctx(
          won: false,
          facility: 'f2',
          prior: prior,
          allFacilities: {'f1', 'f2'},
        ),
      );
      expect(earned, contains(AchievementIds.explorer));
    });

    test('never awarded when the campus facility set is unknown/empty', () {
      final earned = evaluator.evaluate(
        _ctx(facility: 'f1', allFacilities: const {}),
      );
      expect(earned, isNot(contains(AchievementIds.explorer)));
    });
  });

  group('tournament_champion', () {
    test('never evaluated at match confirm', () {
      final earned = evaluator.evaluate(_ctx(won: true));
      expect(earned, isNot(contains(AchievementIds.tournamentChampion)));
    });
  });

  group('write-once', () {
    test('an already-owned id is never re-emitted', () {
      final earned = evaluator.evaluate(
        _ctx(
          won: true,
          // An unvisited facility keeps explorer from firing, isolating the
          // owned first_victory as the only qualifying condition.
          allFacilities: {'f1', 'f2'},
          currentBadges: {AchievementIds.firstVictory},
        ),
      );
      // first_victory qualifies but is owned → excluded; nothing else fires
      // for a plain 1200-vs-1200 first win.
      expect(earned, isNot(contains(AchievementIds.firstVictory)));
      expect(earned, isEmpty);
    });

    test('owning one badge does not suppress a different newly-earned one', () {
      final earned = evaluator.evaluate(
        _ctx(
          won: true,
          ownElo: 1000,
          oppElo: 1300,
          currentBadges: {AchievementIds.firstVictory},
        ),
      );
      expect(earned, contains(AchievementIds.giantSlayer));
      expect(earned, isNot(contains(AchievementIds.firstVictory)));
    });
  });
}
