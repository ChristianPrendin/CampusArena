import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/leaderboards/cubit/leaderboard_cubit.dart';
import 'package:campus_arena/features/leaderboards/cubit/leaderboard_state.dart';
import 'package:campus_arena/models/rating_model.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRatingRepository extends Mock implements RatingRepository {}

class MockUserRepository extends Mock implements UserRepository {}

const _uid = 'me';

RatingModel _rating(
  String ownerId, {
  int elo = kInitialElo,
  String sportId = SportIds.pingPong,
  String? degreeProgram,
}) => RatingModel(
  ratingId: RatingRepository.ratingId(sportId, ownerId),
  ownerType: OwnerType.user,
  ownerId: ownerId,
  sportId: sportId,
  degreeProgram: degreeProgram,
  elo: elo,
  matchesPlayed: 5,
  lastMatchAt: DateTime(2026, 6, 30),
);

UserModel _user(
  String uid, {
  String name = 'Player',
  String degreeProgram = 'Design',
  List<String> friends = const [],
}) => UserModel(
  uid: uid,
  name: name,
  username: name.toLowerCase(),
  email: '$uid@polimi.it',
  degreeProgram: degreeProgram,
  language: 'en',
  pushTokens: const [],
  friendUids: friends,
  badges: const {},
  onboardingComplete: true,
  createdAt: DateTime(2026),
);

/// Matcher on a ready state with the given ordered entry ids.
Matcher _ready(List<String> ownerIds) => isA<LeaderboardState>()
    .having((s) => s.status, 'status', LeaderboardStatus.ready)
    .having(
      (s) => s.entries.map((e) => e.ownerId).toList(),
      'entries',
      ownerIds,
    );

Matcher _loading = isA<LeaderboardState>().having(
  (s) => s.status,
  'status',
  LeaderboardStatus.loading,
);

