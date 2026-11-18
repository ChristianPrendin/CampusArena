import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/map/cubit/facility_cubit.dart';
import 'package:campus_arena/features/map/cubit/facility_state.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/models/rating_model.dart';
import 'package:campus_arena/repositories/facility_repository.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/queue_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared contract #2 — the facility `status` field flips busy/free.
///
/// The map vertical's FacilityCubit LISTENS; two verticals WRITE the status:
/// - the match vertical inside the createMatch / confirm transactions, and
/// - the queue vertical (joinQueue stamps `queued`, leaveQueue reverts to
///   `occupied` when the last ticket goes).
/// This drives the real writer transactions of both and asserts the real
/// FacilityCubit stream re-emits the flipped status — proving the live listener
/// the map renders actually observes every writer's transitions.
void main() {
  late FakeFirebaseFirestore firestore;
  late MatchRepository matchRepository;

  bool facilityIs(FacilityState s, String status) {
    if (s.status != FacilityLoadStatus.loaded) return false;
    final match = s.facilities.where((f) => f.facilityId == 'f1');
    return match.isNotEmpty && match.first.status == status;
  }

  Future<void> seedRating(String ownerId) async {
    final id = RatingRepository.ratingId(SportIds.pingPong, ownerId);
    await firestore
        .collection(FirestoreCollections.ratings)
        .doc(id)
        .set(
          RatingModel(
            ratingId: id,
            ownerType: OwnerType.user,
            ownerId: ownerId,
            sportId: SportIds.pingPong,
            elo: 1200,
            matchesPlayed: 0,
            lastMatchAt: DateTime(2026, 6, 30, 9),
          ).toMap(),
        );
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    matchRepository = MatchRepository(firestore: firestore);
    await firestore
        .collection(FirestoreCollections.facilities)
        .doc('f1')
        .set(
          const FacilityModel(
            facilityId: 'f1',
            name: 'Table 1',
            sportId: SportIds.pingPong,
            coordinates: Coordinates(latitude: 45.47, longitude: 9.22),
            qrCode: 'qr_f1',
            fallbackCode: 'FBf1',
            isOutdoor: false,
            status: FacilityStatus.free,
            kingOfTableWins: 0,
            queueTailPosition: 0,
          ).toMap(),
        );
  });

  test(
    'the map listener observes occupied→free across match transactions',
    () async {
      await seedRating('u1');
      await seedRating('u2');

      final cubit = FacilityCubit(
        repository: FacilityRepository(firestore: firestore),
      );
      addTearDown(cubit.close);
      cubit.subscribe();

      // Starts free.
      await expectLater(
        cubit.stream,
        emitsThrough(
          predicate<FacilityState>((s) => facilityIs(s, FacilityStatus.free)),
        ),
      );

      // Writer flips it occupied.
      final id = await matchRepository.createMatch(
        MatchModel(
          matchId: '',
          facilityId: 'f1',
          sportId: SportIds.pingPong,
          mode: MatchModes.singles,
          playerUids: const ['u1', 'u2'],
          state: MatchStates.occupied,
          startedAt: DateTime(2026, 6, 30, 10),
        ),
      );
      await expectLater(
        cubit.stream,
        emitsThrough(
          predicate<FacilityState>(
            (s) => facilityIs(s, FacilityStatus.occupied),
          ),
        ),
      );

      // Confirming the result frees it again.
      await matchRepository.submitResult(
        matchId: id,
        submittedByUid: 'u1',
        result: const PingPongResult(
          winnerIds: ['u1'],
          sets: [11, 11],
          opponentSets: [7, 9],
        ),
      );
      await matchRepository.confirmResult(matchId: id);
      await expectLater(
        cubit.stream,
        emitsThrough(
          predicate<FacilityState>((s) => facilityIs(s, FacilityStatus.free)),
        ),
      );
    },
  );

  test('the map listener observes the queue vertical\'s status writes', () async {
    await seedRating('u1');
    await seedRating('u2');

    final cubit = FacilityCubit(
      repository: FacilityRepository(firestore: firestore),
    );
    addTearDown(cubit.close);
    cubit.subscribe();

    // A live match occupies the table first: joinQueue deliberately never flips
    // a 'free' table, so 'occupied' is the precondition for it to stamp 'queued'.
    await matchRepository.createMatch(
      MatchModel(
        matchId: '',
        facilityId: 'f1',
        sportId: SportIds.pingPong,
        mode: MatchModes.singles,
        playerUids: const ['u1', 'u2'],
        state: MatchStates.occupied,
        startedAt: DateTime(2026, 6, 30, 10),
      ),
    );
    await expectLater(
      cubit.stream,
      emitsThrough(
        predicate<FacilityState>((s) => facilityIs(s, FacilityStatus.occupied)),
      ),
    );

    final queueRepository = QueueRepository(firestore: firestore);

    // Queue vertical writes the status: a join on an occupied table → 'queued'.
    await queueRepository.joinQueue(facilityId: 'f1', uid: 'u3');
    await expectLater(
      cubit.stream,
      emitsThrough(
        predicate<FacilityState>((s) => facilityIs(s, FacilityStatus.queued)),
      ),
    );

    // The last ticket leaving reverts it to 'occupied' (the match is still live).
    await queueRepository.leaveQueue(facilityId: 'f1', uid: 'u3');
    await expectLater(
      cubit.stream,
      emitsThrough(
        predicate<FacilityState>((s) => facilityIs(s, FacilityStatus.occupied)),
      ),
    );
  });
}
