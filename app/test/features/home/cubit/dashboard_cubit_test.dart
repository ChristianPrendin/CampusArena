import 'dart:async';

import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/core/match_display.dart';
import 'package:campus_arena/features/home/cubit/dashboard_cubit.dart';
import 'package:campus_arena/features/home/cubit/dashboard_state.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/models/rating_model.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRatingRepository extends Mock implements RatingRepository {}

class MockMatchRepository extends Mock implements MatchRepository {}

class MockUserRepository extends Mock implements UserRepository {}

const _uid = 'me';

RatingModel _rating(String sportId, {int elo = kInitialElo, int matches = 0}) =>
    RatingModel(
      ratingId: RatingRepository.ratingId(sportId, _uid),
      ownerType: OwnerType.user,
      ownerId: _uid,
      sportId: sportId,
      elo: elo,
      matchesPlayed: matches,
      lastMatchAt: DateTime(2026, 6, 30),
    );

MatchModel _match({
  required String id,
  String state = MatchStates.confirmed,
  List<String> players = const [_uid, 'opp'],
  Map<String, int>? eloDeltas,
  List<String> winnerIds = const [_uid],
  DateTime? startedAt,
}) => MatchModel(
  matchId: id,
  facilityId: 'f1',
  sportId: SportIds.pingPong,
  mode: 'singles',
  playerUids: players,
  state: state,
  result: state == MatchStates.confirmed
      ? PingPongResult(
          winnerIds: winnerIds,
          sets: const [11],
          opponentSets: const [5],
        )
      : null,
  eloDeltas: eloDeltas,
  startedAt: startedAt ?? DateTime(2026, 6, 30, 10),
);

UserModel _user(String uid, String username) => UserModel(
  uid: uid,
  name: username,
  username: username,
  email: '$uid@polimi.it',
  degreeProgram: 'Computer Science',
  language: 'en',
  pushTokens: const [],
  friendUids: const [],
  badges: const {},
  onboardingComplete: true,
  createdAt: DateTime(2026),
);

