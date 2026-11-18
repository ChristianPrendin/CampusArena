import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/tournaments/cubit/create_tournament_cubit.dart';
import 'package:campus_arena/features/tournaments/cubit/create_tournament_state.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/models/tournament_model.dart';
import 'package:campus_arena/repositories/facility_repository.dart';
import 'package:campus_arena/repositories/tournament_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTournamentRepository extends Mock implements TournamentRepository {}

class MockFacilityRepository extends Mock implements FacilityRepository {}

class FakeTournamentModel extends Fake implements TournamentModel {}

FacilityModel _facility(String id, String sportId) => FacilityModel(
  facilityId: id,
  name: 'Table $id',
  sportId: sportId,
  coordinates: const Coordinates(latitude: 45, longitude: 9),
  qrCode: 'qr',
  fallbackCode: 'fb',
  isOutdoor: false,
  status: FacilityStatus.free,
  kingOfTableWins: 0,
  queueTailPosition: 0,
);

void main() {
  late MockTournamentRepository tournamentRepo;
  late MockFacilityRepository facilityRepo;

  final deadline = DateTime(2026, 8, 1, 17);
  final scheduled = DateTime(2026, 8, 1, 18);
  final now = DateTime(2026, 7, 1);

  setUpAll(() => registerFallbackValue(FakeTournamentModel()));

  setUp(() {
    tournamentRepo = MockTournamentRepository();
    facilityRepo = MockFacilityRepository();
    when(() => facilityRepo.watchFacilities()).thenAnswer(
      (_) => Stream.value([
        _facility('pp1', SportIds.pingPong),
        _facility('fb1', SportIds.foosball),
      ]),
    );
    when(
      () => tournamentRepo.createTournament(any()),
    ).thenAnswer((_) async => 'tid');
  });

  CreateTournamentCubit makeCubit() => CreateTournamentCubit(
    organizerId: 'org',
    tournamentRepository: tournamentRepo,
    facilityRepository: facilityRepo,
  );

  CreateTournamentCubit filled() => makeCubit()
    ..setName('Spring Slam')
    ..setFacility('pp1')
    ..setDeadline(deadline)
    ..setScheduledAt(scheduled);

  blocTest<CreateTournamentCubit, CreateTournamentState>(
    'loadFacilities filters to the selected sport',
    build: makeCubit,
    act: (cubit) => cubit.loadFacilities(),
    wait: const Duration(milliseconds: 10),
    verify: (cubit) {
      expect(cubit.state.facilities.map((f) => f.facilityId), ['pp1']);
    },
  );

  blocTest<CreateTournamentCubit, CreateTournamentState>(
    'setSport re-filters facilities and drops a mismatched selection',
    build: makeCubit,
    act: (cubit) async {
      cubit.loadFacilities();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      cubit.setFacility('pp1');
      cubit.setSport(SportIds.foosball);
    },
    verify: (cubit) {
      expect(cubit.state.sportId, SportIds.foosball);
      expect(cubit.state.facilities.map((f) => f.facilityId), ['fb1']);
      expect(cubit.state.facilityId, isNull);
    },
  );

  blocTest<CreateTournamentCubit, CreateTournamentState>(
    'max-participants stepper clamps to [4, 32]',
    build: () {
      final cubit = makeCubit();
      for (var i = 0; i < 40; i++) {
        cubit.incrementMax();
      }
      return cubit;
    },
    verify: (cubit) => expect(
      cubit.state.maxParticipants,
      CreateTournamentCubit.participantsMax,
    ),
  );

  blocTest<CreateTournamentCubit, CreateTournamentState>(
    'submit writes a registering tournament and reports success',
    build: filled,
    act: (cubit) => cubit.submit(now: now),
    expect: () => [
      isA<CreateTournamentState>().having(
        (s) => s.status,
        'status',
        CreateTournamentStatus.submitting,
      ),
      isA<CreateTournamentState>().having(
        (s) => s.status,
        'status',
        CreateTournamentStatus.success,
      ),
    ],
    verify: (cubit) {
      final captured =
          verify(
                () => tournamentRepo.createTournament(captureAny()),
              ).captured.single
              as TournamentModel;
      expect(captured.name, 'Spring Slam');
      expect(captured.status, TournamentStatus.registering);
      expect(captured.facilityId, 'pp1');
      expect(captured.eloMultiplier, 1.5);
      expect(captured.bracket, isEmpty);
      expect(captured.registrationDeadline, deadline);
    },
  );

  blocTest<CreateTournamentCubit, CreateTournamentState>(
    'submit blocks a deadline after the scheduled time',
    build: () => makeCubit()
      ..setName('Bad Order')
      ..setFacility('pp1')
      ..setDeadline(scheduled) // deadline after schedule
      ..setScheduledAt(deadline),
    act: (cubit) => cubit.submit(now: now),
    expect: () => [
      isA<CreateTournamentState>()
          .having((s) => s.status, 'status', CreateTournamentStatus.failure)
          .having((s) => s.error, 'error', CreateTournamentError.deadlineOrder),
    ],
    verify: (cubit) {
      verifyNever(() => tournamentRepo.createTournament(any()));
    },
  );

  blocTest<CreateTournamentCubit, CreateTournamentState>(
    'submit blocks a deadline in the past',
    build: filled,
    act: (cubit) => cubit.submit(now: deadline.add(const Duration(days: 1))),
    expect: () => [
      isA<CreateTournamentState>()
          .having((s) => s.status, 'status', CreateTournamentStatus.failure)
          .having(
            (s) => s.error,
            'error',
            CreateTournamentError.deadlineFuture,
          ),
    ],
    verify: (cubit) =>
        verifyNever(() => tournamentRepo.createTournament(any())),
  );

  blocTest<CreateTournamentCubit, CreateTournamentState>(
    'submit surfaces a repository failure',
    build: () {
      when(
        () => tournamentRepo.createTournament(any()),
      ).thenThrow(Exception('boom'));
      return filled();
    },
    act: (cubit) => cubit.submit(now: now),
    expect: () => [
      isA<CreateTournamentState>().having(
        (s) => s.status,
        'status',
        CreateTournamentStatus.submitting,
      ),
      isA<CreateTournamentState>()
          .having((s) => s.status, 'status', CreateTournamentStatus.failure)
          .having((s) => s.error, 'error', CreateTournamentError.createFailed),
    ],
  );
}
