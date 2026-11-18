import 'package:campus_arena/repositories/queue_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late QueueRepository repository;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    repository = QueueRepository(firestore: firestore);

    // Seed a facility for the queue tests to attach to.
    await firestore.collection('facilities').doc('f1').set({
      'facilityId': 'f1',
      'name': 'Test Table',
      'sportId': 'ping_pong',
      'queueTailPosition': 0,
    });
  });

  test('joinQueue assigns monotonic positions', () async {
    expect(await repository.joinQueue(facilityId: 'f1', uid: 'u1'), 1);
    expect(await repository.joinQueue(facilityId: 'f1', uid: 'u2'), 2);
    expect(await repository.joinQueue(facilityId: 'f1', uid: 'u3'), 3);
  });

  test('joinQueue is idempotent for an already-queued user', () async {
    await repository.joinQueue(facilityId: 'f1', uid: 'u1');
    await repository.joinQueue(facilityId: 'f1', uid: 'u2');

    expect(await repository.joinQueue(facilityId: 'f1', uid: 'u1'), 1);
    expect(await repository.getPosition(facilityId: 'f1', uid: 'u2'), 2);
  });

  test('getPosition returns null when not queued', () async {
    expect(
      await repository.getPosition(facilityId: 'f1', uid: 'ghost'),
      isNull,
    );
  });

  Future<int> tail() async {
    final snap = await firestore.collection('facilities').doc('f1').get();
    return (snap.data()!['queueTailPosition'] as num).toInt();
  }

  test('leaveQueue removes the ticket without renumbering (positions are '
      'monotonic; rank comes from snapshot order)', () async {
    await repository.joinQueue(facilityId: 'f1', uid: 'u1');
    await repository.joinQueue(facilityId: 'f1', uid: 'u2');
    await repository.joinQueue(facilityId: 'f1', uid: 'u3');

    await repository.leaveQueue(facilityId: 'f1', uid: 'u1');

    expect(await repository.getPosition(facilityId: 'f1', uid: 'u1'), isNull);
    // Survivors keep their ticket numbers; the ordered snapshot still yields
    // dense ranks (u2 is index 0 → rank 1, u3 index 1 → rank 2).
    expect(await repository.getPosition(facilityId: 'f1', uid: 'u2'), 2);
    expect(await repository.getPosition(facilityId: 'f1', uid: 'u3'), 3);
    // queueTailPosition is a monotonic counter — a leave never rewrites it.
    expect(await tail(), 3);
  });

  test('join → leave → rejoin issues a fresh monotonic ticket', () async {
    expect(await repository.joinQueue(facilityId: 'f1', uid: 'u1'), 1);
    expect(await tail(), 1);

    await repository.leaveQueue(facilityId: 'f1', uid: 'u1');
    // The counter is not decremented on leave.
    expect(await tail(), 1);

    expect(await repository.joinQueue(facilityId: 'f1', uid: 'u1'), 2);
    expect(await tail(), 2);
  });

  test('leaveQueue is a no-op for a non-queued user', () async {
    await repository.joinQueue(facilityId: 'f1', uid: 'u1');

    await repository.leaveQueue(facilityId: 'f1', uid: 'ghost');

    expect(await repository.getPosition(facilityId: 'f1', uid: 'u1'), 1);
    expect(await tail(), 1);
  });

  test('watchQueue emits entries ordered by position', () async {
    await repository.joinQueue(facilityId: 'f1', uid: 'u1');
    await repository.joinQueue(facilityId: 'f1', uid: 'u2');

    final entries = await repository.watchQueue('f1').first;

    expect(entries.map((e) => e.uid), ['u1', 'u2']);
    expect(entries.map((e) => e.position), [1, 2]);
  });

  group('getQueueLength', () {
    test('counts entries via a bounded aggregation query', () async {
      await repository.joinQueue(facilityId: 'f1', uid: 'u1');
      await repository.joinQueue(facilityId: 'f1', uid: 'u2');

      expect(await repository.getQueueLength('f1'), 2);
    });

    test('returns 0 for an empty queue', () async {
      expect(await repository.getQueueLength('f1'), 0);
    });
  });

  group('getUserQueueEntry', () {
    test('finds the entry across facilities via collectionGroup', () async {
      await firestore.collection('facilities').doc('f2').set({
        'facilityId': 'f2',
        'name': 'Other Table',
        'sportId': 'foosball',
        'queueTailPosition': 0,
      });
      await repository.joinQueue(facilityId: 'f2', uid: 'u1');

      final entry = await repository.getUserQueueEntry('u1');

      expect(entry, isNotNull);
      expect(entry!.facilityId, 'f2');
      expect(entry.position, 1);
    });

    test('returns null when the user is not queued anywhere', () async {
      expect(await repository.getUserQueueEntry('ghost'), isNull);
    });
  });

  Future<String?> statusOf(String facilityId) async {
    final snap = await firestore.collection('facilities').doc(facilityId).get();
    return snap.data()?['status'] as String?;
  }

  group('facility status transitions', () {
    test('joinQueue on an occupied facility sets status to queued', () async {
      await firestore.collection('facilities').doc('f1').update({
        'status': 'occupied',
      });

      await repository.joinQueue(facilityId: 'f1', uid: 'u1');

      expect(await statusOf('f1'), 'queued');
    });

    test('joinQueue on a free facility does not change status', () async {
      await firestore.collection('facilities').doc('f1').update({
        'status': 'free',
      });

      await repository.joinQueue(facilityId: 'f1', uid: 'u1');

      // A free facility must stay claimable by createMatch, which requires
      // 'free'. Stamping 'queued' here would brick the table permanently.
      expect(await statusOf('f1'), 'free');
    });

    test('last member leaving reverts queued to occupied', () async {
      await firestore.collection('facilities').doc('f1').update({
        'status': 'occupied',
      });
      await repository.joinQueue(facilityId: 'f1', uid: 'u1');
      expect(await statusOf('f1'), 'queued');

      await repository.leaveQueue(facilityId: 'f1', uid: 'u1');

      expect(await statusOf('f1'), 'occupied');
    });

    test('a non-last leave does not touch status', () async {
      await firestore.collection('facilities').doc('f1').update({
        'status': 'occupied',
      });
      await repository.joinQueue(facilityId: 'f1', uid: 'u1');
      await repository.joinQueue(facilityId: 'f1', uid: 'u2');

      await repository.leaveQueue(facilityId: 'f1', uid: 'u1');

      expect(await statusOf('f1'), 'queued');
    });
  });
}