void main() {
  late MockRatingRepository ratingRepository;
  late MockMatchRepository matchRepository;
  late MockUserRepository userRepository;

  setUp(() {
    ratingRepository = MockRatingRepository();
    matchRepository = MockMatchRepository();
    userRepository = MockUserRepository();

    when(
      () => ratingRepository.watchUserRatings(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => matchRepository.watchUserMatches(any(), limit: any(named: 'limit')),
    ).thenAnswer((_) => const Stream.empty());
    when(() => userRepository.getUser(any())).thenAnswer((_) async => null);
  });

  DashboardCubit build() => DashboardCubit(
    uid: _uid,
    ratingRepository: ratingRepository,
    matchRepository: matchRepository,
    userRepository: userRepository,
  );

  test('initial state is loading with empty collections', () {
    final cubit = build();
    addTearDown(cubit.close);

    expect(cubit.state.status, DashboardStatus.loading);
    expect(cubit.state.ratings, isEmpty);
    expect(cubit.state.recentMatches, isEmpty);
  });

  test(
    'becomes ready once both streams emit, ratings ordered per supported',
    () async {
      // Feed ratings reversed to prove reordering.
      when(() => ratingRepository.watchUserRatings(_uid)).thenAnswer(
        (_) => Stream.value([
          _rating(SportIds.foosball),
          _rating(SportIds.pingPong),
        ]),
      );
      when(
        () =>
            matchRepository.watchUserMatches(_uid, limit: any(named: 'limit')),
      ).thenAnswer((_) => Stream.value(const <MatchModel>[]));

      final cubit = build();
      addTearDown(cubit.close);
      await pumpEventQueue();

      expect(cubit.state.status, DashboardStatus.ready);
      expect(cubit.state.ratings.map((r) => r.sportId), [
        SportIds.pingPong,
        SportIds.foosball,
      ]);
      // Campus rank was removed from the dashboard: no rank aggregation runs.
      verifyNever(
        () => ratingRepository.getUserRank(
          sportId: any(named: 'sportId'),
          elo: any(named: 'elo'),
        ),
      );
    },
  );

  test(
    'keeps only terminal-state matches from the window, newest first',
    () async {
      when(
        () =>
            matchRepository.watchUserMatches(_uid, limit: any(named: 'limit')),
      ).thenAnswer(
        (_) => Stream.value([
          _match(id: 'm1', state: MatchStates.confirmed),
          _match(id: 'm2', state: MatchStates.occupied),
          _match(id: 'm3', state: MatchStates.disputed),
          _match(id: 'm4', state: MatchStates.awaitingConfirmation),
          _match(id: 'm5', state: MatchStates.abandoned),
          _match(id: 'm6', state: MatchStates.unconfirmed),
          _match(id: 'm7', state: MatchStates.confirmed),
        ]),
      );
      when(
        () => ratingRepository.watchUserRatings(_uid),
      ).thenAnswer((_) => Stream.value(const <RatingModel>[]));

      final cubit = build();
      addTearDown(cubit.close);
      await pumpEventQueue();

      expect(cubit.state.recentMatches.map((m) => m.matchId), [
        'm1',
        'm3',
        'm5',
        'm6',
        'm7',
      ]);
    },
  );

  test('resolves opponent names once and caches across re-emissions', () async {
    final controller = StreamController<List<MatchModel>>();
    when(
      () => matchRepository.watchUserMatches(_uid, limit: any(named: 'limit')),
    ).thenAnswer((_) => controller.stream);
    when(
      () => userRepository.getUser('opp'),
    ).thenAnswer((_) async => _user('opp', 'Alice'));

    final cubit = build();
    addTearDown(cubit.close);
    addTearDown(controller.close);

    controller.add([_match(id: 'm1')]);
    await pumpEventQueue();
    controller.add([_match(id: 'm1'), _match(id: 'm2')]);
    await pumpEventQueue();

    expect(cubit.state.opponentNames['opp'], 'Alice');
    verify(() => userRepository.getUser('opp')).called(1);
  });

  test('a stream error moves the dashboard to error', () async {
    when(
      () => ratingRepository.watchUserRatings(_uid),
    ).thenAnswer((_) => Stream.error(Exception('boom')));

    final cubit = build();
    addTearDown(cubit.close);
    await pumpEventQueue();

    expect(cubit.state.status, DashboardStatus.error);
  });

  test('retry re-subscribes after an error', () async {
    when(
      () => ratingRepository.watchUserRatings(_uid),
    ).thenAnswer((_) => Stream.error(Exception('boom')));
    when(
      () => matchRepository.watchUserMatches(_uid, limit: any(named: 'limit')),
    ).thenAnswer((_) => Stream.value(const <MatchModel>[]));

    final cubit = build();
    addTearDown(cubit.close);
    await pumpEventQueue();
    expect(cubit.state.status, DashboardStatus.error);

    // Streams now succeed on the retry.
    when(
      () => ratingRepository.watchUserRatings(_uid),
    ).thenAnswer((_) => Stream.value([_rating(SportIds.pingPong)]));
    cubit.retry();
    await pumpEventQueue();

    expect(cubit.state.status, DashboardStatus.ready);
    expect(cubit.state.ratings, isNotEmpty);
  });

  group('sport selection', () {
    test('defaults to the first supported sport', () {
      final cubit = build();
      addTearDown(cubit.close);
      expect(cubit.state.selectedSportId, SportIds.supported.first);
    });

    test(
      'selectSport switches the focused sport; re-selecting is a no-op',
      () async {
        final cubit = build();
        addTearDown(cubit.close);

        final emitted = <String>[];
        final sub = cubit.stream.listen((s) => emitted.add(s.selectedSportId));
        addTearDown(sub.cancel);

        cubit.selectSport(SportIds.foosball);
        expect(cubit.state.selectedSportId, SportIds.foosball);

        cubit.selectSport(SportIds.foosball); // same → no emission
        await pumpEventQueue();
        expect(emitted.where((s) => s == SportIds.foosball), hasLength(1));
      },
    );

    test(
      'selectedRecentMatches filters the window by the focused sport',
      () async {
        when(
          () => matchRepository.watchUserMatches(
            _uid,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) => Stream.value([
            _match(id: 'pp1'),
            MatchModel(
              matchId: 'fb1',
              facilityId: 'f1',
              sportId: SportIds.foosball,
              mode: 'singles',
              playerUids: const [_uid, 'opp'],
              state: MatchStates.confirmed,
              result: const FoosballResult(
                winnerIds: [_uid],
                goals: 10,
                opponentGoals: 6,
              ),
              startedAt: DateTime(2026, 6, 29),
            ),
          ]),
        );

        final cubit = build();
        addTearDown(cubit.close);
        await pumpEventQueue();

        cubit.selectSport(SportIds.pingPong);
        expect(cubit.state.selectedRecentMatches.map((m) => m.matchId), [
          'pp1',
        ]);
        cubit.selectSport(SportIds.foosball);
        expect(cubit.state.selectedRecentMatches.map((m) => m.matchId), [
          'fb1',
        ]);
      },
    );
  });

  group('opponentUids', () {
    test('singles / null pair ids returns everyone but me', () {
      final m = _match(id: 'm1', players: const [_uid, 'opp']);
      expect(opponentUids(m, _uid), ['opp']);
    });

    test('doubles uses pair ids to exclude the caller teammate', () {
      final m = MatchModel(
        matchId: 'm1',
        facilityId: 'f1',
        sportId: SportIds.pingPong,
        mode: 'doubles',
        playerUids: const [_uid, 'mate', 'x', 'y'],
        team1PairId: 'mate_me',
        team2PairId: 'x_y',
        state: MatchStates.confirmed,
        startedAt: DateTime(2026, 6, 30, 10),
      );
      expect(opponentUids(m, _uid), ['x', 'y']);
    });
  });
}
