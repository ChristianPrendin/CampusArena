import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late RatingRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = RatingRepository(firestore: firestore);
  });

  group('deterministic ids', () {
    test('ratingId is {sportId}_{ownerId}', () {
      expect(RatingRepository.ratingId('ping_pong', 'u1'), 'ping_pong_u1');
    });

    test('pairId is order-independent', () {
      expect(
        RatingRepository.pairId(['u2', 'u1']),
        RatingRepository.pairId(['u1', 'u2']),
      );
      expect(RatingRepository.pairId(['u2', 'u1']), 'u1_u2');
    });
  });

  test(
    'seedUserRatings creates one rating per supported sport at 1200',
    () async {
      await repository.seedUserRatings(uid: 'u1', degreeProgram: 'CS');

      final ratings = await repository.watchUserRatings('u1').first;

      expect(ratings.length, SportIds.supported.length);
      for (final rating in ratings) {
        expect(rating.elo, kInitialElo);
        expect(rating.matchesPlayed, 0);
        expect(rating.ownerType, OwnerType.user);
        expect(rating.degreeProgram, 'CS');
      }
      expect(ratings.map((r) => r.sportId).toSet(), SportIds.supported.toSet());
    },
  );

  test('getUserRating resolves a seeded rating by deterministic id', () async {
    await repository.seedUserRatings(uid: 'u1', degreeProgram: 'CS');

    final rating = await repository.getUserRating('u1', SportIds.pingPong);

    expect(rating, isNotNull);
    expect(rating!.ratingId, 'ping_pong_u1');
  });

  group('getOrCreatePairRating', () {
    test('creates a pair rating at 1200 with sorted members', () async {
      final rating = await repository.getOrCreatePairRating(
        sportId: SportIds.foosball,
        memberUids: ['u2', 'u1'],
      );

      expect(rating.ownerType, OwnerType.pair);
      expect(rating.ownerId, 'u1_u2');
      expect(rating.memberUids, ['u1', 'u2']);
      expect(rating.elo, kInitialElo);
      expect(rating.ratingId, 'foosball_u1_u2');
    });

    test('returns the existing rating on second call (idempotent)', () async {
      final first = await repository.getOrCreatePairRating(
        sportId: SportIds.foosball,
        memberUids: ['u1', 'u2'],
      );
      await repository.updateElo(
        ratingId: first.ratingId,
        elo: 1300,
        matchesPlayed: 4,
        lastMatchAt: DateTime(2026, 6, 30),
      );

      final second = await repository.getOrCreatePairRating(
        sportId: SportIds.foosball,
        memberUids: ['u2', 'u1'],
      );

      expect(second.elo, 1300);
      expect(second.matchesPlayed, 4);
    });
  });

  test('updateElo persists the supplied values', () async {
    await repository.seedUserRatings(uid: 'u1', degreeProgram: 'CS');
    final id = RatingRepository.ratingId(SportIds.pingPong, 'u1');

    await repository.updateElo(
      ratingId: id,
      elo: 1234,
      matchesPlayed: 11,
      lastMatchAt: DateTime(2026, 6, 30),
    );

    final rating = await repository.getRating(id);
    expect(rating!.elo, 1234);
    expect(rating.matchesPlayed, 11);
  });

  test('watchLeaderboard returns user ratings ordered by elo desc', () async {
    await repository.seedUserRatings(uid: 'low', degreeProgram: 'CS');
    await repository.seedUserRatings(uid: 'high', degreeProgram: 'CS');
    await repository.updateElo(
      ratingId: RatingRepository.ratingId(SportIds.pingPong, 'high'),
      elo: 1500,
      matchesPlayed: 5,
      lastMatchAt: DateTime(2026, 6, 30),
    );
    // A pair rating must be excluded from the singles leaderboard.
    await repository.getOrCreatePairRating(
      sportId: SportIds.pingPong,
      memberUids: ['high', 'low'],
    );

    final board = await repository
        .watchLeaderboard(sportId: SportIds.pingPong)
        .first;

    expect(board.map((r) => r.ownerId), ['high', 'low']);
    expect(board.every((r) => r.ownerType == OwnerType.user), isTrue);
  });

  test('watchLeaderboard filters by degree program', () async {
    await repository.seedUserRatings(uid: 'cs', degreeProgram: 'CS');
    await repository.seedUserRatings(uid: 'me', degreeProgram: 'ME');

    final board = await repository
        .watchLeaderboard(sportId: SportIds.pingPong, degreeProgram: 'CS')
        .first;

    expect(board.map((r) => r.ownerId), ['cs']);
  });

  group('getUserRank', () {
    test('is 1 when no user rating has a higher elo', () async {
      await repository.seedUserRatings(uid: 'u1', degreeProgram: 'CS');

      final rank = await repository.getUserRank(
        sportId: SportIds.pingPong,
        elo: kInitialElo,
      );

      expect(rank, 1);
    });

    test(
      'counts only strictly-higher, same-sport, user-owned ratings',
      () async {
        // The player under test sits at 1200.
        await repository.seedUserRatings(uid: 'me', degreeProgram: 'CS');
        // One genuinely higher user rating for the same sport → rank 2.
        await repository.seedUserRatings(uid: 'higher', degreeProgram: 'CS');
        await repository.updateElo(
          ratingId: RatingRepository.ratingId(SportIds.pingPong, 'higher'),
          elo: 1400,
          matchesPlayed: 5,
          lastMatchAt: DateTime(2026, 6, 30),
        );
        // An equal-elo user rating must NOT count (strictly greater only).
        await repository.seedUserRatings(uid: 'equal', degreeProgram: 'CS');
        // A higher-elo OTHER sport rating must not count.
        await repository.updateElo(
          ratingId: RatingRepository.ratingId(SportIds.foosball, 'higher'),
          elo: 1600,
          matchesPlayed: 5,
          lastMatchAt: DateTime(2026, 6, 30),
        );
        // A higher-elo PAIR rating must not count.
        final pair = await repository.getOrCreatePairRating(
          sportId: SportIds.pingPong,
          memberUids: ['me', 'higher'],
        );
        await repository.updateElo(
          ratingId: pair.ratingId,
          elo: 1800,
          matchesPlayed: 5,
          lastMatchAt: DateTime(2026, 6, 30),
        );

        final rank = await repository.getUserRank(
          sportId: SportIds.pingPong,
          elo: kInitialElo,
        );

        expect(rank, 2);
      },
    );

    test('degreeProgram narrows the count to that course', () async {
      // Target sits at 1200 in CS.
      await repository.seedUserRatings(uid: 'me', degreeProgram: 'CS');
      // A higher CS player → counts toward the CS rank.
      await repository.seedUserRatings(uid: 'csHigh', degreeProgram: 'CS');
      await repository.updateElo(
        ratingId: RatingRepository.ratingId(SportIds.pingPong, 'csHigh'),
        elo: 1500,
        matchesPlayed: 5,
        lastMatchAt: DateTime(2026, 6, 30),
      );
      // A higher player on ANOTHER course must be excluded by the filter.
      await repository.seedUserRatings(uid: 'meHigh', degreeProgram: 'ME');
      await repository.updateElo(
        ratingId: RatingRepository.ratingId(SportIds.pingPong, 'meHigh'),
        elo: 1700,
        matchesPlayed: 5,
        lastMatchAt: DateTime(2026, 6, 30),
      );

      final courseRank = await repository.getUserRank(
        sportId: SportIds.pingPong,
        elo: kInitialElo,
        degreeProgram: 'CS',
      );
      // Only 'csHigh' is above within CS → rank 2 (the ME player is ignored).
      expect(courseRank, 2);

      // Without the filter, both higher players count → rank 3.
      final globalRank = await repository.getUserRank(
        sportId: SportIds.pingPong,
        elo: kInitialElo,
      );
      expect(globalRank, 3);
    });

    test('tied players share the same rank', () async {
      // One player above; two tied below it.
      await repository.seedUserRatings(uid: 'top', degreeProgram: 'CS');
      await repository.updateElo(
        ratingId: RatingRepository.ratingId(SportIds.pingPong, 'top'),
        elo: 1500,
        matchesPlayed: 5,
        lastMatchAt: DateTime(2026, 6, 30),
      );
      await repository.seedUserRatings(uid: 'a', degreeProgram: 'CS');
      await repository.seedUserRatings(uid: 'b', degreeProgram: 'CS');

      final rank = await repository.getUserRank(
        sportId: SportIds.pingPong,
        elo: kInitialElo,
      );

      // Both 'a' and 'b' are at 1200: only 'top' is higher, so each is rank 2.
      expect(rank, 2);
    });
  });

  group('getUserRatings', () {
    test('empty input issues no read and returns an empty map', () async {
      expect(await repository.getUserRatings(const [], SportIds.pingPong), {});
    });

    test('batches by uid, skipping uids with no rating doc', () async {
      await repository.seedUserRatings(uid: 'u1', degreeProgram: 'CS');
      await repository.seedUserRatings(uid: 'u2', degreeProgram: 'CS');

      final ratings = await repository.getUserRatings(const [
        'u1',
        'u2',
        'missing',
      ], SportIds.pingPong);

      expect(ratings.keys.toSet(), {'u1', 'u2'});
      expect(ratings['u1']!.ownerId, 'u1');
      expect(ratings['u1']!.elo, kInitialElo);
    });

    test('spans more than 30 uids across whereIn chunks', () async {
      final uids = [for (var i = 0; i < 35; i++) 'u$i'];
      for (final uid in uids) {
        await repository.seedUserRatings(uid: uid, degreeProgram: 'CS');
      }

      final ratings = await repository.getUserRatings(uids, SportIds.pingPong);

      expect(ratings.length, 35);
    });
  });
}
