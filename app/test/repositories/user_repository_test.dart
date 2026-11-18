import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// Username defaults to the uid so every _user is a distinct handle — createUser
// now claims usernames/{username}, so shared literals would collide.
UserModel _user(String uid, {String? username}) => UserModel(
  uid: uid,
  name: 'Ada',
  username: username ?? uid,
  email: 'ada@polimi.it',
  degreeProgram: 'Computer Science',
  language: 'en',
  pushTokens: const ['tok1'],
  friendUids: const [],
  badges: const {},
  onboardingComplete: false,
  createdAt: DateTime(2026, 6, 30),
);

void main() {
  late FakeFirebaseFirestore firestore;
  late UserRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = UserRepository(firestore: firestore);
  });

  test('createUser then getUser round-trips the model', () async {
    await repository.createUser(_user('u1', username: 'ada'));

    final loaded = await repository.getUser('u1');

    expect(loaded, isNotNull);
    expect(loaded!.uid, 'u1');
    expect(loaded.username, 'ada');
    expect(loaded.degreeProgram, 'Computer Science');
    expect(loaded.pushTokens, ['tok1']);
  });

  test('createUser stores the username lowercased', () async {
    await repository.createUser(_user('u1', username: 'Ada'));

    final raw = await firestore.collection('users').doc('u1').get();
    expect(raw.data()!['username'], 'ada');
    expect((await repository.getUser('u1'))!.username, 'ada');
  });

  group('username uniqueness reservation', () {
    test('createUser claims usernames/{handle} with the owner uid', () async {
      await repository.createUser(_user('u1', username: 'ada'));

      final claim = await firestore.collection('usernames').doc('ada').get();
      expect(claim.exists, isTrue);
      expect(claim.data()!['uid'], 'u1');
    });

    test('a duplicate handle throws and writes neither doc', () async {
      await repository.createUser(_user('u1', username: 'ada'));

      await expectLater(
        repository.createUser(_user('u2', username: 'ada')),
        throwsA(isA<UsernameTakenException>()),
      );

      // The original claim is untouched and no u2 doc was created.
      final claim = await firestore.collection('usernames').doc('ada').get();
      expect(claim.data()!['uid'], 'u1');
      expect(await repository.getUser('u2'), isNull);
    });

    test('reservation is case-insensitive: Bob and bob collide', () async {
      await repository.createUser(_user('u1', username: 'Bob'));

      // A differently-cased handle claims the same lowercased doc, so it loses.
      await expectLater(
        repository.createUser(_user('u2', username: 'bob')),
        throwsA(isA<UsernameTakenException>()),
      );

      // The single claim is lowercased and owned by the first registrant.
      final claim = await firestore.collection('usernames').doc('bob').get();
      expect(claim.data()!['uid'], 'u1');
      expect((await repository.getUser('u1'))!.username, 'bob');
      expect(await repository.getUser('u2'), isNull);
    });

    test('the handle is trimmed before it is claimed', () async {
      await repository.createUser(_user('u1', username: '  ada  '));

      final claim = await firestore.collection('usernames').doc('ada').get();
      expect(claim.exists, isTrue);
    });
  });

  test('getUser returns null for a missing doc', () async {
    expect(await repository.getUser('ghost'), isNull);
  });

  test('updateUser applies a partial update', () async {
    await repository.createUser(_user('u1'));

    await repository.updateUser('u1', {'onboardingComplete': true});

    final loaded = await repository.getUser('u1');
    expect(loaded!.onboardingComplete, isTrue);
    expect(loaded.username, 'u1');
  });

  test('watchUser emits the current user and subsequent updates', () async {
    await repository.createUser(_user('u1'));

    final stream = repository.watchUser('u1');
    expectLater(
      stream,
      emitsThrough(predicate<UserModel?>((u) => u?.onboardingComplete == true)),
    );

    await firestore.collection('users').doc('u1').update({
      'onboardingComplete': true,
    });
  });

  group('searchUsers', () {
    UserModel named(String uid, String username) => UserModel(
      uid: uid,
      name: username,
      username: username,
      email: '$uid@polimi.it',
      degreeProgram: 'Design',
      language: 'en',
      pushTokens: const [],
      friendUids: const [],
      badges: const {},
      onboardingComplete: true,
      createdAt: DateTime(2026),
    );

    Future<void> seed() async {
      // Handles seeded with mixed case are stored lowercased by createUser.
      for (final u in [
        named('a', 'alice'),
        named('al', 'Alina'),
        named('b', 'bob'),
        named('am', 'ambra'),
      ]) {
        await repository.createUser(u);
      }
    }

    test('returns only usernames with the given prefix', () async {
      await seed();

      final results = await repository.searchUsers('al');

      expect(results.map((u) => u.username).toSet(), {'alice', 'alina'});
    });

    test('matches case-insensitively via the lowercased prefix', () async {
      await seed();

      // An upper-case query is lowercased before the prefix scan.
      final upper = await repository.searchUsers('AL');
      expect(upper.map((u) => u.username).toSet(), {'alice', 'alina'});
      final lower = await repository.searchUsers('alin');
      expect(lower.single.username, 'alina');
    });

    test('blank query returns nothing without querying', () async {
      await seed();

      expect(await repository.searchUsers(''), isEmpty);
      expect(await repository.searchUsers('   '), isEmpty);
    });

    test('respects the result limit', () async {
      await seed();

      final results = await repository.searchUsers('a', limit: 2);

      expect(results, hasLength(2));
    });

    test('no match returns an empty list', () async {
      await seed();

      expect(await repository.searchUsers('zz'), isEmpty);
    });
  });

  group('getUsersByIds', () {
    test('empty input returns empty without querying', () async {
      expect(await repository.getUsersByIds(const []), isEmpty);
    });

    test('loads the requested users, skipping missing ids', () async {
      await repository.createUser(_user('u1'));
      await repository.createUser(_user('u2'));

      final loaded = await repository.getUsersByIds(['u1', 'ghost', 'u2']);

      expect(loaded.map((u) => u.uid).toSet(), {'u1', 'u2'});
    });

    test('handles more than 30 ids across chunks', () async {
      final ids = [for (var i = 0; i < 65; i++) 'u$i'];
      for (final id in ids) {
        await repository.createUser(_user(id));
      }

      final loaded = await repository.getUsersByIds(ids);

      expect(loaded, hasLength(65));
    });
  });
}
