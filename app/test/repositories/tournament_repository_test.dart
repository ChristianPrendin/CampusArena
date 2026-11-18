import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/models/tournament_model.dart';
import 'package:campus_arena/repositories/tournament_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

final _deadline = DateTime(2026, 7, 5, 17);

TournamentModel _tournament({
  String id = '',
  String sportId = SportIds.pingPong,
  String status = 'registering',
  int maxParticipants = 8,
  DateTime? registrationDeadline,
  Map<String, List<String>> bracket = const {},
}) => TournamentModel(
  tournamentId: id,
  name: 'Spring Cup',
  sportId: sportId,
  facilityId: 'f1',
  organizerId: 'org1',
  maxParticipants: maxParticipants,
  status: status,
  bracket: bracket,
  eloMultiplier: 1.5,
  registrationDeadline: registrationDeadline ?? _deadline,
  scheduledAt: DateTime(2026, 7, 6),
  createdAt: DateTime(2026, 6, 30),
);

/// A moment before the default registration deadline (2026-07-05).
final DateTime _beforeDeadline = DateTime(2026, 7, 4, 12);

void main() {
  late FakeFirebaseFirestore firestore;
  late TournamentRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = TournamentRepository(firestore: firestore);
  });

  test('createTournament auto-generates id and round-trips', () async {
    final id = await repository.createTournament(_tournament());

    final loaded = await repository.getTournament(id);
    expect(loaded, isNotNull);
    expect(loaded!.tournamentId, id);
    expect(loaded.name, 'Spring Cup');
    expect(loaded.eloMultiplier, 1.5);
  });

  test('watchTournaments filters correctly', () async {
    await repository.createTournament(
      _tournament(sportId: SportIds.pingPong, status: 'registering'),
    );
    await repository.createTournament(
      _tournament(sportId: SportIds.foosball, status: 'registering'),
    );
    await repository.createTournament(
      _tournament(sportId: SportIds.pingPong, status: 'completed'),
    );

    final registeringPingPong = await repository
        .watchTournaments(sportId: SportIds.pingPong, statuses: ['registering'])
        .first;

    expect(registeringPingPong.length, 1);
    expect(registeringPingPong.single.sportId, SportIds.pingPong);
    expect(registeringPingPong.single.status, 'registering');
  });

  test('updateBracket persists the round → matchIds map', () async {
    final id = await repository.createTournament(_tournament());

    await repository.updateBracket(id, {
      'quarterfinal': ['m1', 'm2'],
    });

    final loaded = await repository.getTournament(id);
    expect(loaded!.bracket['quarterfinal'], ['m1', 'm2']);
  });

  test('updateTournament applies a partial update', () async {
    final id = await repository.createTournament(_tournament());

    await repository.updateTournament(id, {
      'status': 'completed',
      'winnerUid': 'u1',
    });

    final loaded = await repository.getTournament(id);
    expect(loaded!.status, 'completed');
    expect(loaded.winnerUid, 'u1');
  });

  group('participants subcollection', () {
    test('addParticipant then watch emits ordered by seed', () async {
      final id = await repository.createTournament(_tournament());

      await repository.addParticipant(
        id,
        const TournamentParticipantModel(uid: 'u2', seed: 2, eliminated: false),
      );
      await repository.addParticipant(
        id,
        const TournamentParticipantModel(uid: 'u1', seed: 1, eliminated: false),
      );

      final participants = await repository.watchParticipants(id).first;
      expect(participants.map((p) => p.uid), ['u1', 'u2']);
    });

    test('updateParticipant marks elimination', () async {
      final id = await repository.createTournament(_tournament());
      await repository.addParticipant(
        id,
        const TournamentParticipantModel(uid: 'u1', seed: 1, eliminated: false),
      );

      await repository.updateParticipant(id, 'u1', {'eliminated': true});

      final participants = await repository.watchParticipants(id).first;
      expect(participants.single.eliminated, isTrue);
    });
  });

  group('getTournamentsInWindow', () {
    test('returns only tournaments scheduled inside [start, end)', () async {
      await repository.createTournament(
        _tournament(),
      ); // scheduledAt: 2026-07-06
      final start = DateTime(2026, 7, 6);
      final end = DateTime(2026, 7, 7);

      final inWindow = await repository.getTournamentsInWindow(start, end);

      expect(inWindow, hasLength(1));
      expect(inWindow.single.name, 'Spring Cup');
    });

    test('excludes tournaments scheduled outside the window', () async {
      await repository.createTournament(_tournament()); // 2026-07-06

      final outside = await repository.getTournamentsInWindow(
        DateTime(2026, 7, 7),
        DateTime(2026, 7, 8),
      );

      expect(outside, isEmpty);
    });

    test('is bounded by limit', () async {
      for (var i = 0; i < 3; i++) {
        await repository.createTournament(_tournament());
      }

      final inWindow = await repository.getTournamentsInWindow(
        DateTime(2026, 7, 6),
        DateTime(2026, 7, 7),
        limit: 2,
      );

      expect(inWindow.length, 2);
    });
  });

  group('getParticipantCount', () {
    test('counts participants via a bounded aggregation query', () async {
      final id = await repository.createTournament(_tournament());
      await repository.addParticipant(
        id,
        const TournamentParticipantModel(uid: 'u1', seed: 1, eliminated: false),
      );
      await repository.addParticipant(
        id,
        const TournamentParticipantModel(uid: 'u2', seed: 2, eliminated: false),
      );

      expect(await repository.getParticipantCount(id), 2);
    });

    test('returns 0 for a tournament with no participants', () async {
      final id = await repository.createTournament(_tournament());

      expect(await repository.getParticipantCount(id), 0);
    });
  });

  group('seedIfDue', () {
    Future<void> addParticipants(String id, Map<String, int> seeds) async {
      for (final entry in seeds.entries) {
        await repository.addParticipant(
          id,
          TournamentParticipantModel(
            uid: entry.key,
            seed: entry.value,
            eliminated: false,
          ),
        );
      }
    }

    test('before the deadline and not full: no-op', () async {
      final id = await repository.createTournament(_tournament());
      await addParticipants(id, {'a': 1, 'b': 2});

      await repository.seedIfDue(
        id,
        now: _deadline.subtract(const Duration(hours: 1)),
      );

      final loaded = await repository.getTournament(id);
      expect(loaded!.status, TournamentStatus.registering);
    });

    test('at the deadline: compacts seeds by (seed, uid) and seeds', () async {
      final id = await repository.createTournament(_tournament());
      // Sparse, out-of-order seeds plus a tie to prove the (seed, uid) order.
      await addParticipants(id, {'zoe': 7, 'ann': 3, 'bob': 3});

      await repository.seedIfDue(id, now: _deadline);

      final loaded = await repository.getTournament(id);
      expect(loaded!.status, TournamentStatus.seeded);
      // Reconciled to the actual roster (addParticipant doesn't touch the count,
      // so this proves seeding backfills it).
      expect(loaded.participantCount, 3);
      final participants = await repository.watchParticipants(id).first;
      // seed 3 (ann) → 1, seed 3 (bob) → 2 (uid tiebreak), seed 7 (zoe) → 3.
      expect(
        {for (final p in participants) p.uid: p.seed},
        {'ann': 1, 'bob': 2, 'zoe': 3},
      );
    });

    test('full bracket seeds before the deadline', () async {
      final id = await repository.createTournament(
        _tournament(maxParticipants: 2),
      );
      await addParticipants(id, {'a': 1, 'b': 2});

      await repository.seedIfDue(
        id,
        now: _deadline.subtract(const Duration(days: 1)),
      );

      final loaded = await repository.getTournament(id);
      expect(loaded!.status, TournamentStatus.seeded);
    });

    test('fewer than two participants at the deadline cancels', () async {
      final id = await repository.createTournament(_tournament());
      await addParticipants(id, {'a': 1});

      await repository.seedIfDue(id, now: _deadline);

      final loaded = await repository.getTournament(id);
      expect(loaded!.status, TournamentStatus.cancelled);
    });

    test('is a no-op once past registering', () async {
      final id = await repository.createTournament(
        _tournament(status: TournamentStatus.active),
      );
      await addParticipants(id, {'a': 1, 'b': 2});

      await repository.seedIfDue(id, now: _deadline);

      final loaded = await repository.getTournament(id);
      expect(loaded!.status, TournamentStatus.active);
    });
  });

  group('completeIfDecided', () {
    test('active tournament completes with the winner', () async {
      final id = await repository.createTournament(
        _tournament(status: TournamentStatus.active),
      );

      await repository.completeIfDecided(id, 'champ');

      final loaded = await repository.getTournament(id);
      expect(loaded!.status, TournamentStatus.completed);
      expect(loaded.winnerUid, 'champ');
    });

    test('seeded tournament (all-bye degenerate) completes', () async {
      final id = await repository.createTournament(
        _tournament(status: TournamentStatus.seeded),
      );

      await repository.completeIfDecided(id, 'champ');

      final loaded = await repository.getTournament(id);
      expect(loaded!.status, TournamentStatus.completed);
    });

    test('guard blocks completion when still registering', () async {
      final id = await repository.createTournament(_tournament());

      await repository.completeIfDecided(id, 'champ');

      final loaded = await repository.getTournament(id);
      expect(loaded!.status, TournamentStatus.registering);
      expect(loaded.winnerUid, isNull);
    });

    Future<Map<String, dynamic>?> userBadges(String uid) async {
      final snap = await firestore.collection('users').doc(uid).get();
      return snap.data()?['badges'] as Map<String, dynamic>?;
    }

    test('awards the champion the tournament_champion badge', () async {
      final id = await repository.createTournament(
        _tournament(status: TournamentStatus.active),
      );

      await repository.completeIfDecided(id, 'champ');

      final badges = await userBadges('champ');
      expect(badges, isNotNull);
      expect(badges!.containsKey('tournament_champion'), isTrue);
    });

    test('does not award the badge when the guard blocks completion', () async {
      final id = await repository.createTournament(_tournament());

      await repository.completeIfDecided(id, 'champ');

      expect(await userBadges('champ'), anyOf(isNull, isEmpty));
    });

    test(
      'write-once: an existing tournament_champion timestamp is preserved',
      () async {
        final original = DateTime(2026, 1, 1, 9);
        await firestore.collection('users').doc('champ').set({
          'badges': {'tournament_champion': Timestamp.fromDate(original)},
        });
        final id = await repository.createTournament(
          _tournament(status: TournamentStatus.active),
        );

        await repository.completeIfDecided(id, 'champ');

        final badges = await userBadges('champ');
        expect(
          (badges!['tournament_champion'] as Timestamp).toDate(),
          original,
        );
      },
    );
  });

  group('watchTournaments limit', () {
    test('bounds the number of docs returned', () async {
      for (var i = 0; i < 4; i++) {
        await repository.createTournament(_tournament());
      }

      final capped = await repository.watchTournaments(limit: 2).first;
      expect(capped.length, 2);
    });
  });

  group('registerParticipant', () {
    test('writes the doc and increments seeds', () async {
      final id = await repository.createTournament(_tournament());

      await repository.registerParticipant(id, 'u1', now: _beforeDeadline);
      await repository.registerParticipant(id, 'u2', now: _beforeDeadline);

      final participants = await repository.watchParticipants(id).first;
      expect(participants.map((p) => p.uid), ['u1', 'u2']);
      expect(participants.map((p) => p.seed), [1, 2]);
      expect(participants.every((p) => !p.eliminated), isTrue);
      // Denormalized count tracks each new registration.
      expect((await repository.getTournament(id))!.participantCount, 2);
    });

    test('re-registering the same uid is idempotent', () async {
      final id = await repository.createTournament(_tournament());

      await repository.registerParticipant(id, 'u1', now: _beforeDeadline);
      await repository.registerParticipant(id, 'u1', now: _beforeDeadline);

      final participants = await repository.watchParticipants(id).first;
      expect(participants.length, 1);
      expect(participants.single.seed, 1);
      // A no-op re-register must not bump the count.
      expect((await repository.getTournament(id))!.participantCount, 1);
    });

    test('throws when the tournament is full', () async {
      final id = await repository.createTournament(
        _tournament(maxParticipants: 1),
      );
      await repository.registerParticipant(id, 'u1', now: _beforeDeadline);

      expect(
        () => repository.registerParticipant(id, 'u2', now: _beforeDeadline),
        throwsA(isA<StateError>()),
      );
    });

    test('throws when the deadline has passed', () async {
      final id = await repository.createTournament(_tournament());

      expect(
        () =>
            repository.registerParticipant(id, 'u1', now: DateTime(2026, 7, 6)),
        throwsA(isA<StateError>()),
      );
    });

    test('throws when registration is not open', () async {
      final id = await repository.createTournament(
        _tournament(status: 'seeded'),
      );

      expect(
        () => repository.registerParticipant(id, 'u1', now: _beforeDeadline),
        throwsA(isA<StateError>()),
      );
    });

    test('capacity guard reads participantCount, not the roster size', () async {
      // Denormalized count already at max with an empty roster (the guard must
      // trust the transactionally-read count, not a pre-read subcollection scan).
      final id = await repository.createTournament(
        _tournament(maxParticipants: 2),
      );
      await repository.updateTournament(id, {'participantCount': 2});

      expect(
        () => repository.registerParticipant(id, 'u1', now: _beforeDeadline),
        throwsA(isA<StateError>()),
      );
    });

    test('seeds the new participant from participantCount', () async {
      // A count ahead of the roster (drift) must still drive the next seed, so
      // two concurrent joins can never share one.
      final id = await repository.createTournament(_tournament());
      await repository.updateTournament(id, {'participantCount': 3});

      await repository.registerParticipant(id, 'u1', now: _beforeDeadline);

      final participants = await repository.watchParticipants(id).first;
      expect(participants.single.seed, 4);
      expect((await repository.getTournament(id))!.participantCount, 4);
    });
  });

  group('activateIfStarted', () {
    test('flips seeded → active', () async {
      final id = await repository.createTournament(
        _tournament(status: 'seeded'),
      );

      await repository.activateIfStarted(id);

      expect((await repository.getTournament(id))!.status, 'active');
    });

    test('is a no-op when not seeded', () async {
      for (final status in ['registering', 'active', 'completed']) {
        final id = await repository.createTournament(
          _tournament(status: status),
        );
        await repository.activateIfStarted(id);
        expect((await repository.getTournament(id))!.status, status);
      }
    });
  });

  group('recordBracketMatch', () {
    test(
      'appends the matchId and flips seeded → active on the first',
      () async {
        final id = await repository.createTournament(
          _tournament(status: 'seeded'),
        );

        await repository.recordBracketMatch(id, 'final', 'm1');

        final loaded = await repository.getTournament(id);
        expect(loaded!.bracket['final'], ['m1']);
        expect(loaded.status, 'active');
      },
    );

    test('appends without duplicating and does not re-flip', () async {
      final id = await repository.createTournament(
        _tournament(status: 'seeded'),
      );

      await repository.recordBracketMatch(id, 'final', 'm1');
      await repository.recordBracketMatch(id, 'final', 'm1'); // dup
      await repository.recordBracketMatch(id, 'final', 'm2');

      final loaded = await repository.getTournament(id);
      expect(loaded!.bracket['final'], ['m1', 'm2']);
      expect(loaded.status, 'active');
    });
  });
}
