import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_arena/models/match_model.dart';

void main() {
  group('MatchResult subtypes tests', () {
    test('PingPongResult toMap/fromMap', () {
      final res = PingPongResult(
        winnerIds: const ['uid1'],
        sets: const [11, 9, 11],
        opponentSets: const [7, 11, 5],
      );

      final map = res.toMap();
      expect(map['winnerIds'], ['uid1']);
      expect(map['score']['sets'], [11, 9, 11]);

      final parsed = PingPongResult.fromMap(map);
      expect(parsed, res);
    });

    test('FoosballResult toMap/fromMap', () {
      final res = FoosballResult(
        winnerIds: const ['uid1'],
        goals: 10,
        opponentGoals: 7,
      );

      final map = res.toMap();
      expect(map['winnerIds'], ['uid1']);
      expect(map['score']['goals'], 10);

      final parsed = FoosballResult.fromMap(map);
      expect(parsed, res);
    });

    test('GenericMatchResult toMap/fromMap', () {
      final res = GenericMatchResult(
        winnerIds: const ['uid1', 'uid2'],
        score: const {'points': 21},
      );

      final map = res.toMap();
      expect(map['winnerIds'], ['uid1', 'uid2']);
      expect(map['score']['points'], 21);

      final parsed = GenericMatchResult.fromMap(map);
      expect(parsed, res);
    });
  });

  group('MatchModel tests', () {
    final now = DateTime.now();
    final nowTimestamp = Timestamp.fromDate(now);

    final rawPingPongMap = {
      'facilityId': 'fac_1',
      'sportId': 'ping_pong',
      'mode': 'singles',
      'playerUids': ['uid1', 'uid2'],
      'state': 'awaitingConfirmation',
      'submittedByUid': 'uid1',
      'result': {
        'winnerIds': ['uid1'],
        'score': {
          'sets': [11, 9, 11],
          'opponentSets': [7, 11, 5],
        },
      },
      'eloBefore': {'uid1': 1200, 'uid2': 1200},
      'eloDeltas': {'uid1': 16, 'uid2': -16},
      'startedAt': nowTimestamp,
      'confirmedAt': nowTimestamp,
    };

    test('should parse correctly fromMap (Ping Pong)', () {
      final match = MatchModel.fromMap(rawPingPongMap, 'match_1');

      expect(match.matchId, 'match_1');
      expect(match.facilityId, 'fac_1');
      expect(match.sportId, 'ping_pong');
      expect(match.mode, 'singles');
      expect(match.playerUids, ['uid1', 'uid2']);
      expect(match.state, 'awaitingConfirmation');
      expect(match.submittedByUid, 'uid1');
      expect(match.result, isA<PingPongResult>());
      final result = match.result as PingPongResult;
      expect(result.winnerIds, ['uid1']);
      expect(result.sets, [11, 9, 11]);
      expect(match.eloBefore, {'uid1': 1200, 'uid2': 1200});
      expect(match.eloDeltas, {'uid1': 16, 'uid2': -16});
      expect(match.startedAt, now);
      expect(match.confirmedAt, now);
    });

    test('should fallback to defaults on empty fromMap', () {
      final match = MatchModel.fromMap(const {}, 'match_1');

      expect(match.matchId, 'match_1');
      expect(match.facilityId, '');
      expect(match.sportId, '');
      expect(match.mode, 'singles');
      expect(match.playerUids, isEmpty);
      expect(match.state, 'occupied');
      expect(match.result, isNull);
    });

    test('should serialize correctly toMap (Foosball)', () {
      final match = MatchModel(
        matchId: 'match_1',
        facilityId: 'fac_1',
        sportId: 'foosball',
        mode: 'singles',
        playerUids: const ['uid1', 'uid2'],
        state: 'confirmed',
        submittedByUid: 'uid1',
        result: FoosballResult(
          winnerIds: const ['uid1'],
          goals: 10,
          opponentGoals: 8,
        ),
        eloBefore: const {'uid1': 1200, 'uid2': 1200},
        eloDeltas: const {'uid1': 16, 'uid2': -16},
        startedAt: now,
        confirmedAt: now,
      );

      final map = match.toMap();

      expect(map['sportId'], 'foosball');
      expect(map['result']['score']['goals'], 10);
      expect(map['startedAt'], isA<Timestamp>());
      expect((map['startedAt'] as Timestamp).toDate(), now);
      expect(map['confirmedAt'], isA<Timestamp>());
      expect((map['confirmedAt'] as Timestamp).toDate(), now);
    });

    test('should support copyWith', () {
      final match = MatchModel(
        matchId: 'match_1',
        facilityId: 'fac_1',
        sportId: 'ping_pong',
        mode: 'singles',
        playerUids: const ['uid1', 'uid2'],
        state: 'occupied',
        startedAt: now,
      );

      final updated = match.copyWith(state: 'confirmed');
      expect(updated.state, 'confirmed');
      expect(updated.matchId, 'match_1');
    });
  });
}
