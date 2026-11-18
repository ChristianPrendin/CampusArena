import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/profile/cubit/profile_cubit.dart';
import 'package:campus_arena/features/profile/cubit/profile_state.dart';
import 'package:campus_arena/features/profile/profile_stats.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/models/rating_model.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/achievement_repository.dart';
import 'package:campus_arena/repositories/facility_repository.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRatingRepository extends Mock implements RatingRepository {}

class MockMatchRepository extends Mock implements MatchRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockFacilityRepository extends Mock implements FacilityRepository {}

class MockAchievementRepository extends Mock implements AchievementRepository {}

const _uid = 'me';

RatingModel _rating(String sportId, {int elo = kInitialElo}) => RatingModel(
  ratingId: RatingRepository.ratingId(sportId, _uid),
  ownerType: OwnerType.user,
  ownerId: _uid,
  sportId: sportId,
  elo: elo,
  matchesPlayed: 5,
  lastMatchAt: DateTime(2026, 6, 30),
);

MatchModel _match({
  required String id,
  required int day,
  String state = MatchStates.confirmed,
  List<String> players = const [_uid, 'opp'],
  bool won = true,
  Map<String, int>? eloBefore,
  Map<String, int>? eloDeltas,
}) => MatchModel(
  matchId: id,
  facilityId: 'f1',
  sportId: SportIds.pingPong,
  mode: 'singles',
  playerUids: players,
  state: state,
  result: state == MatchStates.confirmed
      ? PingPongResult(
          winnerIds: won
              ? const [_uid]
              : [players.firstWhere((p) => p != _uid)],
          sets: const [11, 11],
          opponentSets: const [5, 7],
        )
      : null,
  eloBefore: eloBefore,
  eloDeltas: eloDeltas,
  startedAt: DateTime(2026, 7, day, 10),
  confirmedAt: state == MatchStates.confirmed
      ? DateTime(2026, 7, day, 11)
      : null,
);

UserModel _user(String uid, String username) => UserModel(
  uid: uid,
  name: username,
  username: username,
  email: '$uid@polimi.it',
  degreeProgram: 'Computer Science and Engineering',
  language: 'en',
  pushTokens: const [],
  friendUids: const [],
  badges: {'first_victory': DateTime(2026, 6, 20)},
  onboardingComplete: true,
  createdAt: DateTime(2026),
);

FacilityModel _facility(String id, String name) => FacilityModel(
  facilityId: id,
  name: name,
  sportId: SportIds.pingPong,
  coordinates: const Coordinates(latitude: 45.4784, longitude: 9.2272),
  qrCode: 'qr-$id',
  fallbackCode: 'FB$id',
  isOutdoor: false,
  status: FacilityStatus.free,
  kingOfTableWins: 0,
  queueTailPosition: 0,
);

