import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/profile/cubit/profile_cubit.dart';
import 'package:campus_arena/features/profile/cubit/profile_state.dart';
import 'package:campus_arena/features/profile/profile_stats.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/models/rating_model.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/achievement_repository.dart';
import 'package:campus_arena/repositories/facility_repository.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared contract #1 — the match document shape mid-confirmation.
///
/// The match vertical WRITES `state`/`result`/`eloBefore`/`eloDeltas`/
/// `confirmedAt` inside the atomic confirm transaction; the profile/history
/// vertical READS them back. The per-side unit tests already cover each half in
/// isolation; this exercises the real writer transaction and the real
/// ProfileCubit reader over a single shared Firestore, so a field the writer
/// emits but the reader can't parse (or vice-versa) fails here.
void main() {
  late FakeFirebaseFirestore firestore;
  late MatchRepository matchRepository;

  UserModel user(String uid) => UserModel(
    uid: uid,
    name: uid,
    username: uid,
    email: '$uid@polimi.it',
    degreeProgram: 'Computer Science and Engineering',
    language: 'en',
    pushTokens: const [],
    friendUids: const [],
    badges: const {},
    onboardingComplete: true,
    createdAt: DateTime(2026),
  );

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

  ProfileCubit profileCubit(String uid) => ProfileCubit(
    uid: uid,
    ratingRepository: RatingRepository(firestore: firestore),
    matchRepository: matchRepository,
    userRepository: UserRepository(firestore: firestore),
    facilityRepository: FacilityRepository(firestore: firestore),
    achievementRepository: AchievementRepository(firestore: firestore),
    // Bypass the isolate so pumping is deterministic; the derivation itself is
    // covered by profile_stats' own tests.
    derive: (input) async => deriveProfileStats(input),
  );

  test(
    'a confirmed singles match surfaces in the profile history with its ELO delta',
    () async {
      final userRepository = UserRepository(firestore: firestore);
      await userRepository.createUser(user('u1'));
      await seedRating('u1');
      await seedRating('u2');

      // Writer half: the real create → submit → confirm transaction chain.
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

      // Reader half: the real ProfileCubit consuming the same store.
      final cubit = profileCubit('u1');
      addTearDown(cubit.close);

      await expectLater(
        cubit.stream,
        emitsThrough(
          predicate<ProfileState>((s) {
            if (s.status != ProfileStatus.ready) return false;
            final matches = s.matches.where((m) => m.matchId == id);
            if (matches.isEmpty) return false;
            final match = matches.first;
            return match.state == MatchStates.confirmed &&
                match.result?.winnerIds.contains('u1') == true &&
                // Provisional K=32, even 1200s → winner +16.
                match.eloDeltas?['u1'] == 16 &&
                match.eloBefore?['u1'] == 1200 &&
                match.confirmedAt != null;
          }),
        ),
      );
    },
  );

  test(
    'a confirmed doubles match reads back with pairId-keyed ELO deltas',
    () async {
      // Seed the pair ratings the confirm transaction rates.
      for (final pairId in const ['u1_u2', 'u3_u4']) {
        final id = RatingRepository.ratingId(SportIds.pingPong, pairId);
        await firestore
            .collection(FirestoreCollections.ratings)
            .doc(id)
            .set(
              RatingModel(
                ratingId: id,
                ownerType: OwnerType.pair,
                ownerId: pairId,
                memberUids: pairId.split('_'),
                sportId: SportIds.pingPong,
                elo: 1200,
                matchesPlayed: 0,
                lastMatchAt: DateTime(2026, 6, 30, 9),
              ).toMap(),
            );
      }

      // Put the doubles match straight into awaitingConfirmation and point the
      // facility at it — the confirm precondition, without the full join dance.
      final doubles = MatchModel(
        matchId: 'd1',
        facilityId: 'f1',
        sportId: SportIds.pingPong,
        mode: MatchModes.doubles,
        playerUids: const ['u1', 'u2', 'u3', 'u4'],
        team1PairId: 'u1_u2',
        team2PairId: 'u3_u4',
        state: MatchStates.awaitingConfirmation,
        submittedByUid: 'u1',
        result: const PingPongResult(
          winnerIds: ['u1', 'u2'],
          sets: [11],
          opponentSets: [5],
        ),
        startedAt: DateTime(2026, 6, 30, 10),
      );
      await firestore
          .collection(FirestoreCollections.matches)
          .doc('d1')
          .set(doubles.toMap());
      await firestore
          .collection(FirestoreCollections.facilities)
          .doc('f1')
          .update({'status': FacilityStatus.occupied, 'currentMatchId': 'd1'});

      await matchRepository.confirmResult(matchId: 'd1');

      // Reader half: the history watcher a member's profile subscribes to.
      final history = await matchRepository
          .watchUserMatches('u1', limit: 100)
          .first;
      final match = history.singleWhere((m) => m.matchId == 'd1');
      expect(match.state, MatchStates.confirmed);
      // Deltas are keyed by pairId, not member uid — the shape the team-profile
      // reader keys on.
      expect(match.eloBefore, {'u1_u2': 1200, 'u3_u4': 1200});
      expect(match.eloDeltas, {'u1_u2': 16, 'u3_u4': -16});
    },
  );
}
