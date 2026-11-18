import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/tournaments/cubit/tournament_cubit.dart';
import 'package:campus_arena/features/tournaments/cubit/tournament_state.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/models/tournament_model.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/facility_repository.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/tournament_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTournamentRepository extends Mock implements TournamentRepository {}

class MockMatchRepository extends Mock implements MatchRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockFacilityRepository extends Mock implements FacilityRepository {}

const _id = 't1';
final _now = DateTime(2026, 7, 1);

TournamentModel _tournament({
  String status = TournamentStatus.seeded,
  Map<String, List<String>> bracket = const {},
}) => TournamentModel(
  tournamentId: _id,
  name: 'Bovisa Open',
  sportId: SportIds.pingPong,
  facilityId: 'f1',
  organizerId: 'org',
  maxParticipants: 8,
  status: status,
  bracket: bracket,
  eloMultiplier: 1.5,
  registrationDeadline: DateTime(2026, 7, 5),
  scheduledAt: DateTime(2026, 7, 6),
  createdAt: DateTime(2026, 6, 30),
);

TournamentParticipantModel _p(String uid, int seed) =>
    TournamentParticipantModel(uid: uid, seed: seed, eliminated: false);

MatchModel _match(String id, List<String> players, {String? winner}) =>
    MatchModel(
      matchId: id,
      facilityId: 'f1',
      sportId: SportIds.pingPong,
      mode: 'singles',
      playerUids: players,
      state: MatchStates.confirmed,
      result: winner == null
          ? null
          : GenericMatchResult(winnerIds: [winner], score: const {}),
      startedAt: DateTime(2026, 7, 6),
    );

void main() {
  late MockTournamentRepository tournamentRepo;
  late MockMatchRepository matchRepo;
  late MockUserRepository userRepo;
  late MockFacilityRepository facilityRepo;

  setUp(() {
    tournamentRepo = MockTournamentRepository();
    matchRepo = MockMatchRepository();
    userRepo = MockUserRepository();
    facilityRepo = MockFacilityRepository();

    when(
      () => tournamentRepo.seedIfDue(any(), now: any(named: 'now')),
    ).thenAnswer((_) async {});
    when(
      () => tournamentRepo.activateIfStarted(any()),
    ).thenAnswer((_) async {});
    when(
      () => tournamentRepo.completeIfDecided(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => tournamentRepo.watchTournament(any()),
    ).thenAnswer((_) => Stream.value(_tournament()));
    when(
      () => tournamentRepo.watchParticipants(any()),
    ).thenAnswer((_) => Stream.value([_p('u1', 1), _p('u2', 2)]));
    when(
      () => matchRepo.watchTournamentMatches(any(), limit: any(named: 'limit')),
    ).thenAnswer((_) => Stream.value(<MatchModel>[]));
    when(() => facilityRepo.getFacility(any())).thenAnswer((_) async => null);
    when(
      () => userRepo.getUsersByIds(any()),
    ).thenAnswer((_) async => <UserModel>[]);
  });

  TournamentCubit makeCubit() => TournamentCubit(
    tournamentId: _id,
    uid: 'u1',
    tournamentRepository: tournamentRepo,
    matchRepository: matchRepo,
    userRepository: userRepo,
    facilityRepository: facilityRepo,
  );

  blocTest<TournamentCubit, TournamentState>(
    'load derives the bracket tree and reaches ready',
    build: makeCubit,
    act: (cubit) => cubit.load(now: _now),
    wait: const Duration(milliseconds: 50),
    verify: (cubit) {
      expect(cubit.state.status, BracketStatus.ready);
      expect(cubit.state.tree, isNotNull);
      expect(cubit.state.tree!.rounds, ['final']);
      final slot = cubit.state.tree!.slots['final']!.single;
      expect([slot.a.uid, slot.b.uid], ['u1', 'u2']);
      verify(() => tournamentRepo.seedIfDue(_id, now: _now)).called(1);
    },
  );

  blocTest<TournamentCubit, TournamentState>(
    'fires completeIfDecided once a champion is derived',
    setUp: () {
      when(() => tournamentRepo.watchTournament(any())).thenAnswer(
        (_) => Stream.value(
          _tournament(
            status: TournamentStatus.active,
            bracket: const {
              'final': ['m1'],
            },
          ),
        ),
      );
      when(
        () =>
            matchRepo.watchTournamentMatches(any(), limit: any(named: 'limit')),
      ).thenAnswer(
        (_) => Stream.value([
          _match('m1', ['u1', 'u2'], winner: 'u1'),
        ]),
      );
    },
    build: makeCubit,
    act: (cubit) => cubit.load(now: _now),
    wait: const Duration(milliseconds: 50),
    verify: (cubit) {
      expect(cubit.state.tree!.championUid, 'u1');
      verify(() => tournamentRepo.completeIfDecided(_id, 'u1')).called(1);
    },
  );

  test('a confirmed match re-derives the tree even though the tournament doc '
      'never changes (regression: the live bracket must not depend on the '
      'bracket map to notice a match confirmation)', () async {
    when(() => tournamentRepo.watchTournament(any())).thenAnswer(
      (_) => Stream.value(
        _tournament(
          status: TournamentStatus.active,
          bracket: const {
            'final': ['m1'],
          },
        ),
      ),
    );
    final matchesController = StreamController<List<MatchModel>>();
    when(
      () => matchRepo.watchTournamentMatches(any(), limit: any(named: 'limit')),
    ).thenAnswer((_) => matchesController.stream);

    final cubit = makeCubit();
    cubit.load(now: _now);

    matchesController.add([
      _match('m1', ['u1', 'u2']),
    ]); // no winner yet
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.tree!.championUid, isNull);

    matchesController.add([
      _match('m1', ['u1', 'u2'], winner: 'u1'),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.tree!.championUid, 'u1');

    await cubit.close();
    await matchesController.close();
  });

  blocTest<TournamentCubit, TournamentState>(
    'emits error when the tournament does not exist',
    setUp: () {
      when(
        () => tournamentRepo.watchTournament(any()),
      ).thenAnswer((_) => Stream.value(null));
    },
    build: makeCubit,
    act: (cubit) => cubit.load(now: _now),
    wait: const Duration(milliseconds: 20),
    verify: (cubit) => expect(cubit.state.status, BracketStatus.error),
  );

  blocTest<TournamentCubit, TournamentState>(
    'emits error when the tournament stream errors',
    setUp: () {
      when(
        () => tournamentRepo.watchTournament(any()),
      ).thenAnswer((_) => Stream.error(StateError('boom')));
    },
    build: makeCubit,
    act: (cubit) => cubit.load(now: _now),
    wait: const Duration(milliseconds: 20),
    verify: (cubit) => expect(cubit.state.status, BracketStatus.error),
  );

  test('seedIfDue fires once even as the tournament stream re-emits', () async {
    final controller = StreamController<TournamentModel?>();
    when(
      () => tournamentRepo.watchTournament(_id),
    ).thenAnswer((_) => controller.stream);

    final cubit = makeCubit();
    cubit.load(now: _now);
    controller.add(_tournament(status: TournamentStatus.seeded));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    controller.add(_tournament(status: TournamentStatus.active));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    verify(() => tournamentRepo.seedIfDue(_id, now: _now)).called(1);

    await cubit.close();
    await controller.close();
  });
}
