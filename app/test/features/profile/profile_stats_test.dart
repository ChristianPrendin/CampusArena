import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/profile/profile_stats.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:flutter_test/flutter_test.dart';

const _uid = 'me';

/// Sequential match factory: [day] orders matches chronologically.
MatchModel _match({
  required String id,
  required int day,
  String sportId = SportIds.pingPong,
  String state = MatchStates.confirmed,
  String mode = 'singles',
  List<String> players = const [_uid, 'opp'],
  bool won = true,
  Map<String, int>? eloBefore,
  Map<String, int>? eloDeltas,
}) => MatchModel(
  matchId: id,
  facilityId: 'f1',
  sportId: sportId,
  mode: mode,
  playerUids: players,
  state: state,
  result: PingPongResult(
    winnerIds: won ? const [_uid] : [players.firstWhere((p) => p != _uid)],
    sets: const [11, 11],
    opponentSets: const [5, 7],
  ),
  eloBefore: eloBefore,
  eloDeltas: eloDeltas,
  startedAt: DateTime(2026, 7, day, 10),
  confirmedAt: DateTime(2026, 7, day, 11),
);

ProfileDerivation _derive(List<MatchModel> matches) =>
    deriveProfileStats(ProfileDerivationInput(uid: _uid, matches: matches));

