// Integration test for the full "Proof of Play" loop against a
// `FakeFirebaseFirestore` backend (task_board.md Phase 7 stretch goal;
// test_plan.md §5). Unlike `match_repository_test.dart`, which seeds each
// scenario directly into its target `state`, this drives the whole chain —
// scan(s) → result → confirm → ELO update — as one continuous sequence
// through the real repositories, and asserts the cross-vertical shared
// contracts from task_board.md (match doc shape, facility status flip,
// queue position) hold across the full transition, not just at one step.

import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/models/rating_model.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/queue_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MatchRepository matchRepo;
  late QueueRepository queueRepo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    matchRepo = MatchRepository(firestore: firestore);
    queueRepo = QueueRepository(firestore: firestore);
  });

  Future<void> seedFacility(String id, {String sportId = SportIds.pingPong}) {
    return firestore
        .collection(FirestoreCollections.facilities)
        .doc(id)
        .set(
          FacilityModel(
            facilityId: id,
            name: 'Table $id',
            sportId: sportId,
            coordinates: const Coordinates(latitude: 45.47, longitude: 9.22),
            qrCode: 'qr_$id',
            fallbackCode: 'FB$id',
            isOutdoor: false,
            status: FacilityStatus.free,
            kingOfTableWins: 0,
            queueTailPosition: 0,
          ).toMap(),
        );
  }

  Future<void> seedRating(
    String ownerId, {
    String ownerType = OwnerType.user,
    List<String>? memberUids,
    String sportId = SportIds.pingPong,
  }) {
    final id = RatingRepository.ratingId(sportId, ownerId);
    return firestore
        .collection(FirestoreCollections.ratings)
        .doc(id)
        .set(
          RatingModel(
            ratingId: id,
            ownerType: ownerType,
            ownerId: ownerId,
            memberUids: memberUids,
            sportId: sportId,
            elo: 1200,
            matchesPlayed: 0,
            lastMatchAt: DateTime(2026, 6, 30, 9),
          ).toMap(),
        );
  }

  Future<FacilityModel> facility(String id) async {
    final snap = await firestore
        .collection(FirestoreCollections.facilities)
        .doc(id)
        .get();
    return FacilityModel.fromMap(snap.data()!, snap.id);
  }

  Future<MatchModel> matchById(String id) async {
    final snap = await firestore
        .collection(FirestoreCollections.matches)
        .doc(id)
        .get();
    return MatchModel.fromMap(snap.data()!, snap.id);
  }

  Future<RatingModel> ratingById(String ownerId, {String? sportId}) async {
    final id = RatingRepository.ratingId(sportId ?? SportIds.pingPong, ownerId);
    final snap = await firestore
        .collection(FirestoreCollections.ratings)
        .doc(id)
        .get();
    return RatingModel.fromMap(snap.data()!, snap.id);
  }

  test('singles: scan (create + join) → result → confirm carries ELO and the '
      'facility-status shared contract across every step, leaving a bystander '
      "queue ticket untouched by the match's own scan", () async {
    await seedFacility('f1');
    await seedRating('u1');
    await seedRating('u2');
    // A third player already queued behind the two about to play — the
    // queue shared contract says this ticket belongs to the queue vertical
    // and must not be touched by the match vertical's scan.
    final bystanderPosition = await queueRepo.joinQueue(
      facilityId: 'f1',
      uid: 'bystander',
    );

    // 1. Scan: the creator checks in, then the opponent scans the same
    // table's QR to join — exactly how two walk-up players start a match.
    final matchId = await matchRepo.createMatch(
      MatchModel(
        matchId: '',
        facilityId: 'f1',
        sportId: SportIds.pingPong,
        mode: MatchModes.singles,
        playerUids: const ['u1'],
        state: MatchStates.occupied,
        startedAt: DateTime(2026, 7, 10, 12),
      ),
    );
    await matchRepo.joinMatch(facilityId: 'f1', uid: 'u2');

    var match = await matchById(matchId);
    expect(match.playerUids, ['u1', 'u2']);
    expect(match.state, MatchStates.occupied);
    var fac = await facility('f1');
    // Facility shared contract: the scan flips it away from `free`, with
    // the bystander still queued behind it.
    expect(fac.status, FacilityStatus.queued);
    expect(fac.currentMatchId, matchId);

    final bystanderEntry = await queueRepo.getUserQueueEntry('bystander');
    expect(bystanderEntry?.position, bystanderPosition);

    // 2. Result entry.
    await matchRepo.submitResult(
      matchId: matchId,
      submittedByUid: 'u1',
      result: const PingPongResult(
        winnerIds: ['u1'],
        sets: [11, 9, 11],
        opponentSets: [7, 11, 8],
      ),
    );

    match = await matchById(matchId);
    // Match-document-mid-confirmation shared contract fields (task_board.md
    // §Shared Contracts): matchId, state, playerUids, result — present and
    // correct before any ELO write has happened.
    expect(match.matchId, matchId);
    expect(match.state, MatchStates.awaitingConfirmation);
    expect(match.playerUids, ['u1', 'u2']);
    expect(match.result?.winnerIds, ['u1']);
    expect(match.eloDeltas, isNull);

    // 3. Opponent confirmation → ELO update, folded into one transaction.
    await matchRepo.confirmResult(matchId: matchId);

    match = await matchById(matchId);
    expect(match.state, MatchStates.confirmed);
    expect(match.confirmedAt, isNotNull);
    expect(match.playerUids, ['u1', 'u2']); // unchanged by confirm
    expect(match.result?.winnerIds, ['u1']); // unchanged by confirm
    expect(match.eloBefore, {'u1': 1200, 'u2': 1200});
    expect(match.eloDeltas, {'u1': 16, 'u2': -16});

    final winner = await ratingById('u1');
    expect(winner.elo, 1216);
    expect(winner.matchesPlayed, 1);
    final loser = await ratingById('u2');
    expect(loser.elo, 1184);
    expect(loser.matchesPlayed, 1);

    // Facility shared contract: confirm frees the table for the next
    // player to claim it.
    fac = await facility('f1');
    expect(fac.status, FacilityStatus.free);
    expect(fac.currentMatchId, isNull);

    // Queue shared contract: the bystander's ticket is still theirs to
    // resolve — the match vertical never wrote to it.
    final finalBystanderEntry = await queueRepo.getUserQueueEntry('bystander');
    expect(finalBystanderEntry?.position, bystanderPosition);
  });

  test('doubles: creator scans solo, three opponents join and pick sides, '
      'confirm rates both pairs keyed by pairId', () async {
    await seedFacility('f2');

    final matchId = await matchRepo.createMatch(
      MatchModel(
        matchId: '',
        facilityId: 'f2',
        sportId: SportIds.pingPong,
        mode: MatchModes.doubles,
        playerUids: const ['a1'],
        team1PairId: 'a1', // the creator's own uid seeds their side's pairId
        state: MatchStates.occupied,
        startedAt: DateTime(2026, 7, 10, 12),
      ),
    );
    await matchRepo.joinMatch(facilityId: 'f2', uid: 'a2', team: 1);
    await matchRepo.joinMatch(facilityId: 'f2', uid: 'b1', team: 2);
    await matchRepo.joinMatch(facilityId: 'f2', uid: 'b2', team: 2);

    var match = await matchById(matchId);
    expect(match.playerUids, ['a1', 'a2', 'b1', 'b2']);
    expect(match.team1PairId, 'a1_a2');
    expect(match.team2PairId, 'b1_b2');

    await matchRepo.submitResult(
      matchId: matchId,
      submittedByUid: 'a1',
      result: const PingPongResult(
        winnerIds: ['a1', 'a2'],
        sets: [11, 11],
        opponentSets: [4, 6],
      ),
    );
    await matchRepo.confirmResult(matchId: matchId);

    match = await matchById(matchId);
    expect(match.state, MatchStates.confirmed);
    expect(match.eloDeltas, {'a1_a2': 16, 'b1_b2': -16});

    final winningPair = await ratingById('a1_a2');
    expect(winningPair.elo, 1216);
    expect(winningPair.ownerType, OwnerType.pair);
    final losingPair = await ratingById('b1_b2');
    expect(losingPair.elo, 1184);

    final fac = await facility('f2');
    expect(fac.status, FacilityStatus.free);
  });
}