void main() {
  late MockRatingRepository ratingRepository;
  late MockUserRepository userRepository;

  // Completers shared between a blocTest's setUp and its act (each test assigns
  // its own before use; tests run sequentially so there is no cross-bleed).
  late Completer<UserModel?> userLoadedCompleter;
  late Completer<List<RatingModel>> pingPongFriends;
  late Completer<List<RatingModel>> foosballFriends;

  setUp(() {
    ratingRepository = MockRatingRepository();
    userRepository = MockUserRepository();

    // Quiet defaults: nothing emits unless a test overrides it.
    when(
      () => ratingRepository.watchLeaderboard(
        sportId: any(named: 'sportId'),
        ownerType: any(named: 'ownerType'),
        degreeProgram: any(named: 'degreeProgram'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => ratingRepository.getFriendsLeaderboard(
        sportId: any(named: 'sportId'),
        userAndFriendUids: any(named: 'userAndFriendUids'),
      ),
    ).thenAnswer((_) async => const <RatingModel>[]);
    when(
      () => ratingRepository.getUserRating(any(), any()),
    ).thenAnswer((_) async => null);
    when(
      () => ratingRepository.getUserRatings(any(), any()),
    ).thenAnswer((_) async => const <String, RatingModel>{});
    when(
      () => ratingRepository.getUserRank(
        sportId: any(named: 'sportId'),
        elo: any(named: 'elo'),
        degreeProgram: any(named: 'degreeProgram'),
      ),
    ).thenAnswer((_) async => 1);
    when(() => userRepository.getUser(any())).thenAnswer((_) async => null);
    when(
      () => userRepository.getUsersByIds(any()),
    ).thenAnswer((_) async => const <UserModel>[]);
    when(
      () => userRepository.searchUsers(any(), limit: any(named: 'limit')),
    ).thenAnswer((_) async => const <UserModel>[]);
  });

  LeaderboardCubit build() => LeaderboardCubit(
    uid: _uid,
    ratingRepository: ratingRepository,
    userRepository: userRepository,
  );

  test('constructor emits the initial state synchronously', () {
    final cubit = build();
    addTearDown(cubit.close);

    expect(cubit.state.status, LeaderboardStatus.loading);
    expect(cubit.state.scope, LeaderboardScope.global);
    expect(cubit.state.selectedSportId, SportIds.supported.first);
    expect(cubit.state.entries, isEmpty);
  });

  blocTest<LeaderboardCubit, LeaderboardState>(
    'init loads the global board into a ready state',
    setUp: () {
      when(
        () => ratingRepository.watchLeaderboard(
          sportId: SportIds.pingPong,
          ownerType: any(named: 'ownerType'),
          degreeProgram: null,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) => Stream.value([_rating('a', elo: 1500), _rating('b', elo: 1400)]),
      );
    },
    build: build,
    act: (cubit) => cubit.init(),
    expect: () => [
      _ready(['a', 'b']),
    ],
  );

  blocTest<LeaderboardCubit, LeaderboardState>(
    'resolves display names in one batched lookup after the board loads',
    setUp: () {
      when(
        () => ratingRepository.watchLeaderboard(
          sportId: SportIds.pingPong,
          ownerType: any(named: 'ownerType'),
          degreeProgram: null,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => Stream.value([_rating('a'), _rating('b')]));
      when(() => userRepository.getUsersByIds(any())).thenAnswer(
        (_) async => [_user('a', name: 'Anna'), _user('b', name: 'Bruno')],
      );
    },
    build: build,
    act: (cubit) => cubit.init(),
    expect: () => [
      _ready(['a', 'b']),
      isA<LeaderboardState>()
          .having((s) => s.displayNames['a'], 'name a', 'Anna')
          .having((s) => s.displayNames['b'], 'name b', 'Bruno'),
    ],
    verify: (_) {
      verify(() => userRepository.getUsersByIds(any())).called(1);
    },
  );

  blocTest<LeaderboardCubit, LeaderboardState>(
    'myCourse scope queries the current user degree program',
    setUp: () {
      when(
        () => userRepository.getUser(_uid),
      ).thenAnswer((_) async => _user(_uid, degreeProgram: 'Design'));
      when(
        () => ratingRepository.watchLeaderboard(
          sportId: any(named: 'sportId'),
          ownerType: any(named: 'ownerType'),
          degreeProgram: 'Design',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) => Stream.value([_rating('a', degreeProgram: 'Design')]),
      );
    },
    build: build,
    act: (cubit) async {
      cubit.init();
      await Future<void>.delayed(Duration.zero);
      cubit.selectScope(LeaderboardScope.myCourse);
    },
    expect: () => [
      _loading,
      _ready(['a']),
    ],
    verify: (_) {
      verify(
        () => ratingRepository.watchLeaderboard(
          sportId: SportIds.pingPong,
          ownerType: any(named: 'ownerType'),
          degreeProgram: 'Design',
          limit: any(named: 'limit'),
        ),
      ).called(1);
    },
  );

  blocTest<LeaderboardCubit, LeaderboardState>(
    'friends scope fetches the friends board with self + friends',
    setUp: () {
      when(
        () => userRepository.getUser(_uid),
      ).thenAnswer((_) async => _user(_uid, friends: ['a', 'b']));
      when(
        () => ratingRepository.getFriendsLeaderboard(
          sportId: SportIds.pingPong,
          userAndFriendUids: any(named: 'userAndFriendUids'),
        ),
      ).thenAnswer((_) async => [_rating('a'), _rating(_uid)]);
    },
    build: build,
    act: (cubit) async {
      cubit.init();
      await Future<void>.delayed(Duration.zero);
      cubit.selectScope(LeaderboardScope.friends);
    },
    expect: () => [
      _loading,
      _ready(['a', _uid]),
    ],
    verify: (_) {
      final captured =
          verify(
                () => ratingRepository.getFriendsLeaderboard(
                  sportId: SportIds.pingPong,
                  userAndFriendUids: captureAny(named: 'userAndFriendUids'),
                ),
              ).captured.last
              as List<String>;
      expect(captured, containsAll([_uid, 'a', 'b']));
    },
  );

  blocTest<LeaderboardCubit, LeaderboardState>(
    'a friends board requested before the user doc resolves waits for it and '
    'fetches once, with the full friend list',
    setUp: () {
      // getUser resolves late — controlled by this completer.
      final userLoaded = Completer<UserModel?>();
      when(
        () => userRepository.getUser(_uid),
      ).thenAnswer((_) => userLoaded.future);
      when(
        () => ratingRepository.getFriendsLeaderboard(
          sportId: SportIds.pingPong,
          userAndFriendUids: any(named: 'userAndFriendUids'),
        ),
      ).thenAnswer((_) async => [_rating(_uid), _rating('a'), _rating('b')]);
      userLoadedCompleter = userLoaded;
    },
    build: build,
    act: (cubit) async {
      cubit.init();
      // Switch to friends BEFORE the user doc resolves.
      cubit.selectScope(LeaderboardScope.friends);
      await Future<void>.delayed(Duration.zero);
      userLoadedCompleter.complete(_user(_uid, friends: ['a', 'b']));
      await Future<void>.delayed(Duration.zero);
    },
    verify: (cubit) {
      expect(cubit.state.entries.map((e) => e.ownerId), [_uid, 'a', 'b']);
      final captured =
          verify(
                () => ratingRepository.getFriendsLeaderboard(
                  sportId: SportIds.pingPong,
                  userAndFriendUids: captureAny(named: 'userAndFriendUids'),
                ),
              ).captured.single
              as List<String>;
      expect(captured, containsAll([_uid, 'a', 'b']));
    },
  );

  blocTest<LeaderboardCubit, LeaderboardState>(
    'a friend added after init appears on the next friends-scope load '
    '(the board re-reads the user doc, never a cached copy)',
    setUp: () {
      // First getUser (init) has no friends; every later one has 'a' — as if
      // the friends screen added them while the tab was alive.
      var calls = 0;
      when(() => userRepository.getUser(_uid)).thenAnswer(
        (_) async => _user(_uid, friends: ++calls == 1 ? const [] : ['a']),
      );
      when(
        () => ratingRepository.getFriendsLeaderboard(
          sportId: SportIds.pingPong,
          userAndFriendUids: any(named: 'userAndFriendUids'),
        ),
      ).thenAnswer((_) async => [_rating('a'), _rating(_uid)]);
    },
    build: build,
    act: (cubit) async {
      cubit.init();
      await Future<void>.delayed(Duration.zero);
      cubit.selectScope(LeaderboardScope.friends);
    },
    expect: () => [
      _loading,
      _ready(['a', _uid]),
    ],
    verify: (_) {
      final captured =
          verify(
                () => ratingRepository.getFriendsLeaderboard(
                  sportId: SportIds.pingPong,
                  userAndFriendUids: captureAny(named: 'userAndFriendUids'),
                ),
              ).captured.last
              as List<String>;
      expect(captured, containsAll([_uid, 'a']));
    },
  );

  blocTest<LeaderboardCubit, LeaderboardState>(
    'a late friends fetch for the previous sport cannot overwrite the current',
    setUp: () {
      when(
        () => userRepository.getUser(_uid),
      ).thenAnswer((_) async => _user(_uid, friends: ['x']));
      final pingPong = Completer<List<RatingModel>>();
      final foosball = Completer<List<RatingModel>>();
      when(
        () => ratingRepository.getFriendsLeaderboard(
          sportId: SportIds.pingPong,
          userAndFriendUids: any(named: 'userAndFriendUids'),
        ),
      ).thenAnswer((_) => pingPong.future);
      when(
        () => ratingRepository.getFriendsLeaderboard(
          sportId: SportIds.foosball,
          userAndFriendUids: any(named: 'userAndFriendUids'),
        ),
      ).thenAnswer((_) => foosball.future);
      pingPongFriends = pingPong;
      foosballFriends = foosball;
    },
    build: build,
    act: (cubit) async {
      cubit.init();
      await Future<void>.delayed(Duration.zero);
      cubit.selectScope(LeaderboardScope.friends); // fetch ping_pong (pending)
      cubit.selectSport(SportIds.foosball); // now foosball (pending)
      // foosball resolves first and wins the board.
      foosballFriends.complete([_rating('fb', sportId: SportIds.foosball)]);
      await Future<void>.delayed(Duration.zero);
      // ping_pong resolves late — its guard must drop it.
      pingPongFriends.complete([_rating('pp')]);
      await Future<void>.delayed(Duration.zero);
    },
    verify: (cubit) {
      expect(cubit.state.selectedSportId, SportIds.foosball);
      expect(cubit.state.entries.map((e) => e.ownerId), ['fb']);
    },
  );

  blocTest<LeaderboardCubit, LeaderboardState>(
    'populates the your-rank bar from rating + rank',
    setUp: () {
      when(
        () => ratingRepository.getUserRating(_uid, SportIds.pingPong),
      ).thenAnswer((_) async => _rating(_uid, elo: 1333));
      when(
        () =>
            ratingRepository.getUserRank(sportId: SportIds.pingPong, elo: 1333),
      ).thenAnswer((_) async => 7);
    },
    build: build,
    act: (cubit) => cubit.init(),
    expect: () => [
      isA<LeaderboardState>()
          .having((s) => s.currentUserRating?.elo, 'elo', 1333)
          .having((s) => s.currentUserRank, 'rank', 7),
    ],
  );

  blocTest<LeaderboardCubit, LeaderboardState>(
    'switching to an unplayed sport clears the previous pinned rank',
    setUp: () {
      when(
        () => ratingRepository.getUserRating(_uid, SportIds.pingPong),
      ).thenAnswer((_) async => _rating(_uid, elo: 1333));
      when(
        () =>
            ratingRepository.getUserRank(sportId: SportIds.pingPong, elo: 1333),
      ).thenAnswer((_) async => 7);
      // Never played foosball.
      when(
        () => ratingRepository.getUserRating(_uid, SportIds.foosball),
      ).thenAnswer((_) async => null);
    },
    build: build,
    act: (cubit) async {
      cubit.init();
      await Future<void>.delayed(Duration.zero);
      cubit.selectSport(SportIds.foosball);
      await Future<void>.delayed(Duration.zero);
    },
    verify: (cubit) {
      expect(cubit.state.selectedSportId, SportIds.foosball);
      expect(cubit.state.currentUserRating, isNull);
      expect(cubit.state.currentUserRank, isNull);
    },
  );

  blocTest<LeaderboardCubit, LeaderboardState>(
    'a stream error moves the board to error',
    setUp: () {
      when(
        () => ratingRepository.watchLeaderboard(
          sportId: any(named: 'sportId'),
          ownerType: any(named: 'ownerType'),
          degreeProgram: any(named: 'degreeProgram'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => Stream.error(Exception('boom')));
    },
    build: build,
    act: (cubit) => cubit.init(),
    expect: () => [
      isA<LeaderboardState>().having(
        (s) => s.status,
        'status',
        LeaderboardStatus.error,
      ),
    ],
  );

  blocTest<LeaderboardCubit, LeaderboardState>(
    'name-resolution failure leaves the board ready',
    setUp: () {
      when(
        () => ratingRepository.watchLeaderboard(
          sportId: any(named: 'sportId'),
          ownerType: any(named: 'ownerType'),
          degreeProgram: any(named: 'degreeProgram'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => Stream.value([_rating('a')]));
      when(
        () => userRepository.getUsersByIds(any()),
      ).thenThrow(Exception('lookup failed'));
    },
    build: build,
    act: (cubit) => cubit.init(),
    expect: () => [
      _ready(['a']),
    ],
    verify: (cubit) {
      expect(cubit.state.displayNames.containsKey('a'), isFalse);
    },
  );

  blocTest<LeaderboardCubit, LeaderboardState>(
    'global search places a player from the loaded board by position, '
    'without a rank query',
    setUp: () {
      when(
        () => ratingRepository.watchLeaderboard(
          sportId: SportIds.pingPong,
          ownerType: any(named: 'ownerType'),
          degreeProgram: null,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) => Stream.value([_rating('a', elo: 1500), _rating('b', elo: 1400)]),
      );
      when(
        () => userRepository.searchUsers('b', limit: any(named: 'limit')),
      ).thenAnswer((_) async => [_user('b', name: 'Bruno')]);
    },
    build: build,
    act: (cubit) async {
      cubit.init();
      await Future<void>.delayed(Duration.zero);
      cubit.search('b');
      await Future<void>.delayed(const Duration(milliseconds: 350));
    },
    verify: (cubit) {
      final result = cubit.state.searchResults.single;
      expect(result.user!.uid, 'b');
      // Second on the board → rank 2, ELO straight from the entry.
      expect(result.rank, 2);
      expect(result.rating?.elo, 1400);
      // Board position is free: no rating batch and no count aggregation.
      verifyNever(() => ratingRepository.getUserRatings(any(), any()));
      verifyNever(
        () => ratingRepository.getUserRank(
          sportId: any(named: 'sportId'),
          elo: any(named: 'elo'),
          degreeProgram: any(named: 'degreeProgram'),
        ),
      );
    },
  );

  blocTest<LeaderboardCubit, LeaderboardState>(
    'a deep player whose rank count fails is omitted',
    setUp: () {
      when(
        () => userRepository.searchUsers('al', limit: any(named: 'limit')),
      ).thenAnswer((_) async => [_user('a', name: 'Alice')]);
      when(
        () => ratingRepository.getUserRatings(['a'], SportIds.pingPong),
      ).thenAnswer((_) async => {'a': _rating('a', elo: 900)});
      when(
        () =>
            ratingRepository.getUserRank(sportId: SportIds.pingPong, elo: 900),
      ).thenThrow(Exception('missing index'));
    },
    build: build,
    act: (cubit) async {
      cubit.init();
      cubit.search('al');
      await Future<void>.delayed(const Duration(milliseconds: 350));
    },
    verify: (cubit) {
      expect(cubit.state.searchStatus, LeaderboardSearchStatus.done);
      // No position available → the player is dropped from the results.
      expect(cubit.state.searchResults, isEmpty);
    },
  );

  blocTest<LeaderboardCubit, LeaderboardState>(
    'global search reports each match campus rank',
    setUp: () {
      when(
        () => userRepository.searchUsers('al', limit: any(named: 'limit')),
      ).thenAnswer((_) async => [_user('a', name: 'Alice')]);
      when(
        () => ratingRepository.getUserRatings(['a'], SportIds.pingPong),
      ).thenAnswer((_) async => {'a': _rating('a', elo: 1600)});
      when(
        () =>
            ratingRepository.getUserRank(sportId: SportIds.pingPong, elo: 1600),
      ).thenAnswer((_) async => 3);
    },
    build: build,
    act: (cubit) async {
      cubit.init();
      cubit.search('al');
      await Future<void>.delayed(const Duration(milliseconds: 350));
    },
    verify: (cubit) {
      expect(cubit.state.searchStatus, LeaderboardSearchStatus.done);
      final results = cubit.state.searchResults;
      expect(results.map((r) => r.user!.uid), ['a']);
      expect(results.single.rank, 3);
      expect(results.single.rating?.elo, 1600);
    },
  );

  blocTest<LeaderboardCubit, LeaderboardState>(
    'course search leaves other-program players unranked',
    setUp: () {
      when(
        () => userRepository.getUser(_uid),
      ).thenAnswer((_) async => _user(_uid, degreeProgram: 'Design'));
      when(
        () => userRepository.searchUsers('p', limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => [
          _user('same', name: 'Same', degreeProgram: 'Design'),
          _user('other', name: 'Other', degreeProgram: 'Physics'),
        ],
      );
      when(
        () => ratingRepository.getUserRatings(any(), SportIds.pingPong),
      ).thenAnswer(
        (_) async => {
          'same': _rating('same', elo: 1500, degreeProgram: 'Design'),
          'other': _rating('other', elo: 1900, degreeProgram: 'Physics'),
        },
      );
      when(
        () => ratingRepository.getUserRank(
          sportId: SportIds.pingPong,
          elo: 1500,
          degreeProgram: 'Design',
        ),
      ).thenAnswer((_) async => 2);
    },
    build: build,
    act: (cubit) async {
      cubit.init();
      await Future<void>.delayed(Duration.zero);
      cubit.selectScope(LeaderboardScope.myCourse);
      await Future<void>.delayed(Duration.zero);
      cubit.search('p');
      await Future<void>.delayed(const Duration(milliseconds: 350));
    },
    verify: (cubit) {
      final byUid = {for (final r in cubit.state.searchResults) r.user!.uid: r};
      expect(byUid['same']!.rank, 2);
      // Off-program player has no position on this board → omitted.
      expect(byUid.containsKey('other'), isFalse);
    },
  );

  blocTest<LeaderboardCubit, LeaderboardState>(
    'friends search ranks by board position and skips non-friends',
    setUp: () {
      when(
        () => userRepository.getUser(_uid),
      ).thenAnswer((_) async => _user(_uid, friends: ['a']));
      when(
        () => ratingRepository.getFriendsLeaderboard(
          sportId: SportIds.pingPong,
          userAndFriendUids: any(named: 'userAndFriendUids'),
        ),
      ).thenAnswer(
        (_) async => [_rating('a', elo: 1500), _rating(_uid, elo: 1400)],
      );
      when(
        () => userRepository.searchUsers('x', limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => [_user('a', name: 'Anna'), _user('z', name: 'Zoe')],
      );
    },
    build: build,
    act: (cubit) async {
      cubit.init();
      await Future<void>.delayed(Duration.zero);
      cubit.selectScope(LeaderboardScope.friends);
      await Future<void>.delayed(Duration.zero);
      cubit.search('x');
      await Future<void>.delayed(const Duration(milliseconds: 350));
    },
    verify: (cubit) {
      final byUid = {for (final r in cubit.state.searchResults) r.user!.uid: r};
      // 'a' is first on the friends board → rank 1.
      expect(byUid['a']!.rank, 1);
      // 'z' isn't a friend → no board position → omitted.
      expect(byUid.containsKey('z'), isFalse);
    },
  );

  blocTest<LeaderboardCubit, LeaderboardState>(
    'changing sport while searching recomputes ranks for the new sport',
    setUp: () {
      when(
        () => userRepository.searchUsers('al', limit: any(named: 'limit')),
      ).thenAnswer((_) async => [_user('a', name: 'Alice')]);
      when(
        () => ratingRepository.getUserRatings(['a'], SportIds.pingPong),
      ).thenAnswer((_) async => {'a': _rating('a', elo: 1600)});
      when(
        () => ratingRepository.getUserRatings(['a'], SportIds.foosball),
      ).thenAnswer(
        (_) async => {'a': _rating('a', elo: 1100, sportId: SportIds.foosball)},
      );
      when(
        () =>
            ratingRepository.getUserRank(sportId: SportIds.pingPong, elo: 1600),
      ).thenAnswer((_) async => 3);
      when(
        () =>
            ratingRepository.getUserRank(sportId: SportIds.foosball, elo: 1100),
      ).thenAnswer((_) async => 42);
    },
    build: build,
    act: (cubit) async {
      cubit.init();
      cubit.search('al');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      cubit.selectSport(SportIds.foosball);
      await Future<void>.delayed(Duration.zero);
    },
    verify: (cubit) {
      expect(cubit.state.selectedSportId, SportIds.foosball);
      expect(cubit.state.searchResults.single.rank, 42);
    },
  );

  blocTest<LeaderboardCubit, LeaderboardState>(
    'clearing the query empties results without querying',
    build: build,
    act: (cubit) async {
      cubit.init();
      cubit.search('al');
      cubit.search('');
      await Future<void>.delayed(const Duration(milliseconds: 350));
    },
    verify: (cubit) {
      expect(cubit.state.isSearching, isFalse);
      expect(cubit.state.searchResults, isEmpty);
      expect(cubit.state.searchStatus, LeaderboardSearchStatus.idle);
      verifyNever(
        () => userRepository.searchUsers('al', limit: any(named: 'limit')),
      );
    },
  );

  group('doubles mode', () {
    RatingModel pair(String pairId, List<String> members, {int elo = 1500}) =>
        RatingModel(
          ratingId: RatingRepository.ratingId(SportIds.pingPong, pairId),
          ownerType: OwnerType.pair,
          ownerId: pairId,
          memberUids: members,
          sportId: SportIds.pingPong,
          elo: elo,
          matchesPlayed: 3,
          lastMatchAt: DateTime(2026, 6, 30),
        );

    void stubPairBoard(List<RatingModel> pairs) {
      when(
        () => ratingRepository.watchLeaderboard(
          sportId: SportIds.pingPong,
          ownerType: OwnerType.pair,
          degreeProgram: null,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => Stream.value(pairs));
    }

    test(
      'selectMode(doubles) loads the pair board and forces global scope',
      () async {
        stubPairBoard([
          pair('a_b', ['a', 'b']),
        ]);
        when(() => userRepository.getUsersByIds(any())).thenAnswer(
          (_) async => [_user('a', name: 'Anna'), _user('b', name: 'Bruno')],
        );

        final cubit = build();
        addTearDown(cubit.close);
        cubit.init();
        await Future<void>.delayed(Duration.zero);
        cubit.selectScope(LeaderboardScope.friends);
        cubit.selectMode(LeaderboardMode.doubles);
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.mode, LeaderboardMode.doubles);
        // Doubles is global-only, so the friends scope snaps back.
        expect(cubit.state.scope, LeaderboardScope.global);
        expect(cubit.state.entries.map((e) => e.ownerId), ['a_b']);
        // The two members are resolved, not the synthetic pairId.
        expect(cubit.state.displayNames['a'], 'Anna');
        expect(cubit.state.displayNames['b'], 'Bruno');
      },
    );

    test(
      'doubles search returns pair rows whose member matches the query',
      () async {
        stubPairBoard([
          pair('a_b', ['a', 'b'], elo: 1500),
          pair('c_d', ['c', 'd'], elo: 1400),
        ]);
        when(
          () => userRepository.searchUsers('anna', limit: any(named: 'limit')),
        ).thenAnswer((_) async => [_user('a', name: 'Anna')]);

        final cubit = build();
        addTearDown(cubit.close);
        cubit.init();
        await Future<void>.delayed(Duration.zero);
        cubit.selectMode(LeaderboardMode.doubles);
        await Future<void>.delayed(Duration.zero);
        cubit.search('anna');
        await Future<void>.delayed(const Duration(milliseconds: 350));

        final results = cubit.state.searchResults;
        expect(results.length, 1);
        expect(results.first.rating!.ownerId, 'a_b');
        expect(results.first.user, isNull);
        expect(results.first.rank, 1);
      },
    );
  });
}
