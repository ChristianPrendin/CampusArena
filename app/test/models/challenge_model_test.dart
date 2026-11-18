import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_arena/models/challenge_model.dart';

void main() {
  group('ChallengeModel tests', () {
    final now = DateTime.now();
    final nowTimestamp = Timestamp.fromDate(now);

    final rawMap = {
      'fromUserId': 'uid_1',
      'toUserId': 'uid_2',
      'sportId': 'ping_pong',
      'status': 'accepted',
      'matchId': 'match_xyz',
      'createdAt': nowTimestamp,
      'respondedAt': nowTimestamp,
    };

    test('should parse correctly fromMap', () {
      final challenge = ChallengeModel.fromMap(rawMap, 'chall_1');

      expect(challenge.challengeId, 'chall_1');
      expect(challenge.fromUserId, 'uid_1');
      expect(challenge.toUserId, 'uid_2');
      expect(challenge.sportId, 'ping_pong');
      expect(challenge.status, 'accepted');
      expect(challenge.matchId, 'match_xyz');
      expect(challenge.createdAt, now);
      expect(challenge.respondedAt, now);
    });

    test('should fallback to defaults in fromMap', () {
      final challenge = ChallengeModel.fromMap(const {}, 'chall_1');

      expect(challenge.challengeId, 'chall_1');
      expect(challenge.fromUserId, '');
      expect(challenge.toUserId, '');
      expect(challenge.sportId, '');
      expect(challenge.status, 'pending');
      expect(challenge.matchId, isNull);
      expect(challenge.respondedAt, isNull);
    });

    test('should serialize correctly toMap', () {
      final challenge = ChallengeModel(
        challengeId: 'chall_1',
        fromUserId: 'uid_1',
        toUserId: 'uid_2',
        sportId: 'ping_pong',
        status: 'accepted',
        matchId: 'match_xyz',
        createdAt: now,
        respondedAt: now,
      );

      final map = challenge.toMap();

      expect(map['fromUserId'], 'uid_1');
      expect(map['toUserId'], 'uid_2');
      expect(map['sportId'], 'ping_pong');
      expect(map['status'], 'accepted');
      expect(map['matchId'], 'match_xyz');
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate(), now);
      expect(map['respondedAt'], isA<Timestamp>());
      expect((map['respondedAt'] as Timestamp).toDate(), now);
    });

    test('should serialize correctly toMap when respondedAt is null', () {
      final challenge = ChallengeModel(
        challengeId: 'chall_1',
        fromUserId: 'uid_1',
        toUserId: 'uid_2',
        sportId: 'ping_pong',
        status: 'pending',
        createdAt: now,
      );

      final map = challenge.toMap();

      expect(map['respondedAt'], isNull);
    });

    test('should support copyWith', () {
      final challenge = ChallengeModel(
        challengeId: 'chall_1',
        fromUserId: 'uid_1',
        toUserId: 'uid_2',
        sportId: 'ping_pong',
        status: 'pending',
        createdAt: now,
      );

      final updated = challenge.copyWith(status: 'declined', respondedAt: now);
      expect(updated.status, 'declined');
      expect(updated.respondedAt, now);
      expect(updated.challengeId, 'chall_1');
    });
  });
}
