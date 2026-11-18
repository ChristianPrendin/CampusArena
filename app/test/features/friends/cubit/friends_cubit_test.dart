import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/features/friends/cubit/friends_cubit.dart';
import 'package:campus_arena/features/friends/cubit/friends_state.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUserRepository extends Mock implements UserRepository {}

const _me = 'me';

UserModel _user(
  String uid,
  String username, {
  List<String> friendUids = const [],
}) => UserModel(
  uid: uid,
  name: username,
  username: username,
  email: '$uid@polimi.it',
  degreeProgram: 'Computer Science',
  language: 'en',
  pushTokens: const [],
  friendUids: friendUids,
  badges: const {},
  onboardingComplete: true,
  createdAt: DateTime(2026),
);

/// Flushes pending microtasks so a stream-listener emit lands before the next
/// action reads cubit-internal state.
Future<void> _flush() => Future<void>.delayed(Duration.zero);

/// Longer than the cubit's 300ms search debounce.
const _afterDebounce = Duration(milliseconds: 350);

void main() {
  late MockUserRepository repository;
  late StreamController<UserModel?> userController;

  setUp(() {
    repository = MockUserRepository();
    userController = StreamController<UserModel?>();
    when(
      () => repository.watchUser(_me),
    ).thenAnswer((_) => userController.stream);
  });

  tearDown(() => userController.close());

  test('initial state is loading, emitted synchronously', () {
    final cubit = FriendsCubit(uid: _me, userRepository: repository);
    expect(cubit.state.status, FriendsStatus.loading);
    expect(cubit.state.friends, isEmpty);
    cubit.close();
  });

  blocTest<FriendsCubit, FriendsState>(
    'search proposes matching players after the debounce',
    setUp: () {
      when(() => repository.searchUsers('ali')).thenAnswer(
        (_) async => [_user('u_alice', 'alice'), _user('u_al', 'Alina')],
      );
    },
    build: () => FriendsCubit(uid: _me, userRepository: repository),
    act: (cubit) async {
      userController.add(_user(_me, 'me'));
      await _flush();
      cubit.search('ali');
    },
    wait: _afterDebounce,
    expect: () => [
      isA<FriendsState>().having(
        (s) => s.status,
        'status',
        FriendsStatus.ready,
      ),
      isA<FriendsState>().having((s) => s.searchQuery, 'query', 'ali'),
      isA<FriendsState>().having(
        (s) => s.searchStatus,
        'searchStatus',
        FriendSearchStatus.searching,
      ),
      isA<FriendsState>()
          .having(
            (s) => s.searchStatus,
            'searchStatus',
            FriendSearchStatus.done,
          )
          .having(
            (s) => s.searchResults.map((u) => u.username).toList(),
            'results',
            ['alice', 'Alina'],
          ),
    ],
    verify: (_) => verify(() => repository.searchUsers('ali')).called(1),
  );

  blocTest<FriendsCubit, FriendsState>(
    'a blank query clears the search overlay back to idle',
    build: () => FriendsCubit(uid: _me, userRepository: repository),
    act: (cubit) async {
      userController.add(_user(_me, 'me'));
      await _flush();
      cubit.search('  ');
    },
    // A blank query never leaves the idle defaults, so it collapses to a
    // single new state (the query text) rather than a search/idle round-trip.
    expect: () => [
      isA<FriendsState>().having(
        (s) => s.status,
        'status',
        FriendsStatus.ready,
      ),
      isA<FriendsState>()
          .having((s) => s.searchQuery, 'query', '  ')
          .having(
            (s) => s.searchStatus,
            'searchStatus',
            FriendSearchStatus.idle,
          )
          .having((s) => s.searchResults, 'results', isEmpty),
    ],
    verify: (_) => verifyNever(() => repository.searchUsers(any())),
  );

  blocTest<FriendsCubit, FriendsState>(
    'a failed search emits the failed status',
    setUp: () {
      when(() => repository.searchUsers('ali')).thenThrow(Exception('offline'));
    },
    build: () => FriendsCubit(uid: _me, userRepository: repository),
    act: (cubit) async {
      userController.add(_user(_me, 'me'));
      await _flush();
      cubit.search('ali');
    },
    wait: _afterDebounce,
    expect: () => [
      isA<FriendsState>().having(
        (s) => s.status,
        'status',
        FriendsStatus.ready,
      ),
      isA<FriendsState>().having((s) => s.searchQuery, 'query', 'ali'),
      isA<FriendsState>().having(
        (s) => s.searchStatus,
        'searchStatus',
        FriendSearchStatus.searching,
      ),
      isA<FriendsState>().having(
        (s) => s.searchStatus,
        'searchStatus',
        FriendSearchStatus.failed,
      ),
    ],
  );

  blocTest<FriendsCubit, FriendsState>(
    'addFriend writes the friendship and emits added',
    setUp: () {
      when(() => repository.addFriend(_me, 'u_alice')).thenAnswer((_) async {});
    },
    build: () => FriendsCubit(uid: _me, userRepository: repository),
    act: (cubit) async {
      userController.add(_user(_me, 'me'));
      await _flush();
      await cubit.addFriend(_user('u_alice', 'alice'));
    },
    expect: () => [
      isA<FriendsState>().having(
        (s) => s.status,
        'status',
        FriendsStatus.ready,
      ),
      isA<FriendsState>()
          .having((s) => s.addStatus, 'addStatus', FriendAddStatus.added)
          .having((s) => s.addedUsername, 'addedUsername', 'alice'),
    ],
    verify: (_) => verify(() => repository.addFriend(_me, 'u_alice')).called(1),
  );

  blocTest<FriendsCubit, FriendsState>(
    'addFriend is a no-op for yourself or an existing friend',
    setUp: () {
      when(
        () => repository.getUsersByIds(['u_bob']),
      ).thenAnswer((_) async => [_user('u_bob', 'bob')]);
    },
    build: () => FriendsCubit(uid: _me, userRepository: repository),
    act: (cubit) async {
      userController.add(_user(_me, 'me', friendUids: const ['u_bob']));
      await _flush();
      await cubit.addFriend(_user(_me, 'me')); // yourself
      await cubit.addFriend(_user('u_bob', 'bob')); // already a friend
    },
    expect: () => [
      isA<FriendsState>()
          .having((s) => s.status, 'status', FriendsStatus.ready)
          .having((s) => s.friends.map((u) => u.uid).toList(), 'friends', [
            'u_bob',
          ]),
    ],
    verify: (_) => verifyNever(() => repository.addFriend(any(), any())),
  );

  blocTest<FriendsCubit, FriendsState>(
    'two consecutive adds each bump addTick so both fire the snackbar',
    setUp: () {
      when(() => repository.addFriend(_me, 'u_alice')).thenAnswer((_) async {});
      when(() => repository.addFriend(_me, 'u_bob')).thenAnswer((_) async {});
    },
    build: () => FriendsCubit(uid: _me, userRepository: repository),
    act: (cubit) async {
      userController.add(_user(_me, 'me'));
      await _flush();
      await cubit.addFriend(_user('u_alice', 'alice'));
      await cubit.addFriend(_user('u_bob', 'bob'));
    },
    // Both adds keep addStatus == added, so it's addTick (1 then 2) that makes
    // each a distinct state the listener can react to.
    expect: () => [
      isA<FriendsState>().having(
        (s) => s.status,
        'status',
        FriendsStatus.ready,
      ),
      isA<FriendsState>()
          .having((s) => s.addedUsername, 'addedUsername', 'alice')
          .having((s) => s.addTick, 'addTick', 1),
      isA<FriendsState>()
          .having((s) => s.addedUsername, 'addedUsername', 'bob')
          .having((s) => s.addTick, 'addTick', 2),
    ],
  );

  blocTest<FriendsCubit, FriendsState>(
    'addFriend surfaces a failed write',
    setUp: () {
      when(
        () => repository.addFriend(_me, 'u_alice'),
      ).thenThrow(Exception('offline'));
    },
    build: () => FriendsCubit(uid: _me, userRepository: repository),
    act: (cubit) async {
      userController.add(_user(_me, 'me'));
      await _flush();
      await cubit.addFriend(_user('u_alice', 'alice'));
    },
    expect: () => [
      isA<FriendsState>().having(
        (s) => s.status,
        'status',
        FriendsStatus.ready,
      ),
      isA<FriendsState>().having(
        (s) => s.addStatus,
        'addStatus',
        FriendAddStatus.failed,
      ),
    ],
  );

  blocTest<FriendsCubit, FriendsState>(
    'remove delegates to the repository',
    setUp: () {
      when(
        () => repository.getUsersByIds(['u_bob']),
      ).thenAnswer((_) async => [_user('u_bob', 'bob')]);
      when(
        () => repository.removeFriend(_me, 'u_bob'),
      ).thenAnswer((_) async {});
    },
    build: () => FriendsCubit(uid: _me, userRepository: repository),
    act: (cubit) async {
      userController.add(_user(_me, 'me', friendUids: const ['u_bob']));
      await _flush();
      await cubit.removeFriend('u_bob');
    },
    verify: (_) =>
        verify(() => repository.removeFriend(_me, 'u_bob')).called(1),
  );

  blocTest<FriendsCubit, FriendsState>(
    'friends stream update re-emits the resolved list',
    setUp: () {
      when(
        () => repository.getUsersByIds(['u_amy']),
      ).thenAnswer((_) async => [_user('u_amy', 'amy')]);
      when(
        () => repository.getUsersByIds(['u_zoe']),
      ).thenAnswer((_) async => [_user('u_zoe', 'zoe')]);
    },
    build: () => FriendsCubit(uid: _me, userRepository: repository),
    act: (cubit) async {
      userController.add(_user(_me, 'me', friendUids: const ['u_amy']));
      await _flush();
      userController.add(
        _user(_me, 'me', friendUids: const ['u_amy', 'u_zoe']),
      );
      await _flush();
    },
    expect: () => [
      isA<FriendsState>().having(
        (s) => s.friends.map((u) => u.uid).toList(),
        'friends',
        ['u_amy'],
      ),
      isA<FriendsState>().having(
        (s) => s.friends.map((u) => u.uid).toList(),
        'friends',
        ['u_amy', 'u_zoe'],
      ),
    ],
  );
}
