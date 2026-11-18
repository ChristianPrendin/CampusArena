import 'package:campus_arena/core/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/models/rating_model.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

MatchModel _match({String id = '', String state = MatchStates.occupied}) =>
    MatchModel(
      matchId: id,
      facilityId: 'f1',
      sportId: SportIds.pingPong,
      mode: 'singles',
      playerUids: const ['u1', 'u2'],
      state: state,
      startedAt: DateTime(2026, 6, 30, 10),
    );

void main() {
  late FakeFirebaseFirestore firestore;
  late MatchRepository repository;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    repository = MatchRepository(firestore: firestore);
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

  Future<FacilityModel> facility() async {
    final snap = await firestore
        .collection(FirestoreCollections.facilities)
        .doc('f1')
        .get();
    return FacilityModel.fromMap(snap.data()!, snap.id);
  }

  // Direct doc read. `snapshots().first` on fake_cloud_firestore replays the
  // earliest buffered emission, so it can't observe a just-committed write.
  Future<MatchModel> matchById(String id) async {
    final snap = await firestore
        .collection(FirestoreCollections.matches)
        .doc(id)
        .get();
    return MatchModel.fromMap(snap.data()!, snap.id);
  }

  // Seeds a rating doc (user or pair) with a controllable ELO / match count /
  // last-played time, so the confirm path has entities to read and rate.
  Future<void> seedRating(
    String ownerId, {
    int elo = 1200,
    int matchesPlayed = 0,
    String ownerType = OwnerType.user,
    List<String>? memberUids,
    DateTime? lastMatchAt,
    String sportId = SportIds.pingPong,
  }) async {
    final id = RatingRepository.ratingId(sportId, ownerId);
    await firestore
        .collection(FirestoreCollections.ratings)
        .doc(id)
        .set(
          RatingModel(
            ratingId: id,
            ownerType: ownerType,
            ownerId: ownerId,
            memberUids: memberUids,
            sportId: sportId,
            elo: elo,
            matchesPlayed: matchesPlayed,
            lastMatchAt: lastMatchAt ?? DateTime(2026, 6, 30, 9),
          ).toMap(),
        );
  }

  Future<RatingModel> ratingById(String ownerId, {String? sportId}) async {
    final id = RatingRepository.ratingId(sportId ?? SportIds.pingPong, ownerId);
    final snap = await firestore
        .collection(FirestoreCollections.ratings)
        .doc(id)
        .get();
    return RatingModel.fromMap(snap.data()!, snap.id);
  }

  // Writes a match doc straight into `awaitingConfirmation` with a result, and
  // points the facility at it — the precondition for confirm/dispute, without
  // driving the whole createMatch → submitResult path.
  Future<void> putAwaitingMatch(MatchModel match) async {
    await firestore
        .collection(FirestoreCollections.matches)
        .doc(match.matchId)
        .set(match.toMap());
    await firestore
        .collection(FirestoreCollections.facilities)
        .doc(match.facilityId)
        .update({
          'status': FacilityStatus.occupied,
          'currentMatchId': match.matchId,
        });
  }

  test('createMatch auto-generates an id and occupies the facility', () async {
    final id = await repository.createMatch(_match());

    expect(id, isNotEmpty);
    final match = await matchById(id);
    expect(match.matchId, id);
    expect(match.state, MatchStates.occupied);

    final fac = await facility();
    expect(fac.status, FacilityStatus.occupied);
    expect(fac.currentMatchId, id);
  });

  test('createMatch throws StateError if facility is occupied', () async {
    await repository.createMatch(_match());

    expect(
      () => repository.createMatch(_match(id: 'm2')),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'Facility is currently occupied.',
        ),
      ),
    );
  });

  test('submitResult moves to awaitingConfirmation with result', () async {
    final id = await repository.createMatch(_match());

    await repository.submitResult(
      matchId: id,
      submittedByUid: 'u1',
      result: const PingPongResult(
        winnerIds: ['u1'],
        sets: [11, 11],
        opponentSets: [7, 9],
      ),
    );

    final match = await matchById(id);
    expect(match.state, MatchStates.awaitingConfirmation);
    expect(match.submittedByUid, 'u1');
    expect((match.result as PingPongResult).sets, [11, 11]);
  });

  test('confirmResult computes ELO, updates both ratings + facility', () async {
    final id = await repository.createMatch(_match());
    await repository.submitResult(
      matchId: id,
      submittedByUid: 'u1',
      result: const PingPongResult(
        winnerIds: ['u1'],
        sets: [11, 11],
        opponentSets: [7, 9],
      ),
    );
    await seedRating('u1'); // 1200 / 0 provisional (K=32)
    await seedRating('u2');

    await repository.confirmResult(matchId: id);

    final match = await matchById(id);
    expect(match.state, MatchStates.confirmed);
    expect(match.confirmedAt, isNotNull);
    // Provisional K=32, even ratings: winner +16, loser -16.
    expect(match.eloBefore, {'u1': 1200, 'u2': 1200});
    expect(match.eloDeltas, {'u1': 16, 'u2': -16});

    final u1 = await ratingById('u1');
    expect(u1.elo, 1216);
    expect(u1.matchesPlayed, 1);
    final u2 = await ratingById('u2');
    expect(u2.elo, 1184);
    expect(u2.matchesPlayed, 1);

    final fac = await facility();
    expect(fac.status, FacilityStatus.free);
    expect(fac.currentMatchId, isNull);
  });

  test(
    'confirmResult throws if the match is not awaiting confirmation',
    () async {
      final id = await repository.createMatch(_match()); // still occupied
      await seedRating('u1');
      await seedRating('u2');

      expect(
        () => repository.confirmResult(matchId: id),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'confirmResult on an idle rating confirms from the decayed base',
    () async {
      final id = await repository.createMatch(_match());
      await repository.submitResult(
        matchId: id,
        submittedByUid: 'u1',
        result: const PingPongResult(
          winnerIds: ['u1'],
          sets: [11],
          opponentSets: [5],
        ),
      );
      // Winner idle 90 days at 1300 → decays 60 pts (90-30) to 1240 before rating.
      await seedRating(
        'u1',
        elo: 1300,
        matchesPlayed: 20,
        lastMatchAt: DateTime(2026, 4, 6, 10),
      );
      await seedRating('u2', elo: 1200, matchesPlayed: 20);

      await repository.confirmResult(
        matchId: id,
        now: DateTime(2026, 7, 5, 10),
      );

      final match = await matchById(id);
      // eloBefore snapshots the decayed value, not the stored 1300.
      expect(match.eloBefore!['u1'], 1240);
      final u1 = await ratingById('u1');
      // Established K=16, expected ~0.557 → +7 from the decayed 1240.
      expect(u1.elo, 1247);
    },
  );

  test('confirmResult applies the tournament ELO multiplier', () async {
    await firestore.collection(FirestoreCollections.tournaments).doc('t1').set({
      'eloMultiplier': 2.0,
    });
    final id = await repository.createMatch(_match());
    await repository.submitResult(
      matchId: id,
      submittedByUid: 'u1',
      result: const PingPongResult(
        winnerIds: ['u1'],
        sets: [11],
        opponentSets: [5],
      ),
    );
    // Attach the tournament to the match.
    await firestore.collection(FirestoreCollections.matches).doc(id).update({
      'tournamentId': 't1',
    });
    await seedRating('u1');
    await seedRating('u2');

    await repository.confirmResult(matchId: id);

    // K=32, even ratings, μ=2.0 → 32 * 2 * 0.5 = 32.
    final match = await matchById(id);
    expect(match.eloDeltas, {'u1': 32, 'u2': -32});
  });

  test('confirmResult rates the 10th match at K=32 (before-count)', () async {
    final id = await repository.createMatch(_match());
    await repository.submitResult(
      matchId: id,
      submittedByUid: 'u1',
      result: const PingPongResult(
        winnerIds: ['u1'],
        sets: [11],
        opponentSets: [5],
      ),
    );
    // 9 played means this is the 10th — still provisional K=32.
    await seedRating('u1', matchesPlayed: 9);
    await seedRating('u2', matchesPlayed: 9);

    await repository.confirmResult(matchId: id);

    final match = await matchById(id);
    expect(match.eloDeltas!['u1'], 16); // 32 * 0.5
    expect((await ratingById('u1')).matchesPlayed, 10);
  });

  test('disputeResult marks disputed and frees facility without elo', () async {
    final id = await repository.createMatch(_match());
    await repository.submitResult(
      matchId: id,
      submittedByUid: 'u1',
      result: const PingPongResult(
        winnerIds: ['u1'],
        sets: [11],
        opponentSets: [5],
      ),
    );

    await repository.disputeResult(matchId: id, disputingUid: 'u2');

    final match = await matchById(id);
    expect(match.state, MatchStates.disputed);
    expect(match.eloDeltas, isNull);

    final fac = await facility();
    expect(fac.status, FacilityStatus.free);
  });

  group('watchUserMatches', () {
    // Seed three matches for u1 at increasing times, bypassing createMatch's
    // single-facility occupancy guard by writing docs directly.
    Future<void> seedHistory() async {
      final col = firestore.collection(FirestoreCollections.matches);
      for (var i = 0; i < 3; i++) {
        await col
            .doc('m$i')
            .set(
              _match(
                id: 'm$i',
                state: MatchStates.confirmed,
              ).copyWith(startedAt: DateTime(2026, 6, 30, 10 + i)).toMap(),
            );
      }
    }

    test('limit caps to the newest N, ordered desc', () async {
      await seedHistory();

      final matches = await repository.watchUserMatches('u1', limit: 2).first;

      expect(matches.map((m) => m.matchId), ['m2', 'm1']);
    });

    test('without limit returns the full history', () async {
      await seedHistory();

      final matches = await repository.watchUserMatches('u1').first;

      expect(matches.length, 3);
    });
  });

  // Drives a match to `awaitingConfirmation` with u1 as the submitted winner.
  Future<String> awaitingMatch() async {
    final id = await repository.createMatch(_match());
    await repository.submitResult(
      matchId: id,
      submittedByUid: 'u1',
      result: const PingPongResult(
        winnerIds: ['u1'],
        sets: [11],
        opponentSets: [5],
      ),
    );
    return id;
  }

  test('watchActiveMatchForFacility ignores resolved matches', () async {
    final id = await awaitingMatch();
    final active = await repository.watchActiveMatchForFacility('f1').first;
    expect(active!.matchId, id);

    await repository.disputeResult(matchId: id, disputingUid: 'u2');
    final afterResolve = await repository
        .watchActiveMatchForFacility('f1')
        .first;
    expect(afterResolve, isNull);
  });

  group('getActiveMatchForFacility', () {
    test('resolves the match the facility currentMatchId points at', () async {
      final id = await repository.createMatch(_match());
      final active = await repository.getActiveMatchForFacility('f1');
      expect(active!.matchId, id);
    });

    test('returns null once the pointed-at match has resolved', () async {
      final id = await awaitingMatch();
      await repository.disputeResult(matchId: id, disputingUid: 'u2');
      final active = await repository.getActiveMatchForFacility('f1');
      expect(active, isNull);
    });

    test('returns null when the facility has no currentMatchId', () async {
      final active = await repository.getActiveMatchForFacility('f1');
      expect(active, isNull);
    });

    test('returns null when currentMatchId dangles to a deleted doc', () async {
      await repository.createMatch(_match());
      await firestore
          .collection(FirestoreCollections.facilities)
          .doc('f1')
          .update({'currentMatchId': 'ghost'});
      final active = await repository.getActiveMatchForFacility('f1');
      expect(active, isNull);
    });

    test(
      'ignores a stale live match doc elsewhere in the collection',
      () async {
        // A leftover occupied doc at the same facility that isn't the one the
        // facility actually points at (e.g. a seed/test artifact) must never be
        // picked up — only the currentMatchId pointer is authoritative.
        await firestore
            .collection(FirestoreCollections.matches)
            .doc('phantom')
            .set(_match(id: 'phantom').toMap());
        final id = await repository.createMatch(_match());
        final active = await repository.getActiveMatchForFacility('f1');
        expect(active!.matchId, id);
      },
    );
  });

  test('disputeResult increments disputeCount for unpenalized user', () async {
    await firestore.collection(FirestoreCollections.users).doc('u2').set({
      'disputeCount': 1,
    });
    final id = await awaitingMatch();
    await repository.disputeResult(matchId: id, disputingUid: 'u2');

    final snap = await firestore
        .collection(FirestoreCollections.users)
        .doc('u2')
        .get();
    expect(snap.data()?['disputeCount'], 2);
  });

  test('disputeResult applies 7-day penalty on 3rd dispute', () async {
    await firestore.collection(FirestoreCollections.users).doc('u2').set({
      'disputeCount': 2,
    });
    final id = await awaitingMatch();
    await repository.disputeResult(matchId: id, disputingUid: 'u2');

    final snap = await firestore
        .collection(FirestoreCollections.users)
        .doc('u2')
        .get();
    expect(snap.data()?['disputeCount'], 0);
    expect(snap.data()?['disputePenaltyUntil'], isNotNull);
  });

  test(
    'disputeResult force-confirms a penalized disputer WITH real ELO',
    () async {
      await firestore.collection(FirestoreCollections.users).doc('u2').set({
        'disputePenaltyUntil': Timestamp.fromDate(
          DateTime(2026, 7, 6, 10), // in the future relative to injected `now`
        ),
      });
      final id = await awaitingMatch();
      await seedRating('u1');
      await seedRating('u2');

      await repository.disputeResult(
        matchId: id,
        disputingUid: 'u2',
        now: DateTime(2026, 7, 5, 10),
      );

      // Intercepted: forced to confirmed and ELO processed normally (not a
      // fallback, but the same computed values as confirmResult).
      final match = await matchById(id);
      expect(match.state, MatchStates.confirmed);
      expect(match.eloDeltas, {'u1': 16, 'u2': -16});
      expect((await ratingById('u1')).elo, 1216);
      expect((await ratingById('u2')).elo, 1184);

      final fac = await facility();
      expect(fac.status, FacilityStatus.free);
    },
  );

  // --- abandonMatch (leave-on-back) ---

  DocumentReference<Map<String, dynamic>> facilityRef() =>
      firestore.collection(FirestoreCollections.facilities).doc('f1');

  test(
    'abandonMatch marks the match abandoned and frees the facility',
    () async {
      final id = await repository.createMatch(_match());

      await repository.abandonMatch(matchId: id, facilityId: 'f1');

      expect((await matchById(id)).state, MatchStates.abandoned);
      final fac = await facility();
      expect(fac.status, FacilityStatus.free);
      expect(fac.currentMatchId, isNull);
      expect(fac.freedAt, isNotNull);
    },
  );

  test(
    'abandonMatch never clobbers a facility pointing at another match',
    () async {
      final id = await repository.createMatch(_match());
      // The table was reassigned to a different match in the meantime.
      await facilityRef().update({'currentMatchId': 'other'});

      await repository.abandonMatch(matchId: id, facilityId: 'f1');

      final fac = await facility();
      expect(fac.currentMatchId, 'other');
      expect(fac.status, FacilityStatus.occupied);
    },
  );

  test('abandonMatch is a no-op once a result has been submitted', () async {
    final id = await repository.createMatch(_match());
    await repository.submitResult(
      matchId: id,
      submittedByUid: 'u1',
      result: const PingPongResult(
        winnerIds: ['u1'],
        sets: [11],
        opponentSets: [5],
      ),
    );

    await repository.abandonMatch(matchId: id, facilityId: 'f1');

    expect((await matchById(id)).state, MatchStates.awaitingConfirmation);
  });

  Future<bool> matchExists(String id) async {
    final snap = await firestore
        .collection(FirestoreCollections.matches)
        .doc(id)
        .get();
    return snap.exists;
  }

  // --- cancelMatch (solo check-in the opponent never joined) ---

  test('cancelMatch deletes the match and frees the facility', () async {
    final id = await repository.createMatch(_match());

    await repository.cancelMatch(matchId: id, facilityId: 'f1');

    expect(await matchExists(id), isFalse);
    final fac = await facility();
    expect(fac.status, FacilityStatus.free);
    expect(fac.currentMatchId, isNull);
    expect(fac.freedAt, isNotNull);
  });

  test(
    'cancelMatch never clobbers a facility pointing at another match',
    () async {
      final id = await repository.createMatch(_match());
      await facilityRef().update({'currentMatchId': 'other'});

      await repository.cancelMatch(matchId: id, facilityId: 'f1');

      final fac = await facility();
      expect(fac.currentMatchId, 'other');
      expect(fac.status, FacilityStatus.occupied);
    },
  );

  test('cancelMatch is a no-op once a result has been submitted', () async {
    final id = await repository.createMatch(_match());
    await repository.submitResult(
      matchId: id,
      submittedByUid: 'u1',
      result: const PingPongResult(
        winnerIds: ['u1'],
        sets: [11],
        opponentSets: [5],
      ),
    );

    await repository.cancelMatch(matchId: id, facilityId: 'f1');

    expect(await matchExists(id), isTrue);
    expect((await matchById(id)).state, MatchStates.awaitingConfirmation);
  });

  // --- queue eviction on claim (§3.4) ---

  Future<void> seedQueue(Map<String, int> byUid) async {
    for (final entry in byUid.entries) {
      await facilityRef()
          .collection(FirestoreCollections.queue)
          .doc(entry.key)
          .set({
            'userId': entry.key,
            'position': entry.value,
            'joinedAt': Timestamp.now(),
          });
    }
  }

  Future<Set<String>> queueUids() async {
    final snap = await facilityRef()
        .collection(FirestoreCollections.queue)
        .get();
    return snap.docs.map((d) => d.id).toSet();
  }

  test('createMatch purges no-show front-runners when free > 5 min', () async {
    await facilityRef().update({
      'freedAt': Timestamp.fromDate(DateTime(2026, 7, 5, 10)),
    });
    await seedQueue({'ghost1': 1, 'ghost2': 2});

    await repository.createMatch(_match(), now: DateTime(2026, 7, 5, 10, 10));

    expect(await queueUids(), isEmpty);
  });

  test('createMatch keeps the queue when the table freed recently', () async {
    await facilityRef().update({
      'freedAt': Timestamp.fromDate(DateTime(2026, 7, 5, 10)),
    });
    await seedQueue({'ghost1': 1});

    await repository.createMatch(_match(), now: DateTime(2026, 7, 5, 10, 3));

    expect(await queueUids(), {'ghost1'});
  });

  test(
    'createMatch deletes the scanning players\' own queue tickets',
    () async {
      // No stale purge (recent free): the only removals are the scanners' own
      // tickets, so the facility can't stay falsely `queued` on a phantom.
      await facilityRef().update({
        'freedAt': Timestamp.fromDate(DateTime(2026, 7, 5, 10, 9)),
      });
      // u1 and u2 are both playerUids of _match(); neither should linger.
      await seedQueue({'u1': 1, 'u2': 2});

      await repository.createMatch(_match(), now: DateTime(2026, 7, 5, 10, 10));

      expect(await queueUids(), isEmpty);
      expect((await facility()).status, FacilityStatus.occupied);
    },
  );

  test(
    'createMatch purges only no-shows ahead of the scanner, keeping those behind',
    () async {
      await facilityRef().update({
        'freedAt': Timestamp.fromDate(DateTime(2026, 7, 5, 10)),
      });
      // Scanner u1 sits at position 2: ghost1 (ahead) is a no-show and is
      // purged; u1's own ticket is dropped; late3 (behind) keeps waiting.
      await seedQueue({'ghost1': 1, 'u1': 2, 'late3': 3});

      await repository.createMatch(_match(), now: DateTime(2026, 7, 5, 10, 10));

      expect(await queueUids(), {'late3'});
      // A survivor behind the scanner keeps the table marked `queued`.
      expect((await facility()).status, FacilityStatus.queued);
    },
  );

  // --- doubles confirm (pair entity, keyed by pairId) ---

  test('confirmResult on doubles rates the pair, keyed by pairId', () async {
    final doubles = MatchModel(
      matchId: 'd1',
      facilityId: 'f1',
      sportId: SportIds.pingPong,
      mode: 'doubles',
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
    await putAwaitingMatch(doubles);
    // Members' singles ratings exist and must be left untouched.
    for (final u in ['u1', 'u2', 'u3', 'u4']) {
      await seedRating(u, elo: 1500, matchesPlayed: 5);
    }

    await repository.confirmResult(matchId: 'd1');

    final match = await matchById('d1');
    // eloBefore/eloDeltas keyed by pairId, not member uids.
    expect(match.eloBefore, {'u1_u2': 1200, 'u3_u4': 1200});
    expect(match.eloDeltas, {'u1_u2': 16, 'u3_u4': -16});

    // The pair rating entities moved…
    expect((await ratingById('u1_u2')).elo, 1216);
    expect((await ratingById('u3_u4')).elo, 1184);
    // …while every member's singles rating is unchanged.
    for (final u in ['u1', 'u2', 'u3', 'u4']) {
      expect((await ratingById(u)).elo, 1500);
    }
  });

  // --- King of the Table (denormalized, decorative) ---

  test('confirmResult crowns the winner when their wins here lead', () async {
    // A prior confirmed win for u1 at this table.
    await firestore
        .collection(FirestoreCollections.matches)
        .doc('old')
        .set(
          _match(id: 'old', state: MatchStates.confirmed)
              .copyWith(
                result: const PingPongResult(
                  winnerIds: ['u1'],
                  sets: [11],
                  opponentSets: [4],
                ),
              )
              .toMap(),
        );
    final id = await awaitingMatch();
    await seedRating('u1');
    await seedRating('u2');

    await repository.confirmResult(matchId: id);

    final fac = await facility();
    // 1 prior win + this one = 2, beating the incumbent (0).
    expect(fac.kingOfTableUid, 'u1');
    expect(fac.kingOfTableWins, 2);
  });

  // --- submitResult guard ---

  test('submitResult throws when the match is no longer occupied', () async {
    final id = await awaitingMatch(); // already awaitingConfirmation

    expect(
      () => repository.submitResult(
        matchId: id,
        submittedByUid: 'u2',
        result: const PingPongResult(
          winnerIds: ['u2'],
          sets: [11],
          opponentSets: [3],
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  // --- lazy timeout transitions ---

  test('resolveTimeout abandons an occupied match older than 4h', () async {
    final id = await repository.createMatch(_match());
    final match = await matchById(id);

    await repository.resolveTimeout(match, now: DateTime(2026, 6, 30, 15));

    expect((await matchById(id)).state, MatchStates.abandoned);
    final fac = await facility();
    expect(fac.status, FacilityStatus.free);
    expect(fac.currentMatchId, isNull);
    expect(fac.freedAt, isNotNull);
  });

  test('resolveTimeout unconfirms an awaiting match older than 24h', () async {
    final id = await awaitingMatch();
    final match = await matchById(id);

    await repository.resolveTimeout(match, now: DateTime(2026, 7, 1, 11));

    expect((await matchById(id)).state, MatchStates.unconfirmed);
    expect((await facility()).status, FacilityStatus.free);
  });

  test('resolveTimeout is a no-op while the match is still fresh', () async {
    final id = await repository.createMatch(_match());
    final match = await matchById(id);

    await repository.resolveTimeout(match, now: DateTime(2026, 6, 30, 11));

    expect((await matchById(id)).state, MatchStates.occupied);
    expect((await facility()).status, FacilityStatus.occupied);
  });

  group('getTournamentMatches', () {
    Future<void> putMatch(String id, {String? tournamentId}) {
      return firestore
          .collection(FirestoreCollections.matches)
          .doc(id)
          .set(
            MatchModel(
              matchId: id,
              facilityId: 'f1',
              sportId: SportIds.pingPong,
              mode: 'singles',
              playerUids: const ['u1', 'u2'],
              state: MatchStates.confirmed,
              tournamentId: tournamentId,
              startedAt: DateTime(2026, 6, 30, 10),
            ).toMap(),
          );
    }

    test('returns only the matches for the given tournament', () async {
      await putMatch('m1', tournamentId: 't1');
      await putMatch('m2', tournamentId: 't1');
      await putMatch('m3', tournamentId: 't2');
      await putMatch('m4'); // non-tournament match

      final matches = await repository.getTournamentMatches('t1');

      expect(matches.map((m) => m.matchId).toSet(), {'m1', 'm2'});
    });

    test('respects the limit bound', () async {
      for (var i = 0; i < 5; i++) {
        await putMatch('m$i', tournamentId: 't1');
      }

      final matches = await repository.getTournamentMatches('t1', limit: 3);

      expect(matches.length, 3);
    });
  });

  group('watchTournamentMatches', () {
    Future<void> putMatch(
      String id, {
      String? tournamentId,
      String state = MatchStates.confirmed,
    }) {
      return firestore
          .collection(FirestoreCollections.matches)
          .doc(id)
          .set(
            MatchModel(
              matchId: id,
              facilityId: 'f1',
              sportId: SportIds.pingPong,
              mode: 'singles',
              playerUids: const ['u1', 'u2'],
              state: state,
              tournamentId: tournamentId,
              startedAt: DateTime(2026, 6, 30, 10),
            ).toMap(),
          );
    }

    test('emits only the matches for the given tournament', () async {
      await putMatch('m1', tournamentId: 't1');
      await putMatch('m2', tournamentId: 't2');

      final matches = await repository.watchTournamentMatches('t1').first;

      expect(matches.map((m) => m.matchId).toSet(), {'m1'});
    });

    test('re-emits when a bracket match transitions to confirmed', () async {
      await putMatch(
        'm1',
        tournamentId: 't1',
        state: MatchStates.awaitingConfirmation,
      );

      final updates = repository.watchTournamentMatches('t1').take(2).toList();

      await putMatch('m1', tournamentId: 't1', state: MatchStates.confirmed);

      final emissions = await updates;
      expect(emissions.last.single.state, MatchStates.confirmed);
    });
  });

  group('joinMatch tournament context', () {
    // A live singles table with one player and an open slot, plus its facility
    // pointing at it — the precondition for the second player joining.
    Future<void> putOpenSolo({String? tournamentId}) async {
      await firestore
          .collection(FirestoreCollections.matches)
          .doc('m1')
          .set(
            MatchModel(
              matchId: 'm1',
              facilityId: 'f1',
              sportId: SportIds.pingPong,
              mode: 'singles',
              playerUids: const ['u1'],
              state: MatchStates.occupied,
              tournamentId: tournamentId,
              startedAt: DateTime(2026, 6, 30, 10),
            ).toMap(),
          );
      await firestore
          .collection(FirestoreCollections.facilities)
          .doc('f1')
          .update({'status': FacilityStatus.occupied, 'currentMatchId': 'm1'});
    }

    test('patches context onto a context-free joined match', () async {
      await putOpenSolo();

      await repository.joinMatch(
        facilityId: 'f1',
        uid: 'u2',
        tournamentId: 't1',
        tournamentRound: 'final',
      );

      final m = await matchById('m1');
      expect(m.playerUids, ['u1', 'u2']);
      expect(m.tournamentId, 't1');
      expect(m.tournamentRound, 'final');
    });

    test('never overwrites an existing tournamentId', () async {
      await putOpenSolo(tournamentId: 'real');

      await repository.joinMatch(
        facilityId: 'f1',
        uid: 'u2',
        tournamentId: 't1',
        tournamentRound: 'final',
      );

      final m = await matchById('m1');
      expect(m.tournamentId, 'real');
      expect(m.playerUids, ['u1', 'u2']);
    });

    test('a plain walk-up join writes no tournament context', () async {
      await putOpenSolo();

      await repository.joinMatch(facilityId: 'f1', uid: 'u2');

      final m = await matchById('m1');
      expect(m.tournamentId, isNull);
      expect(m.tournamentRound, isNull);
    });
  });

  group('joinMatch doubles side assignment', () {
    // A live doubles table created by u1 on Team 1 (seeded as a 1-member
    // pairId), with the facility pointing at it.
    Future<void> putOpenDoubles() async {
      await firestore
          .collection(FirestoreCollections.matches)
          .doc('m1')
          .set(
            MatchModel(
              matchId: 'm1',
              facilityId: 'f1',
              sportId: SportIds.pingPong,
              mode: MatchModes.doubles,
              playerUids: const ['u1'],
              team1PairId: 'u1',
              state: MatchStates.occupied,
              startedAt: DateTime(2026, 6, 30, 10),
            ).toMap(),
          );
      await firestore
          .collection(FirestoreCollections.facilities)
          .doc('f1')
          .update({'status': FacilityStatus.occupied, 'currentMatchId': 'm1'});
    }

    test(
      'a joiner is placed on their chosen side as a sorted pairId',
      () async {
        await putOpenDoubles();

        await repository.joinMatch(facilityId: 'f1', uid: 'u3', team: 2);
        await repository.joinMatch(facilityId: 'f1', uid: 'u2', team: 1);

        final m = await matchById('m1');
        expect(m.playerUids, ['u1', 'u3', 'u2']);
        // Team 1 grows to the sorted join of both members; Team 2 has one.
        expect(m.team1PairId, 'u1_u2');
        expect(m.team2PairId, 'u3');
      },
    );

    test(
      'joining a full side throws and leaves the roster untouched',
      () async {
        await putOpenDoubles();
        await repository.joinMatch(facilityId: 'f1', uid: 'u2', team: 1);

        // Team 1 already holds u1 + u2 — a third pick of Team 1 is rejected.
        await expectLater(
          repository.joinMatch(facilityId: 'f1', uid: 'u3', team: 1),
          throwsStateError,
        );

        final m = await matchById('m1');
        expect(m.playerUids, ['u1', 'u2']);
        expect(m.team1PairId, 'u1_u2');
        expect(m.team2PairId, isNull);
      },
    );
  });

  group('watchPairMatches', () {
    test('returns only matches where the pair is a side', () async {
      final matches = firestore.collection(FirestoreCollections.matches);
      // Ours: u1+u2 vs u3+u4.
      await matches
          .doc('ours')
          .set(
            MatchModel(
              matchId: 'ours',
              facilityId: 'f1',
              sportId: SportIds.pingPong,
              mode: MatchModes.doubles,
              playerUids: const ['u1', 'u2', 'u3', 'u4'],
              team1PairId: 'u1_u2',
              team2PairId: 'u3_u4',
              state: MatchStates.confirmed,
              startedAt: DateTime(2026, 7, 2, 10),
            ).toMap(),
          );
      // u1 with a different partner — must NOT match the u1_u2 pair.
      await matches
          .doc('other')
          .set(
            MatchModel(
              matchId: 'other',
              facilityId: 'f1',
              sportId: SportIds.pingPong,
              mode: MatchModes.doubles,
              playerUids: const ['u1', 'u9', 'u3', 'u4'],
              team1PairId: 'u1_u9',
              team2PairId: 'u3_u4',
              state: MatchStates.confirmed,
              startedAt: DateTime(2026, 7, 1, 10),
            ).toMap(),
          );

      final result = await repository.watchPairMatches('u1_u2', 'u1').first;
      expect(result.map((m) => m.matchId), ['ours']);
    });
  });

  // --- achievements (client-side eval folded into the confirm transaction) ---

  group('confirmResult achievements', () {
    Future<void> seedDefs() async {
      final defs = <String, Map<String, dynamic>>{
        'first_victory': {'condition': 'first_victory', 'threshold': null},
        'streak_5': {'condition': 'win_streak', 'threshold': 5},
        'giant_slayer': {'condition': 'giant_slayer', 'threshold': 200},
        'explorer': {'condition': 'explorer', 'threshold': null},
        'tournament_champion': {
          'condition': 'tournament_champion',
          'threshold': null,
        },
        'workaholic': {'condition': 'monthly_count', 'threshold': 15},
      };
      for (final entry in defs.entries) {
        await firestore
            .collection(FirestoreCollections.achievementDefs)
            .doc(entry.key)
            .set({
              'nameKey': 'achievement_${entry.key}_name',
              'descriptionKey': 'achievement_${entry.key}_desc',
              'iconAsset': 'assets/badges/${entry.key}.png',
              ...entry.value,
            });
      }
    }

    Future<Map<String, DateTime>> badgesOf(String uid) async {
      final snap = await firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .get();
      final raw = (snap.data()?['badges'] as Map?) ?? const {};
      return raw.map(
        (k, v) => MapEntry(k as String, (v as Timestamp).toDate()),
      );
    }

    test(
      'a qualifying confirm writes badges.{id} in the transaction and returns it',
      () async {
        await seedDefs();
        final id = await awaitingMatch(); // u1 beats u2, first win each
        await seedRating('u1');
        await seedRating('u2');

        final unlocked = await repository.confirmResult(matchId: id);

        // The confirming winner's first ranked win → first_victory.
        expect(unlocked['u1'], contains('first_victory'));
        final badges = await badgesOf('u1');
        expect(badges.containsKey('first_victory'), isTrue);
        expect(badges['first_victory'], isA<DateTime>());
      },
    );

    test('a non-qualifying confirm writes no badge for that player', () async {
      await seedDefs();
      // A second facility u1 never played keeps Explorer from firing on the
      // single-table campus, isolating the (absent) win-based badges.
      await firestore
          .collection(FirestoreCollections.facilities)
          .doc('f2')
          .set(
            const FacilityModel(
              facilityId: 'f2',
              name: 'Table 2',
              sportId: SportIds.pingPong,
              coordinates: Coordinates(latitude: 45.47, longitude: 9.22),
              qrCode: 'qr_f2',
              fallbackCode: 'FBf2',
              isOutdoor: false,
              status: FacilityStatus.free,
              kingOfTableWins: 0,
              queueTailPosition: 0,
            ).toMap(),
          );
      // u2 already owns first_victory from before — losing here earns nothing.
      final id = await awaitingMatch();
      await seedRating('u1');
      await seedRating('u2');

      final unlocked = await repository.confirmResult(matchId: id);

      // The loser u2 earned nothing (no win, explorer incomplete).
      expect(unlocked['u2'], anyOf(isNull, isEmpty));
      expect((await badgesOf('u2')).containsKey('first_victory'), isFalse);
    });

    test(
      're-satisfying an owned badge writes nothing and preserves its timestamp',
      () async {
        await seedDefs();
        // An unvisited f2 keeps Explorer from firing.
        await firestore
            .collection(FirestoreCollections.facilities)
            .doc('f2')
            .set(
              const FacilityModel(
                facilityId: 'f2',
                name: 'Table 2',
                sportId: SportIds.pingPong,
                coordinates: Coordinates(latitude: 45.47, longitude: 9.22),
                qrCode: 'qr_f2',
                fallbackCode: 'FBf2',
                isOutdoor: false,
                status: FacilityStatus.free,
                kingOfTableWins: 0,
                queueTailPosition: 0,
              ).toMap(),
            );
        // u1 already holds first_victory with a fixed original timestamp.
        final original = DateTime(2026, 1, 1, 9);
        await firestore.collection(FirestoreCollections.users).doc('u1').set({
          'badges': {'first_victory': Timestamp.fromDate(original)},
        });
        final id = await awaitingMatch();
        await seedRating('u1');
        await seedRating('u2');

        final unlocked = await repository.confirmResult(matchId: id);

        // Write-once: first_victory is owned → not re-emitted, not re-written.
        expect(
          unlocked['u1'] ?? const <String>{},
          isNot(contains('first_victory')),
        );
        expect((await badgesOf('u1'))['first_victory'], original);
      },
    );

    test('confirm still succeeds when no definitions are seeded', () async {
      // No achievementDefs → evaluation is skipped entirely, confirm unaffected.
      final id = await awaitingMatch();
      await seedRating('u1');
      await seedRating('u2');

      final unlocked = await repository.confirmResult(matchId: id);

      expect(unlocked, isEmpty);
      expect((await matchById(id)).state, MatchStates.confirmed);
    });
  });
}
