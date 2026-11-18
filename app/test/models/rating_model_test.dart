import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_arena/models/rating_model.dart';

void main() {
  group('RatingModel tests', () {
    final now = DateTime.now();
    final nowTimestamp = Timestamp.fromDate(now);

    final rawMap = {
      'ownerType': 'user',
      'ownerId': 'uid1',
      'memberUids': null,
      'sportId': 'ping_pong',
      'degreeProgram': 'CS',
      'elo': 1250,
      'matchesPlayed': 12,
      'lastMatchAt': nowTimestamp,
    };

    test('should parse correctly fromMap', () {
      final rating = RatingModel.fromMap(rawMap, 'ping_pong_uid1');

      expect(rating.ratingId, 'ping_pong_uid1');
      expect(rating.ownerType, 'user');
      expect(rating.ownerId, 'uid1');
      expect(rating.memberUids, isNull);
      expect(rating.sportId, 'ping_pong');
      expect(rating.degreeProgram, 'CS');
      expect(rating.elo, 1250);
      expect(rating.matchesPlayed, 12);
      expect(rating.lastMatchAt, now);
    });

    test('should fallback to default values in fromMap', () {
      final rating = RatingModel.fromMap(const {}, 'ping_pong_uid1');

      expect(rating.ratingId, 'ping_pong_uid1');
      expect(rating.ownerType, 'user');
      expect(rating.ownerId, '');
      expect(rating.memberUids, isNull);
      expect(rating.sportId, '');
      expect(rating.degreeProgram, isNull);
      expect(rating.elo, 1200);
      expect(rating.matchesPlayed, 0);
    });

    test('should serialize correctly toMap', () {
      final rating = RatingModel(
        ratingId: 'ping_pong_uid1',
        ownerType: 'user',
        ownerId: 'uid1',
        memberUids: const ['uid1'],
        sportId: 'ping_pong',
        degreeProgram: 'CS',
        elo: 1250,
        matchesPlayed: 12,
        lastMatchAt: now,
      );

      final map = rating.toMap();

      expect(map['ownerType'], 'user');
      expect(map['ownerId'], 'uid1');
      expect(map['memberUids'], ['uid1']);
      expect(map['sportId'], 'ping_pong');
      expect(map['degreeProgram'], 'CS');
      expect(map['elo'], 1250);
      expect(map['matchesPlayed'], 12);
      expect(map['lastMatchAt'], isA<Timestamp>());
      expect((map['lastMatchAt'] as Timestamp).toDate(), now);
    });

    test('should support copyWith', () {
      final rating = RatingModel(
        ratingId: 'ping_pong_uid1',
        ownerType: 'user',
        ownerId: 'uid1',
        sportId: 'ping_pong',
        elo: 1200,
        matchesPlayed: 0,
        lastMatchAt: now,
      );

      final updated = rating.copyWith(elo: 1300, matchesPlayed: 1);

      expect(updated.elo, 1300);
      expect(updated.matchesPlayed, 1);
      expect(updated.ratingId, 'ping_pong_uid1');
    });
  });
}
