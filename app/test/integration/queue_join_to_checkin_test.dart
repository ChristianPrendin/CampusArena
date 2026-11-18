import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/map/user_location_service.dart';
import 'package:campus_arena/features/match/cubit/match_cubit.dart';
import 'package:campus_arena/features/match/cubit/match_state.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/repositories/facility_repository.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/queue_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/tournament_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUserLocationService extends Mock implements UserLocationService {}

/// Shared contract #3 — the queue position write.
///
/// The queue vertical OWNS the join transaction that assigns the monotonic
/// `position` ticket; the match vertical's check-in READS the queue to derive
/// the scanner's standing. This drives the real joinQueue transaction and the
/// real MatchCubit check-in read over one shared Firestore, proving the rank
/// the check-in surfaces is derived from what the queue transaction wrote.
void main() {
  late FakeFirebaseFirestore firestore;
  late QueueRepository queueRepository;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    queueRepository = QueueRepository(firestore: firestore);
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

  MatchCubit checkInCubit(String uid) {
    final location = MockUserLocationService();
    when(() => location.getCurrentPosition()).thenAnswer((_) async => null);
    return MatchCubit(
      uid: uid,
      matchRepository: MatchRepository(firestore: firestore),
      facilityRepository: FacilityRepository(firestore: firestore),
      queueRepository: queueRepository,
      ratingRepository: RatingRepository(firestore: firestore),
      userRepository: UserRepository(firestore: firestore),
      tournamentRepository: TournamentRepository(firestore: firestore),
      locationService: location,
    );
  }

  test(
    'check-in derives the scanner rank from the queue-owned positions',
    () async {
      // Queue vertical writes the tickets: front gets 1, me gets 2.
      await queueRepository.joinQueue(facilityId: 'f1', uid: 'front');
      final myPosition = await queueRepository.joinQueue(
        facilityId: 'f1',
        uid: 'me',
      );
      expect(myPosition, 2, reason: 'monotonic ticket assigned by the queue');

      // Match vertical reads it at check-in.
      final cubit = checkInCubit('me');
      addTearDown(cubit.close);
      await cubit.submitCode('f1');

      expect(cubit.state.status, MatchStatus.readyToConfirm);
      // Dense 1-based rank derived from the ordered snapshot index, not the raw
      // stored ticket — front is 1, I am 2.
      expect(cubit.state.queuePosition, 2);
      expect(cubit.state.queueFrontPosition, 1);
      expect(cubit.state.queuePriorityWarning, isTrue);
    },
  );

  test(
    'a position stored as a Firestore double is coerced, not dropped',
    () async {
      // Firestore may hand a numeric field back as double; the ticket must still
      // parse (regression for QueueEntryModel.fromMap using `as int`).
      await firestore
          .collection(FirestoreCollections.facilities)
          .doc('f1')
          .collection(FirestoreCollections.queue)
          .doc('me')
          .set({
            'userId': 'me',
            'position': 2.0,
            'joinedAt': Timestamp.fromDate(DateTime(2026, 7, 5, 9)),
          });

      final entries = await queueRepository.watchQueue('f1').first;
      expect(entries, hasLength(1));
      expect(entries.single.position, 2);
    },
  );
}
