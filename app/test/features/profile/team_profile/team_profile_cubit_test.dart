import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/profile/profile_stats.dart';
import 'package:campus_arena/features/profile/team_profile/cubit/team_profile_cubit.dart';
import 'package:campus_arena/features/profile/team_profile/cubit/team_profile_state.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/models/rating_model.dart';
import 'package:campus_arena/models/user_model.dart';
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

const _pairId = 'a_b';

UserModel _user(String uid, String name) => UserModel(
  uid: uid,
  name: name,
  username: name.toLowerCase(),
  email: '$uid@polimi.it',
  degreeProgram: 'Design',
  language: 'en',
  pushTokens: const [],
  friendUids: const [],
  badges: const {},
  onboardingComplete: true,
  createdAt: DateTime(2026),
);

RatingModel _pairRating({int elo = 1500}) => RatingModel(
  ratingId: RatingRepository.ratingId(SportIds.pingPong, _pairId),
  ownerType: OwnerType.pair,
  ownerId: _pairId,
  memberUids: const ['a', 'b'],
  sportId: SportIds.pingPong,
  elo: elo,
  matchesPlayed: 3,
  lastMatchAt: DateTime(2026, 6, 30),
);

MatchModel _doublesMatch() => MatchModel(
  matchId: 'd1',
  facilityId: 'f1',
  sportId: SportIds.pingPong,
  mode: MatchModes.doubles,
  playerUids: const ['a', 'b', 'c', 'd'],
  team1PairId: _pairId,
  team2PairId: 'c_d',
  state: MatchStates.confirmed,
  result: const PingPongResult(
    winnerIds: ['a', 'b'],
    sets: [11, 11],
    opponentSets: [5, 7],
  ),
  eloBefore: const {_pairId: 1488},
  eloDeltas: const {_pairId: 12},
  startedAt: DateTime(2026, 7, 2, 10),
  confirmedAt: DateTime(2026, 7, 2, 11),
);

void main() {
  late MockRatingRepository ratingRepo;
  late MockMatchRepository matchRepo;
  late MockUserRepository userRepo;
  late MockFacilityRepository facilityRepo;

  setUp(() {
    ratingRepo = MockRatingRepository();
    matchRepo = MockMatchRepository();
    userRepo = MockUserRepository();
    facilityRepo = MockFacilityRepository();

    when(
      () => ratingRepo.watchPairRatings(_pairId),
    ).thenAnswer((_) => Stream.value([_pairRating()]));
    when(
      () =>
          matchRepo.watchPairMatches(any(), any(), limit: any(named: 'limit')),
    ).thenAnswer((_) => Stream.value([_doublesMatch()]));
    when(
      () => userRepo.getUser('a'),
    ).thenAnswer((_) async => _user('a', 'Anna'));
    when(
      () => userRepo.getUser('b'),
    ).thenAnswer((_) async => _user('b', 'Bruno'));
    when(
      () => userRepo.getUser('c'),
    ).thenAnswer((_) async => _user('c', 'Carla'));
    when(
      () => userRepo.getUser('d'),
    ).thenAnswer((_) async => _user('d', 'Dario'));
    when(() => facilityRepo.getFacility(any())).thenAnswer((_) async => null);
  });

  // Synchronous derivation so the test doesn't spin up a real isolate.
  Future<ProfileDerivation> derive(TeamDerivationInput input) async =>
      deriveTeamStats(input);

  TeamProfileCubit build() => TeamProfileCubit(
    pairId: _pairId,
    ratingRepository: ratingRepo,
    matchRepository: matchRepo,
    userRepository: userRepo,
    facilityRepository: facilityRepo,
    derive: derive,
  );

  test('loads members, pair ratings, history and team derivation', () async {
    final cubit = build();
    addTearDown(cubit.close);

    // Settle the streams + async member/derivation resolution.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final state = cubit.state;
    expect(state.status, TeamProfileStatus.ready);
    expect(state.members.map((m) => m.uid), ['a', 'b']);
    expect(state.ratings.single.ownerId, _pairId);
    expect(state.matches.single.matchId, 'd1');
    // The pair won its one confirmed doubles match.
    final pp = state.selectedStats;
    expect(pp.games, 1);
    expect(pp.wins, 1);
    // Trend reads the pairId-keyed ELO maps: baseline + post-match.
    expect(state.selectedTrend.map((t) => t.elo), [1488, 1500]);
  });

  test('queries pair matches with one member uid', () async {
    final cubit = build();
    addTearDown(cubit.close);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    verify(
      () =>
          matchRepo.watchPairMatches(_pairId, 'a', limit: any(named: 'limit')),
    ).called(1);
  });
}
