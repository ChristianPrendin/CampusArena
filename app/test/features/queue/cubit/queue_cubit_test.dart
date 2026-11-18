import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/features/queue/cubit/queue_cubit.dart';
import 'package:campus_arena/features/queue/cubit/queue_state.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/queue_test_helpers.dart';

void main() {
  late MockQueueRepository queueRepo;
  late MockFacilityRepository facilityRepo;
  late StreamController<List<QueueEntryModel>> queueStream;
  late StreamController<FacilityModel?> facilityStream;

  setUp(() {
    queueRepo = MockQueueRepository();
    facilityRepo = MockFacilityRepository();
    queueStream = StreamController<List<QueueEntryModel>>();
    facilityStream = StreamController<FacilityModel?>();

    when(
      () => queueRepo.watchQueue(any()),
    ).thenAnswer((_) => queueStream.stream);
    when(
      () => facilityRepo.watchFacility(any()),
    ).thenAnswer((_) => facilityStream.stream);
    // Default: not queued on open, so the live listeners stay detached until a
    // join. Tests that start "already in queue" override this.
    when(
      () => queueRepo.getPosition(
        facilityId: any(named: 'facilityId'),
        uid: any(named: 'uid'),
      ),
    ).thenAnswer((_) async => null);
  });

  tearDown(() {
    queueStream.close();
    facilityStream.close();
  });

  QueueCubit build() => QueueCubit(
    facilityId: queueFacilityId,
    uid: queueUid,
    queueRepository: queueRepo,
    facilityRepository: facilityRepo,
  );

  /// Stubs the one-shot membership probe so the cubit attaches its live
  /// listeners on construction (the "already in queue on open" path).
  void stubAlreadyQueued(int position) {
    when(
      () => queueRepo.getPosition(
        facilityId: any(named: 'facilityId'),
        uid: any(named: 'uid'),
      ),
    ).thenAnswer((_) async => position);
  }

  blocTest<QueueCubit, QueueState>(
    'join emits joining, then inQueue once the queue stream observes me',
    build: () {
      when(
        () => queueRepo.joinQueue(
          facilityId: any(named: 'facilityId'),
          uid: any(named: 'uid'),
        ),
      ).thenAnswer((_) async => 1);
      return build();
    },
    act: (cubit) async {
      await cubit.join();
      queueStream.add([queueEntry(queueUid, 1)]);
      await pumpEventQueue();
    },
    expect: () => const [
      QueueState(status: QueueStatus.joining),
      QueueState(
        status: QueueStatus.inQueue,
        position: 1,
        queueLength: 1,
        isFront: true,
      ),
    ],
    verify: (_) {
      verify(
        () => queueRepo.joinQueue(facilityId: queueFacilityId, uid: queueUid),
      ).called(1);
    },
  );

  blocTest<QueueCubit, QueueState>(
    'leave emits leaving, then idle',
    build: () {
      stubAlreadyQueued(1);
      when(
        () => queueRepo.leaveQueue(
          facilityId: any(named: 'facilityId'),
          uid: any(named: 'uid'),
        ),
      ).thenAnswer((_) async {});
      return build();
    },
    act: (cubit) async {
      await pumpEventQueue(); // let the membership probe attach the listeners
      queueStream.add([queueEntry(queueUid, 1)]);
      await pumpEventQueue();
      await cubit.leave();
    },
    expect: () => const [
      QueueState(
        status: QueueStatus.inQueue,
        position: 1,
        queueLength: 1,
        isFront: true,
      ),
      QueueState(
        status: QueueStatus.leaving,
        position: 1,
        queueLength: 1,
        isFront: true,
      ),
      QueueState(),
    ],
  );

  blocTest<QueueCubit, QueueState>(
    'position and front update as the queue ahead of me drains',
    build: () {
      stubAlreadyQueued(2);
      return build();
    },
    act: (cubit) async {
      await pumpEventQueue();
      queueStream.add([queueEntry('other', 1), queueEntry(queueUid, 2)]);
      await pumpEventQueue();
      queueStream.add([queueEntry(queueUid, 2)]);
      await pumpEventQueue();
    },
    expect: () => const [
      QueueState(
        status: QueueStatus.inQueue,
        position: 2,
        queueLength: 2,
        isFront: false,
      ),
      QueueState(
        status: QueueStatus.inQueue,
        position: 1,
        queueLength: 1,
        isFront: true,
      ),
    ],
  );

  blocTest<QueueCubit, QueueState>(
    'fires tableReady when front-of-queue and the facility frees',
    build: () {
      stubAlreadyQueued(1);
      return build();
    },
    act: (cubit) async {
      await pumpEventQueue();
      queueStream.add([queueEntry(queueUid, 1)]);
      await pumpEventQueue();
      // Baseline snapshot: seen but not a transition, so no alert.
      facilityStream.add(queueFacility(status: 'occupied'));
      await pumpEventQueue();
      // Table frees: status → free with a fresh freedAt while I'm front.
      facilityStream.add(
        queueFacility(status: 'free', freedAt: DateTime(2026, 7, 4, 10)),
      );
      await pumpEventQueue();
    },
    expect: () => const [
      QueueState(
        status: QueueStatus.inQueue,
        position: 1,
        queueLength: 1,
        isFront: true,
      ),
      QueueState(
        status: QueueStatus.inQueue,
        position: 1,
        queueLength: 1,
        isFront: true,
        tableReady: true,
      ),
    ],
  );

  blocTest<QueueCubit, QueueState>(
    'does not fire tableReady for a non-front waiter',
    build: () {
      stubAlreadyQueued(2);
      return build();
    },
    act: (cubit) async {
      await pumpEventQueue();
      queueStream.add([queueEntry('other', 1), queueEntry(queueUid, 2)]);
      await pumpEventQueue();
      facilityStream.add(queueFacility(status: 'occupied'));
      await pumpEventQueue();
      facilityStream.add(
        queueFacility(status: 'free', freedAt: DateTime(2026, 7, 4, 10)),
      );
      await pumpEventQueue();
    },
    expect: () => const [
      QueueState(
        status: QueueStatus.inQueue,
        position: 2,
        queueLength: 2,
        isFront: false,
      ),
    ],
  );

  blocTest<QueueCubit, QueueState>(
    'does not fire a stale tableReady after the table is re-occupied and I am '
    'later promoted to front',
    build: () {
      stubAlreadyQueued(2);
      return build();
    },
    act: (cubit) async {
      await pumpEventQueue();
      queueStream.add([queueEntry('other', 1), queueEntry(queueUid, 2)]);
      await pumpEventQueue();
      // Baseline, then the table frees while I'm still #2 → pending, no fire.
      facilityStream.add(queueFacility(status: 'occupied'));
      await pumpEventQueue();
      facilityStream.add(
        queueFacility(status: 'free', freedAt: DateTime(2026, 7, 4, 10)),
      );
      await pumpEventQueue();
      // The person ahead claims the table (re-occupied): the pending alert is now
      // stale and must be dropped.
      facilityStream.add(queueFacility(status: 'occupied'));
      await pumpEventQueue();
      // They leave the queue → I'm promoted to front. Must NOT fire.
      queueStream.add([queueEntry(queueUid, 2)]);
      await pumpEventQueue();
    },
    expect: () => const [
      QueueState(
        status: QueueStatus.inQueue,
        position: 2,
        queueLength: 2,
        isFront: false,
      ),
      QueueState(
        status: QueueStatus.inQueue,
        position: 1,
        queueLength: 1,
        isFront: true,
      ),
    ],
  );

  blocTest<QueueCubit, QueueState>(
    'join emits error (lastAction join) when the transactional write fails',
    build: () {
      when(
        () => queueRepo.joinQueue(
          facilityId: any(named: 'facilityId'),
          uid: any(named: 'uid'),
        ),
      ).thenThrow(Exception('offline'));
      return build();
    },
    act: (cubit) => cubit.join(),
    expect: () => const [
      QueueState(status: QueueStatus.joining),
      QueueState(status: QueueStatus.error, lastAction: QueueAction.join),
    ],
  );

  blocTest<QueueCubit, QueueState>(
    'leave failure emits error tagged lastAction.leave so Retry re-issues leave',
    build: () {
      stubAlreadyQueued(1);
      when(
        () => queueRepo.leaveQueue(
          facilityId: any(named: 'facilityId'),
          uid: any(named: 'uid'),
        ),
      ).thenThrow(Exception('offline'));
      return build();
    },
    act: (cubit) async {
      await pumpEventQueue();
      queueStream.add([queueEntry(queueUid, 1)]);
      await pumpEventQueue();
      await cubit.leave();
    },
    expect: () => const [
      QueueState(
        status: QueueStatus.inQueue,
        position: 1,
        queueLength: 1,
        isFront: true,
      ),
      QueueState(
        status: QueueStatus.leaving,
        position: 1,
        queueLength: 1,
        isFront: true,
      ),
      QueueState(
        status: QueueStatus.error,
        position: 1,
        queueLength: 1,
        isFront: true,
        lastAction: QueueAction.leave,
      ),
    ],
    verify: (_) {
      verify(
        () => queueRepo.leaveQueue(facilityId: queueFacilityId, uid: queueUid),
      ).called(1);
    },
  );
}
