import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/models/challenge_model.dart';
import 'package:campus_arena/repositories/challenge_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ChallengeRepository repository;

  const from = 'sender';
  const to = 'target';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = ChallengeRepository(firestore: firestore);
  });

  Future<void> seedUser(String uid, {List<String> friends = const []}) {
    return firestore.collection('users').doc(uid).set({
      'name': uid,
      'friendUids': friends,
    });
  }

  Future<String> addChallenge({
    String fromUserId = from,
    String toUserId = to,
    String sportId = SportIds.pingPong,
    String status = ChallengeStatus.pending,
    required DateTime createdAt,
    DateTime? respondedAt,
  }) async {
    final ref = await firestore.collection('challenges').add({
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'sportId': sportId,
      'status': status,
      'matchId': null,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null
          ? Timestamp.fromDate(respondedAt)
          : null,
    });
    return ref.id;
  }

  Future<ChallengeModel> read(String id) async {
    final snap = await firestore.collection('challenges').doc(id).get();
    return ChallengeModel.fromMap(snap.data()!, snap.id);
  }

  group('sendChallenge guards', () {
    test('rejects a recipient who is not a friend', () async {
      await seedUser(from, friends: const []);
      expect(
        () => repository.sendChallenge(
          fromUserId: from,
          toUserId: to,
          sportId: SportIds.pingPong,
        ),
        throwsA(
          isA<ChallengeException>().having(
            (e) => e.reason,
            'reason',
            ChallengeError.notFriends,
          ),
        ),
      );
    });

    test('rejects a self-challenge', () async {
      await seedUser(from, friends: const [from]);
      expect(
        () => repository.sendChallenge(
          fromUserId: from,
          toUserId: from,
          sportId: SportIds.pingPong,
        ),
        throwsA(
          isA<ChallengeException>().having(
            (e) => e.reason,
            'reason',
            ChallengeError.self,
          ),
        ),
      );
    });

    test(
      'rejects a duplicate pending challenge for the same (from,to,sport)',
      () async {
        await seedUser(from, friends: const [to]);
        await repository.sendChallenge(
          fromUserId: from,
          toUserId: to,
          sportId: SportIds.pingPong,
        );
        expect(
          () => repository.sendChallenge(
            fromUserId: from,
            toUserId: to,
            sportId: SportIds.pingPong,
          ),
          throwsA(
            isA<ChallengeException>().having(
              (e) => e.reason,
              'reason',
              ChallengeError.duplicatePending,
            ),
          ),
        );
      },
    );

    test('allows a different sport while one sport is pending', () async {
      await seedUser(from, friends: const [to]);
      await repository.sendChallenge(
        fromUserId: from,
        toUserId: to,
        sportId: SportIds.pingPong,
      );
      // A foosball challenge is a distinct (from,to,sport) tuple.
      await repository.sendChallenge(
        fromUserId: from,
        toUserId: to,
        sportId: SportIds.foosball,
      );
      final snap = await firestore.collection('challenges').get();
      expect(snap.docs.length, 2);
    });

    test('allows a new send after the previous one was declined', () async {
      await seedUser(from, friends: const [to]);
      final id = await addChallenge(
        status: ChallengeStatus.declined,
        createdAt: DateTime(2026, 7, 1),
        respondedAt: DateTime(2026, 7, 1),
      );
      expect((await read(id)).status, ChallengeStatus.declined);

      await repository.sendChallenge(
        fromUserId: from,
        toUserId: to,
        sportId: SportIds.pingPong,
      );
      final pending = await firestore
          .collection('challenges')
          .where('status', isEqualTo: ChallengeStatus.pending)
          .get();
      expect(pending.docs.length, 1);
    });

    test('writes status pending with a server timestamp', () async {
      await seedUser(from, friends: const [to]);
      await repository.sendChallenge(
        fromUserId: from,
        toUserId: to,
        sportId: SportIds.pingPong,
      );
      final snap = await firestore.collection('challenges').get();
      final data = snap.docs.single.data();
      expect(data['status'], ChallengeStatus.pending);
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['matchId'], isNull);
    });
  });

  group('respond', () {
    test('accept sets accepted + respondedAt', () async {
      final id = await addChallenge(createdAt: DateTime(2026, 7, 6, 10));
      final now = DateTime(2026, 7, 6, 11);

      await repository.respond(challengeId: id, accept: true, now: now);

      final updated = await read(id);
      expect(updated.status, ChallengeStatus.accepted);
      expect(updated.respondedAt, now);
    });

    test('decline sets declined + respondedAt', () async {
      final id = await addChallenge(createdAt: DateTime(2026, 7, 6, 10));
      final now = DateTime(2026, 7, 6, 11);

      await repository.respond(challengeId: id, accept: false, now: now);

      final updated = await read(id);
      expect(updated.status, ChallengeStatus.declined);
      expect(updated.respondedAt, now);
    });

    test('throws noLongerPending when the challenge is not pending', () async {
      final id = await addChallenge(
        status: ChallengeStatus.accepted,
        createdAt: DateTime(2026, 7, 6, 10),
      );
      await expectLater(
        repository.respond(
          challengeId: id,
          accept: true,
          now: DateTime(2026, 7, 6, 11),
        ),
        throwsA(
          isA<ChallengeRespondException>().having(
            (e) => e.reason,
            'reason',
            ChallengeRespondError.noLongerPending,
          ),
        ),
      );
    });

    test(
      'throws expired for a challenge older than 48h, flips it to expired, and '
      'drops it from the pending inbox',
      () async {
        final created = DateTime(2026, 7, 1, 10);
        final id = await addChallenge(createdAt: created);
        // Well past the 48h timeout.
        final now = created.add(const Duration(hours: 72));

        await expectLater(
          repository.respond(challengeId: id, accept: true, now: now),
          throwsA(
            isA<ChallengeRespondException>().having(
              (e) => e.reason,
              'reason',
              ChallengeRespondError.expired,
            ),
          ),
        );

        final updated = await read(id);
        expect(updated.status, ChallengeStatus.expired);
        expect(updated.respondedAt, isNull);

        // The committed expiry write means the pending-filtered inbox no longer
        // surfaces it — the card leaves the inbox rather than sticking around.
        final inbox = await repository.watchIncomingPending(to).first;
        expect(inbox.map((c) => c.challengeId), isNot(contains(id)));
      },
    );

    test('throws noLongerPending when the challenge does not exist', () async {
      await expectLater(
        repository.respond(challengeId: 'ghost', accept: true),
        throwsA(
          isA<ChallengeRespondException>().having(
            (e) => e.reason,
            'reason',
            ChallengeRespondError.noLongerPending,
          ),
        ),
      );
    });
  });

  group('expireIfDue', () {
    test('expires a pending challenge past the timeout', () async {
      final created = DateTime(2026, 7, 1, 10);
      final id = await addChallenge(createdAt: created);

      await repository.expireIfDue(
        await read(id),
        now: created.add(const Duration(hours: 50)),
      );

      expect((await read(id)).status, ChallengeStatus.expired);
    });

    test('is a no-op for a fresh pending challenge', () async {
      final created = DateTime(2026, 7, 6, 10);
      final id = await addChallenge(createdAt: created);

      await repository.expireIfDue(
        await read(id),
        now: created.add(const Duration(hours: 2)),
      );

      expect((await read(id)).status, ChallengeStatus.pending);
    });

    test('is a no-op for a terminal challenge', () async {
      final created = DateTime(2026, 7, 1, 10);
      final id = await addChallenge(
        status: ChallengeStatus.accepted,
        createdAt: created,
      );

      await repository.expireIfDue(
        await read(id),
        now: created.add(const Duration(hours: 500)),
      );

      expect((await read(id)).status, ChallengeStatus.accepted);
    });
  });

  group('queries', () {
    test(
      'watchIncomingPending returns only pending, newest first, bounded',
      () async {
        for (var i = 0; i < 7; i++) {
          await addChallenge(
            fromUserId: 'f$i',
            toUserId: to,
            createdAt: DateTime(2026, 7, 1).add(Duration(minutes: i)),
          );
        }
        // An accepted one must be excluded by the status filter.
        await addChallenge(
          fromUserId: 'other',
          toUserId: to,
          status: ChallengeStatus.accepted,
          createdAt: DateTime(2026, 7, 2),
        );

        final incoming = await repository.watchIncomingPending(to).first;

        expect(incoming.length, 5);
        expect(
          incoming.every((c) => c.status == ChallengeStatus.pending),
          isTrue,
        );
        // Newest first.
        expect(
          incoming.first.createdAt.isAfter(incoming.last.createdAt),
          isTrue,
        );
      },
    );

    test(
      'watchOutgoingRecent returns all statuses, newest first, bounded',
      () async {
        for (var i = 0; i < 7; i++) {
          await addChallenge(
            fromUserId: from,
            toUserId: 't$i',
            status: i.isEven
                ? ChallengeStatus.pending
                : ChallengeStatus.declined,
            createdAt: DateTime(2026, 7, 1).add(Duration(minutes: i)),
          );
        }

        final outgoing = await repository.watchOutgoingRecent(from).first;

        expect(outgoing.length, 5);
        // No status filter — declined rows are present.
        expect(
          outgoing.any((c) => c.status == ChallengeStatus.declined),
          isTrue,
        );
      },
    );

    test('watchChallenge emits the doc then null when absent', () async {
      final id = await addChallenge(createdAt: DateTime(2026, 7, 6));
      expect((await repository.watchChallenge(id).first)?.challengeId, id);
      expect(await repository.watchChallenge('ghost').first, isNull);
    });
  });
}