void main() {
  late MockRatingRepository ratingRepository;
  late MockMatchRepository matchRepository;
  late MockUserRepository userRepository;
  late MockFacilityRepository facilityRepository;
  late MockAchievementRepository achievementRepository;

  setUp(() {
    ratingRepository = MockRatingRepository();
    matchRepository = MockMatchRepository();
    userRepository = MockUserRepository();
    facilityRepository = MockFacilityRepository();
    achievementRepository = MockAchievementRepository();

    when(
      () => achievementRepository.getDefinitions(),
    ).thenAnswer((_) async => const []);
    when(
      () => ratingRepository.watchUserRatings(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => matchRepository.watchUserMatches(any(), limit: any(named: 'limit')),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => userRepository.watchUser(_uid),
    ).thenAnswer((_) => Stream.value(_user(_uid, 'mario')));
    when(() => userRepository.getUser('opp')).thenAnswer((_) async => null);
    when(
      () => facilityRepository.getFacility(any()),
    ).thenAnswer((_) async => null);
  });

  /// Synchronous derivation bypasses the isolate so bloc_test's pumping is
  /// deterministic; the real compute() path is covered by its own test below.
  ProfileCubit build() => ProfileCubit(
    uid: _uid,
    ratingRepository: ratingRepository,
    matchRepository: matchRepository,
    userRepository: userRepository,
    facilityRepository: facilityRepository,
    achievementRepository: achievementRepository,
    derive: (input) async => deriveProfileStats(input),
  );

  test('initial state is loading, emitted synchronously', () {
    final cubit = build();
    addTearDown(cubit.close);
    expect(cubit.state.status, ProfileStatus.loading);
    expect(cubit.state.selectedSportId, SportIds.supported.first);
  });

  blocTest<ProfileCubit, ProfileState>(
    'happy path: user + ratings + matches land, stats derived, names cached',
    setUp: () {
      when(() => ratingRepository.watchUserRatings(_uid)).thenAnswer(
        (_) => Stream.value([
          _rating(SportIds.foosball, elo: 1300),
          _rating(SportIds.pingPong, elo: 1482),
        ]),
      );
      when(() => matchRepository.watchUserMatches(_uid, limit: 100)).thenAnswer(
        (_) => Stream.value([
          _match(
            id: 'm2',
            day: 2,
            won: false,
            eloBefore: const {_uid: 1216, 'opp': 1200},
            eloDeltas: const {_uid: -12, 'opp': 12},
          ),
          _match(id: 'pending', day: 2, state: MatchStates.occupied),
          _match(
            id: 'm1',
            day: 1,
            won: true,
            eloBefore: const {_uid: 1200, 'opp': 1200},
            eloDeltas: const {_uid: 16, 'opp': -16},
          ),
        ]),
      );
      when(
        () => userRepository.getUser('opp'),
      ).thenAnswer((_) async => _user('opp', 'luigi'));
      when(
        () => facilityRepository.getFacility('f1'),
      ).thenAnswer((_) async => _facility('f1', 'Table 1 — BL27'));
    },
    build: build,
    verify: (cubit) {
      final state = cubit.state;
      expect(state.status, ProfileStatus.ready);
      expect(state.user?.username, 'mario');
      expect(state.badges.keys, ['first_victory']);
      // Ratings reordered per SportIds.supported.
      expect(state.ratings.map((r) => r.sportId), [
        SportIds.pingPong,
        SportIds.foosball,
      ]);
      // The occupied match is excluded from history; terminal ones stay
      // newest first.
      expect(state.matches.map((m) => m.matchId), ['m2', 'm1']);
      final stats = state.derivation.statsFor(SportIds.pingPong);
      expect(stats.games, 2);
      expect(stats.wins, 1);
      expect(state.derivation.trendFor(SportIds.pingPong).map((p) => p.elo), [
        1200, // baseline: eloBefore of the first rated match
        1216,
        1204,
      ]);
      expect(state.opponentNames['opp'], 'luigi');
      expect(state.facilityNames['f1'], 'Table 1 — BL27');
    },
  );

  blocTest<ProfileCubit, ProfileState>(
    'non-confirmed terminal states stay in history but not in stats',
    setUp: () {
      when(
        () => ratingRepository.watchUserRatings(_uid),
      ).thenAnswer((_) => Stream.value([_rating(SportIds.pingPong)]));
      when(() => matchRepository.watchUserMatches(_uid, limit: 100)).thenAnswer(
        (_) => Stream.value([
          _match(id: 'd1', day: 3, state: MatchStates.disputed),
          _match(id: 'u1', day: 2, state: MatchStates.unconfirmed),
          _match(id: 'c1', day: 1, won: true),
        ]),
      );
    },
    build: build,
    verify: (cubit) {
      expect(cubit.state.matches.map((m) => m.matchId), ['d1', 'u1', 'c1']);
      expect(cubit.state.derivation.statsFor(SportIds.pingPong).games, 1);
    },
  );

  blocTest<ProfileCubit, ProfileState>(
    'empty match history is ready with empty derivation',
    setUp: () {
      when(() => ratingRepository.watchUserRatings(_uid)).thenAnswer(
        (_) => Stream.value([
          _rating(SportIds.pingPong),
          _rating(SportIds.foosball),
        ]),
      );
      when(
        () => matchRepository.watchUserMatches(_uid, limit: 100),
      ).thenAnswer((_) => Stream.value(const <MatchModel>[]));
    },
    build: build,
    verify: (cubit) {
      expect(cubit.state.status, ProfileStatus.ready);
      expect(cubit.state.matches, isEmpty);
      expect(cubit.state.selectedStats, SportStats.empty);
      expect(cubit.state.selectedTrend, isEmpty);
      expect(cubit.state.selectedFunStats, SportFunStats.empty);
    },
  );

  blocTest<ProfileCubit, ProfileState>(
    'a ratings stream error moves the profile to error',
    setUp: () {
      when(
        () => ratingRepository.watchUserRatings(_uid),
      ).thenAnswer((_) => Stream.error(Exception('boom')));
      when(
        () => matchRepository.watchUserMatches(_uid, limit: 100),
      ).thenAnswer((_) => Stream.value(const <MatchModel>[]));
    },
    build: build,
    verify: (cubit) => expect(cubit.state.status, ProfileStatus.error),
  );

  blocTest<ProfileCubit, ProfileState>(
    'a user stream error moves the profile to error',
    setUp: () {
      when(
        () => userRepository.watchUser(_uid),
      ).thenAnswer((_) => Stream.error(Exception('boom')));
      when(
        () => ratingRepository.watchUserRatings(_uid),
      ).thenAnswer((_) => Stream.value([_rating(SportIds.pingPong)]));
      when(
        () => matchRepository.watchUserMatches(_uid, limit: 100),
      ).thenAnswer((_) => Stream.value(const <MatchModel>[]));
    },
    build: build,
    verify: (cubit) => expect(cubit.state.status, ProfileStatus.error),
  );

  blocTest<ProfileCubit, ProfileState>(
    'a null user doc (deleted/missing) moves the profile to error',
    setUp: () {
      when(
        () => userRepository.watchUser(_uid),
      ).thenAnswer((_) => Stream.value(null));
      when(
        () => ratingRepository.watchUserRatings(_uid),
      ).thenAnswer((_) => Stream.value([_rating(SportIds.pingPong)]));
      when(
        () => matchRepository.watchUserMatches(_uid, limit: 100),
      ).thenAnswer((_) => Stream.value(const <MatchModel>[]));
    },
    build: build,
    verify: (cubit) => expect(cubit.state.status, ProfileStatus.error),
  );

  blocTest<ProfileCubit, ProfileState>(
    'a later badge unlock on the user stream updates the ready profile live',
    setUp: () {
      when(
        () => ratingRepository.watchUserRatings(_uid),
      ).thenAnswer((_) => Stream.value([_rating(SportIds.pingPong)]));
      when(
        () => matchRepository.watchUserMatches(_uid, limit: 100),
      ).thenAnswer((_) => Stream.value(const <MatchModel>[]));
      when(() => userRepository.watchUser(_uid)).thenAnswer(
        (_) => Stream.fromIterable([
          _user(_uid, 'mario'),
          _user(_uid, 'mario').copyWith(
            badges: {
              'first_victory': DateTime(2026, 6, 20),
              'streak_5': DateTime(2026, 7, 9),
            },
          ),
        ]),
      );
    },
    build: build,
    verify: (cubit) =>
        expect(cubit.state.badges.keys, ['first_victory', 'streak_5']),
  );

  test('retry re-subscribes after an error', () async {
    when(
      () => ratingRepository.watchUserRatings(_uid),
    ).thenAnswer((_) => Stream.error(Exception('boom')));
    when(
      () => matchRepository.watchUserMatches(_uid, limit: 100),
    ).thenAnswer((_) => Stream.value(const <MatchModel>[]));

    final cubit = build();
    addTearDown(cubit.close);
    await pumpEventQueue();
    expect(cubit.state.status, ProfileStatus.error);

    when(
      () => ratingRepository.watchUserRatings(_uid),
    ).thenAnswer((_) => Stream.value([_rating(SportIds.pingPong)]));
    cubit.selectSport(SportIds.foosball);
    cubit.retry();
    await pumpEventQueue();

    expect(cubit.state.status, ProfileStatus.ready);
    // The viewed sport survives the reload.
    expect(cubit.state.selectedSportId, SportIds.foosball);
  });

  test('selectSport switches focus; re-selecting is a no-op', () async {
    final cubit = build();
    addTearDown(cubit.close);

    // Count sport *changes* — decorative emissions (user load) also carry the
    // current selection and must not be mistaken for a switch.
    var switches = 0;
    var previous = cubit.state.selectedSportId;
    final sub = cubit.stream.listen((s) {
      if (s.selectedSportId != previous) switches++;
      previous = s.selectedSportId;
    });
    addTearDown(sub.cancel);

    cubit.selectSport(SportIds.foosball);
    cubit.selectSport(SportIds.foosball); // same → no emission
    await pumpEventQueue();

    expect(cubit.state.selectedSportId, SportIds.foosball);
    expect(switches, 1);
  });

  test('production derivation runs through a real isolate', () async {
    // No injected `derive`: this exercises ProfileCubit.computeDerivation →
    // compute() → deriveProfileStats crossing a real isolate boundary,
    // proving the input/output types are isolate-sendable.
    when(
      () => ratingRepository.watchUserRatings(_uid),
    ).thenAnswer((_) => Stream.value([_rating(SportIds.pingPong)]));
    when(() => matchRepository.watchUserMatches(_uid, limit: 100)).thenAnswer(
      (_) => Stream.value([
        _match(
          id: 'm1',
          day: 1,
          won: true,
          eloBefore: const {_uid: 1200, 'opp': 1200},
          eloDeltas: const {_uid: 16, 'opp': -16},
        ),
      ]),
    );

    final cubit = ProfileCubit(
      uid: _uid,
      ratingRepository: ratingRepository,
      matchRepository: matchRepository,
      userRepository: userRepository,
      facilityRepository: facilityRepository,
      achievementRepository: achievementRepository,
    );
    addTearDown(cubit.close);

    final ready = await cubit.stream
        .firstWhere((s) => s.status == ProfileStatus.ready)
        .timeout(const Duration(seconds: 10));
    expect(ready.derivation.statsFor(SportIds.pingPong).wins, 1);
    expect(ready.derivation.trendFor(SportIds.pingPong).map((p) => p.elo), [
      1200, // baseline: eloBefore of the first rated match
      1216,
    ]);
  });
}
