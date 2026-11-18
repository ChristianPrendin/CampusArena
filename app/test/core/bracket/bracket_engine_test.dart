import 'package:campus_arena/core/bracket/bracket_engine.dart';
import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/models/tournament_model.dart';
import 'package:flutter_test/flutter_test.dart';

TournamentParticipantModel _p(
  String uid,
  int seed, {
  bool eliminated = false,
}) => TournamentParticipantModel(uid: uid, seed: seed, eliminated: eliminated);

/// Seed-compacted participants `u1..uN` with seeds `1..N`.
List<TournamentParticipantModel> _seeded(int n) => [
  for (var i = 1; i <= n; i++) _p('u$i', i),
];

MatchModel _match(
  String id,
  List<String> players, {
  String state = MatchStates.confirmed,
  String? winner,
  String? round,
}) => MatchModel(
  matchId: id,
  facilityId: 'f1',
  sportId: SportIds.pingPong,
  mode: 'singles',
  playerUids: players,
  state: state,
  result: winner == null
      ? null
      : GenericMatchResult(winnerIds: [winner], score: const {}),
  tournamentRound: round,
  startedAt: DateTime(2026),
);

int _byeCount(BracketTree tree) {
  final first = tree.slots[tree.rounds.first] ?? const [];
  var count = 0;
  for (final slot in first) {
    if (slot.a.isBye) count++;
    if (slot.b.isBye) count++;
  }
  return count;
}

