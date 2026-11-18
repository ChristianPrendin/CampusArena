import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_arena/models/user_model.dart';

void main() {
  group('UserModel tests', () {
    final now = DateTime.now();
    final nowTimestamp = Timestamp.fromDate(now);

    final rawMap = {
      'name': 'Mirko Pica',
      'username': 'mirkop',
      'email': 'mirko@mail.polimi.it',
      'degreeProgram': 'Computer Science',
      'language': 'it',
      'pushTokens': ['token123', 'token456'],
      'friendUids': ['uid2', 'uid3'],
      'badges': {'first_victory': nowTimestamp},
      'onboardingComplete': true,
      'createdAt': nowTimestamp,
    };

    test('should parse correctly fromMap', () {
      final user = UserModel.fromMap(rawMap, 'uid1');

      expect(user.uid, 'uid1');
      expect(user.name, 'Mirko Pica');
      expect(user.username, 'mirkop');
      expect(user.email, 'mirko@mail.polimi.it');
      expect(user.degreeProgram, 'Computer Science');
      expect(user.language, 'it');
      expect(user.pushTokens, ['token123', 'token456']);
      expect(user.friendUids, ['uid2', 'uid3']);
      expect(user.badges, {'first_victory': now});
      expect(user.onboardingComplete, true);
      expect(user.createdAt, now);
    });

    test('should skip an unresolved (null) badge value in fromMap', () {
      // An optimistic, latency-compensated snapshot can expose a badge written
      // with serverTimestamp() as null under ServerTimestampBehavior.none.
      // The non-nullable Timestamp cast must not throw on it.
      final map = {
        ...rawMap,
        'badges': {'first_victory': nowTimestamp, 'tournament_champion': null},
      };

      final user = UserModel.fromMap(map, 'uid1');

      expect(user.badges, {'first_victory': now});
    });

    test('should fallback to default values for missing fields in fromMap', () {
      final user = UserModel.fromMap(const {}, 'uid1');

      expect(user.uid, 'uid1');
      expect(user.name, '');
      expect(user.username, '');
      expect(user.email, '');
      expect(user.degreeProgram, '');
      expect(user.language, 'en');
      expect(user.pushTokens, isEmpty);
      expect(user.friendUids, isEmpty);
      expect(user.badges, isEmpty);
      expect(user.onboardingComplete, false);
    });

    test('should serialize correctly toMap', () {
      final user = UserModel(
        uid: 'uid1',
        name: 'Mirko Pica',
        username: 'mirkop',
        email: 'mirko@mail.polimi.it',
        degreeProgram: 'Computer Science',
        language: 'it',
        pushTokens: const ['token123', 'token456'],
        friendUids: const ['uid2', 'uid3'],
        badges: {'first_victory': now},
        onboardingComplete: true,
        createdAt: now,
      );

      final map = user.toMap();

      expect(map['name'], 'Mirko Pica');
      expect(map['username'], 'mirkop');
      expect(map['email'], 'mirko@mail.polimi.it');
      expect(map['degreeProgram'], 'Computer Science');
      expect(map['language'], 'it');
      expect(map['pushTokens'], ['token123', 'token456']);
      expect(map['friendUids'], ['uid2', 'uid3']);
      expect(map['badges']['first_victory'], isA<Timestamp>());
      expect((map['badges']['first_victory'] as Timestamp).toDate(), now);
      expect(map['onboardingComplete'], true);
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate(), now);
    });

    test('should support copyWith', () {
      final user = UserModel(
        uid: 'uid1',
        name: 'Mirko Pica',
        username: 'mirkop',
        email: 'mirko@mail.polimi.it',
        degreeProgram: 'Computer Science',
        language: 'it',
        pushTokens: const ['token123', 'token456'],
        friendUids: const ['uid2', 'uid3'],
        badges: {'first_victory': now},
        onboardingComplete: true,
        createdAt: now,
      );

      final updated = user.copyWith(
        name: 'mirko_new',
        username: 'mirkop_new',
        pushTokens: const ['token789'],
        onboardingComplete: false,
      );

      expect(updated.name, 'mirko_new');
      expect(updated.username, 'mirkop_new');
      expect(updated.pushTokens, ['token789']);
      expect(updated.onboardingComplete, false);
      expect(updated.uid, 'uid1'); // unmodified
    });
  });
}