void main() {
  group('stats', () {
    test('counts games, wins, losses and win rate per sport', () {
      final d = _derive([
        _match(id: 'm1', day: 1, won: true),
        _match(id: 'm2', day: 2, won: false),
        _match(id: 'm3', day: 3, won: true),
        _match(id: 'm4', day: 4, won: true),
        _match(id: 'fb', day: 5, sportId: SportIds.foosball, won: false),
      ]);

      final pp = d.statsFor(SportIds.pingPong);
      expect(pp.games, 4);
      expect(pp.wins, 3);
      expect(pp.losses, 1);
      expect(pp.winRate, 0.75);

      final fb = d.statsFor(SportIds.foosball);
      expect(fb.games, 1);
      expect(fb.wins, 0);
      expect(fb.losses, 1);
      expect(fb.winRate, 0);
    });

    test('a sport with no matches falls back to empty stats', () {
      final d = _derive(const []);
      expect(d.statsFor(SportIds.pingPong), SportStats.empty);
      expect(d.trendFor(SportIds.pingPong), isEmpty);
      expect(d.funStatsFor(SportIds.pingPong), SportFunStats.empty);
    });

    test('doubles matches count toward stats via winnerIds', () {
      final d = _derive([
        _match(
          id: 'd1',
          day: 1,
          mode: 'doubles',
          players: const [_uid, 'mate', 'x', 'y'],
          won: true,
        ),
      ]);
      expect(d.statsFor(SportIds.pingPong).games, 1);
      expect(d.statsFor(SportIds.pingPong).wins, 1);
    });

    test('non-confirmed states are excluded from stats entirely', () {
      final d = _derive([
        _match(id: 'm1', day: 1, won: true),
        _match(id: 'm2', day: 2, state: MatchStates.disputed),
        _match(id: 'm3', day: 3, state: MatchStates.unconfirmed),
        _match(id: 'm4', day: 4, state: MatchStates.abandoned),
        _match(id: 'm5', day: 5, state: MatchStates.awaitingConfirmation),
      ]);
      expect(d.statsFor(SportIds.pingPong).games, 1);
    });
  });

  group('streaks', () {
    test('current streak resets on a loss; best keeps the max run', () {
      // Chronological: W W W L W W — passed newest-first to prove the
      // derivation sorts by confirmedAt itself.
      final matches = [
        _match(id: 'm6', day: 6, won: true),
        _match(id: 'm5', day: 5, won: true),
        _match(id: 'm4', day: 4, won: false),
        _match(id: 'm3', day: 3, won: true),
        _match(id: 'm2', day: 2, won: true),
        _match(id: 'm1', day: 1, won: true),
      ];
      final stats = _derive(matches).statsFor(SportIds.pingPong);
      expect(stats.currentStreak, 2);
      expect(stats.bestStreak, 3);
    });

    test('a loss as the latest match zeroes the current streak', () {
      final stats = _derive([
        _match(id: 'm1', day: 1, won: true),
        _match(id: 'm2', day: 2, won: false),
      ]).statsFor(SportIds.pingPong);
      expect(stats.currentStreak, 0);
      expect(stats.bestStreak, 1);
    });
  });

  group('trend', () {
    test('starts at the first match\'s eloBefore baseline, then eloBefore + '
        'delta per match, ordered by confirmedAt', () {
      final trend = _derive([
        _match(
          id: 'm2',
          day: 2,
          won: false,
          eloBefore: const {_uid: 1216, 'opp': 1200},
          eloDeltas: const {_uid: -12, 'opp': 12},
        ),
        _match(
          id: 'm1',
          day: 1,
          won: true,
          eloBefore: const {_uid: 1200, 'opp': 1200},
          eloDeltas: const {_uid: 16, 'opp': -16},
        ),
      ]).trendFor(SportIds.pingPong);

      expect(trend.map((p) => p.elo), [1200, 1216, 1204]);
      // Baseline sits at the first rated match's start, the real points at
      // their confirmations.
      expect(trend[0].confirmedAt, DateTime(2026, 7, 1, 10));
      expect(trend[1].confirmedAt, DateTime(2026, 7, 1, 11));
    });

    test(
      'a single rated match yields baseline + one point (a drawable line)',
      () {
        final trend = _derive([
          _match(
            id: 'm1',
            day: 1,
            won: true,
            eloBefore: const {_uid: 1200, 'opp': 1200},
            eloDeltas: const {_uid: 16, 'opp': -16},
          ),
        ]).trendFor(SportIds.pingPong);

        expect(trend.map((p) => p.elo), [1200, 1216]);
      },
    );

    test('excludes pairId-keyed (doubles) matches and unrated matches', () {
      final trend = _derive([
        _match(
          id: 'singles',
          day: 1,
          won: true,
          eloBefore: const {_uid: 1200, 'opp': 1200},
          eloDeltas: const {_uid: 16, 'opp': -16},
        ),
        // Doubles: elo maps keyed by pairId, not by uid.
        _match(
          id: 'doubles',
          day: 2,
          mode: 'doubles',
          players: const [_uid, 'mate', 'x', 'y'],
          won: true,
          eloBefore: const {'mate_me': 1200, 'x_y': 1200},
          eloDeltas: const {'mate_me': 16, 'x_y': -16},
        ),
        // Confirmed before the ELO engine was wired: no maps at all.
        _match(id: 'legacy', day: 3, won: true),
      ]).trendFor(SportIds.pingPong);

      expect(trend.map((p) => p.elo), [1200, 1216]);
    });
  });

  group('fun stats gate', () {
    test('2 head-to-head matches surface nothing; 3 surface the labels', () {
      final twoMatchups = _derive([
        _match(id: 'm1', day: 1, won: false),
        _match(id: 'm2', day: 2, won: false),
      ]).funStatsFor(SportIds.pingPong);
      expect(twoMatchups.blackBeast, isNull);
      expect(twoMatchups.favoriteVictim, isNull);

      final threeMatchups = _derive([
        _match(id: 'm1', day: 1, won: false),
        _match(id: 'm2', day: 2, won: false),
        _match(id: 'm3', day: 3, won: true),
      ]).funStatsFor(SportIds.pingPong);
      expect(threeMatchups.blackBeast?.opponentUid, 'opp');
      expect(threeMatchups.blackBeast?.losses, 2);
      expect(threeMatchups.favoriteVictim?.opponentUid, 'opp');
      expect(threeMatchups.favoriteVictim?.wins, 1);
    });

    test('picks the worst beast and best victim across opponents', () {
      MatchModel vs(String id, int day, String opp, {required bool won}) =>
          _match(id: id, day: day, players: [_uid, opp], won: won);

      final fun = _derive([
        // beast: 1W–3L. victim: 3W–0L. Both pass the gate.
        vs('b1', 1, 'beast', won: false),
        vs('b2', 2, 'beast', won: false),
        vs('b3', 3, 'beast', won: true),
        vs('b4', 4, 'beast', won: false),
        vs('v1', 5, 'victim', won: true),
        vs('v2', 6, 'victim', won: true),
        vs('v3', 7, 'victim', won: true),
      ]).funStatsFor(SportIds.pingPong);

      expect(fun.blackBeast?.opponentUid, 'beast');
      expect(fun.blackBeast?.wins, 1);
      expect(fun.blackBeast?.losses, 3);
      expect(fun.favoriteVictim?.opponentUid, 'victim');
      expect(fun.favoriteVictim?.wins, 3);
      expect(fun.favoriteVictim?.losses, 0);
    });

    test('an all-win matchup never becomes the Black Beast', () {
      final fun = _derive([
        _match(id: 'm1', day: 1, won: true),
        _match(id: 'm2', day: 2, won: true),
        _match(id: 'm3', day: 3, won: true),
      ]).funStatsFor(SportIds.pingPong);
      expect(fun.blackBeast, isNull);
      expect(fun.favoriteVictim?.opponentUid, 'opp');
    });

    test('doubles matches never feed the head-to-head tallies', () {
      final fun = _derive([
        for (var day = 1; day <= 3; day++)
          _match(
            id: 'd$day',
            day: day,
            mode: 'doubles',
            players: const [_uid, 'mate', 'opp', 'y'],
            won: false,
          ),
      ]).funStatsFor(SportIds.pingPong);
      expect(fun.blackBeast, isNull);
      expect(fun.favoriteVictim, isNull);
    });
  });

  group('deriveTeamStats', () {
    const mate = 'mate';
    final pair = [_uid, mate]..sort();
    final pairId = pair.join('_');
    final oppPairId = ['opp', 'y']..sort();

    // A doubles match for our pair; [won] controls whether our two members are
    // the winnerIds, and the ELO maps are keyed by pairId as the confirm path
    // stores them.
    MatchModel doubles({
      required String id,
      required int day,
      String sportId = SportIds.pingPong,
      bool won = true,
      int eloBefore = 1200,
      int delta = 12,
    }) => MatchModel(
      matchId: id,
      facilityId: 'f1',
      sportId: sportId,
      mode: 'doubles',
      playerUids: [...pair, 'opp', 'y'],
      team1PairId: pairId,
      team2PairId: oppPairId.join('_'),
      state: MatchStates.confirmed,
      result: PingPongResult(
        winnerIds: won ? pair : oppPairId,
        sets: const [11, 11],
        opponentSets: const [5, 7],
      ),
      eloBefore: {pairId: eloBefore},
      eloDeltas: {pairId: won ? delta : -delta},
      startedAt: DateTime(2026, 7, day, 10),
      confirmedAt: DateTime(2026, 7, day, 11),
    );

    ProfileDerivation derive(List<MatchModel> matches) => deriveTeamStats(
      TeamDerivationInput(pairId: pairId, memberUids: pair, matches: matches),
    );

    test('a pair wins only when both members are in winnerIds', () {
      final d = derive([
        doubles(id: 'w1', day: 1, won: true),
        doubles(id: 'l1', day: 2, won: false),
        doubles(id: 'w2', day: 3, won: true),
      ]);
      final pp = d.statsFor(SportIds.pingPong);
      expect(pp.games, 3);
      expect(pp.wins, 2);
      expect(pp.losses, 1);
      expect(pp.currentStreak, 1);
      expect(pp.bestStreak, 1);
    });

    test('the team trend reads the pairId-keyed ELO maps', () {
      final d = derive([
        doubles(id: 'w1', day: 1, won: true, eloBefore: 1200, delta: 12),
        doubles(id: 'w2', day: 2, won: true, eloBefore: 1212, delta: 8),
      ]);
      final trend = d.trendFor(SportIds.pingPong);
      // Baseline (1200) + one point per rated match.
      expect(trend.map((t) => t.elo), [1200, 1212, 1220]);
    });

    test('a match where the members are split does not count as a win', () {
      // Only one member in winnerIds — not a pair win.
      final split = MatchModel(
        matchId: 's1',
        facilityId: 'f1',
        sportId: SportIds.pingPong,
        mode: 'doubles',
        playerUids: [...pair, 'opp', 'y'],
        team1PairId: pairId,
        team2PairId: oppPairId.join('_'),
        state: MatchStates.confirmed,
        result: PingPongResult(
          winnerIds: [_uid, 'opp'],
          sets: const [11, 11],
          opponentSets: const [5, 7],
        ),
        eloBefore: {pairId: 1200},
        eloDeltas: {pairId: -10},
        startedAt: DateTime(2026, 7, 1, 10),
        confirmedAt: DateTime(2026, 7, 1, 11),
      );
      final pp = derive([split]).statsFor(SportIds.pingPong);
      expect(pp.games, 1);
      expect(pp.wins, 0);
      expect(pp.losses, 1);
    });
  });
}