void main() {
  group('roundKeysForSize', () {
    test('canonical keys per bracket size', () {
      expect(roundKeysForSize(2), ['final']);
      expect(roundKeysForSize(4), ['semifinal', 'final']);
      expect(roundKeysForSize(8), ['quarterfinal', 'semifinal', 'final']);
      expect(roundKeysForSize(16), [
        'round_of_16',
        'quarterfinal',
        'semifinal',
        'final',
      ]);
      expect(roundKeysForSize(32), [
        'round_of_32',
        'round_of_16',
        'quarterfinal',
        'semifinal',
        'final',
      ]);
    });
  });

  group('build — pairing', () {
    test('8 participants pair 1v8, 5v4, 3v6, 7v2 with no byes', () {
      final tree = build(
        participants: _seeded(8),
        bracket: const {},
        matches: const [],
      );

      expect(tree.rounds, ['quarterfinal', 'semifinal', 'final']);
      final qf = tree.slots['quarterfinal']!;
      expect(qf.length, 4);
      expect([qf[0].a.uid, qf[0].b.uid], ['u1', 'u8']);
      expect([qf[1].a.uid, qf[1].b.uid], ['u5', 'u4']);
      expect([qf[2].a.uid, qf[2].b.uid], ['u3', 'u6']);
      expect([qf[3].a.uid, qf[3].b.uid], ['u7', 'u2']);
      expect(_byeCount(tree), 0);
      // Every first-round slot with two real players is playable.
      expect(qf.every((s) => s.isPlayable), isTrue);
      // Downstream rounds are all TBD, hence not playable.
      expect(tree.slots['semifinal']!.every((s) => !s.isPlayable), isTrue);
      expect(tree.championUid, isNull);
    });

    test('seed 1 and seed 2 land in opposite halves, meeting only in the '
        'final', () {
      final tree = build(
        participants: _seeded(8),
        bracket: const {
          'quarterfinal': ['m1', 'm2', 'm3', 'm4'],
        },
        matches: [
          _match('m1', ['u1', 'u8'], winner: 'u1'),
          _match('m2', ['u5', 'u4'], winner: 'u4'),
          _match('m3', ['u3', 'u6'], winner: 'u3'),
          _match('m4', ['u7', 'u2'], winner: 'u2'),
        ],
      );
      final sf = tree.slots['semifinal']!;
      // u1 (seed 1) and u2 (seed 2) are drawn into different semifinal slots.
      expect([sf[0].a.uid, sf[0].b.uid], ['u1', 'u4']);
      expect([sf[1].a.uid, sf[1].b.uid], ['u3', 'u2']);
    });
  });

  group('build — byes', () {
    test('visual-bye count equals bracketSize − N for 5/6/7', () {
      expect(
        _byeCount(build(participants: _seeded(5), bracket: {}, matches: [])),
        3,
      );
      expect(
        _byeCount(build(participants: _seeded(6), bracket: {}, matches: [])),
        2,
      );
      expect(
        _byeCount(build(participants: _seeded(7), bracket: {}, matches: [])),
        1,
      );
    });

    test('a bye auto-advances the real side into the next round', () {
      final tree = build(
        participants: _seeded(5),
        bracket: const {},
        matches: const [],
      );
      final qf = tree.slots['quarterfinal']!;
      // Slot 0: seed 1 vs (missing seed 8) → bye, u1 advances.
      expect(qf[0].b.isBye, isTrue);
      expect(qf[0].winnerUid, 'u1');
      expect(qf[0].isPlayable, isFalse);
      // Slot 1: seed 5 vs seed 4 → both real, unresolved.
      expect(qf[1].isPlayable, isTrue);
      expect(qf[1].winnerUid, isNull);
      // The bye winner feeds side a of the next round's slot 0.
      expect(tree.slots['semifinal']![0].a.uid, 'u1');
    });
  });

  group('build — winner resolution', () {
    test('winner comes from a confirmed match with the matching pair', () {
      final tree = build(
        participants: _seeded(2),
        bracket: const {
          'final': ['m1'],
        },
        matches: [
          _match('m1', ['u1', 'u2'], winner: 'u1'),
        ],
      );
      final finalSlot = tree.slots['final']!.single;
      expect(finalSlot.matchId, 'm1');
      expect(finalSlot.winnerUid, 'u1');
      expect(tree.championUid, 'u1');
    });

    test('resolves from a match tournamentRound absent from the bracket map', () {
      // recordBracketMatch dropped its write, so bracket[] is empty — the match
      // doc's own tournamentRound must still back and resolve the slot.
      final tree = build(
        participants: _seeded(2),
        bracket: const {},
        matches: [
          _match('m1', ['u1', 'u2'], winner: 'u1', round: 'final'),
        ],
      );
      final finalSlot = tree.slots['final']!.single;
      expect(finalSlot.matchId, 'm1');
      expect(finalSlot.winnerUid, 'u1');
      expect(tree.championUid, 'u1');
    });

    test(
      'a pending (unconfirmed) match backs the slot but leaves it playable',
      () {
        final tree = build(
          participants: _seeded(2),
          bracket: const {
            'final': ['m1'],
          },
          matches: [
            _match('m1', ['u1', 'u2'], state: MatchStates.awaitingConfirmation),
          ],
        );
        final finalSlot = tree.slots['final']!.single;
        expect(finalSlot.matchId, 'm1');
        expect(finalSlot.winnerUid, isNull);
        expect(finalSlot.isPlayable, isTrue);
        expect(tree.championUid, isNull);
      },
    );

    test('forfeit advances the opponent mid-bracket', () {
      // 4-player bracket: SF slot 0 played (u1 beats u4); in SF slot 1 the
      // organizer forfeits u3 (eliminated, no confirmed loss) → u2 advances.
      final participants = [
        _p('u1', 1),
        _p('u2', 2),
        _p('u3', 3, eliminated: true),
        _p('u4', 4),
      ];
      final tree = build(
        participants: participants,
        bracket: const {
          'semifinal': ['m1'],
        },
        matches: [
          _match('m1', ['u1', 'u4'], winner: 'u1'),
        ],
      );
      final sf = tree.slots['semifinal']!;
      expect(sf[0].winnerUid, 'u1');
      expect(sf[1].winnerUid, 'u2'); // u3 forfeited.
      // Both winners feed the final: u1 (side a) vs u2 (side b), now playable.
      final finalSlot = tree.slots['final']!.single;
      expect([finalSlot.a.uid, finalSlot.b.uid], ['u1', 'u2']);
      expect(finalSlot.isPlayable, isTrue);
    });

    test(
      'elimination explained by a confirmed loss is not a second forfeit',
      () {
        // u4 eliminated AND lost the confirmed match — priority 1 resolves it;
        // the forfeit branch must not fire.
        final participants = [
          _p('u1', 1),
          _p('u2', 2),
          _p('u3', 3),
          _p('u4', 4, eliminated: true),
        ];
        final tree = build(
          participants: participants,
          bracket: const {
            'semifinal': ['m1'],
          },
          matches: [
            _match('m1', ['u1', 'u4'], winner: 'u1'),
          ],
        );
        expect(tree.slots['semifinal']![0].winnerUid, 'u1');
      },
    );
  });

  group('build — champion & TBD propagation', () {
    test('champion derived when the final resolves', () {
      final tree = build(
        participants: _seeded(4),
        bracket: const {
          'semifinal': ['m1', 'm2'],
          'final': ['m3'],
        },
        matches: [
          _match('m1', ['u1', 'u4'], winner: 'u1'),
          _match('m2', ['u2', 'u3'], winner: 'u2'),
          _match('m3', ['u1', 'u2'], winner: 'u1'),
        ],
      );
      expect(tree.championUid, 'u1');
    });

    test('an unresolved feeder leaves the next slot TBD (not a bye)', () {
      final tree = build(
        participants: _seeded(4),
        bracket: const {
          'semifinal': ['m1'],
        },
        matches: [
          _match('m1', ['u1', 'u4'], winner: 'u1'),
        ],
      );
      final finalSlot = tree.slots['final']!.single;
      expect(finalSlot.a.uid, 'u1');
      expect(finalSlot.b.uid, isNull);
      expect(finalSlot.b.isBye, isFalse); // TBD, not a bye.
      expect(finalSlot.isPlayable, isFalse);
      expect(tree.championUid, isNull);
    });

    test('playableSlots flattens exactly the checkable slots', () {
      final tree = build(
        participants: _seeded(4),
        bracket: const {},
        matches: const [],
      );
      // Both semifinals are playable; the final is TBD.
      expect(tree.playableSlots.length, 2);
      expect(tree.playableSlots.every((s) => s.round == 'semifinal'), isTrue);
    });
  });
}
