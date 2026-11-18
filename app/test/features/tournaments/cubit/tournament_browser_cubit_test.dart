import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/tournaments/cubit/tournament_browser_cubit.dart';
import 'package:campus_arena/features/tournaments/cubit/tournament_browser_state.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/models/tournament_model.dart';
import 'package:campus_arena/repositories/facility_repository.dart';
import 'package:campus_arena/repositories/tournament_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTournamentRepository extends Mock implements TournamentRepository {}

class MockFacilityRepository extends Mock implements FacilityRepository {}

TournamentModel _t({
  required String id,
  String sportId = SportIds.pingPong,
  String status = TournamentStatus.registering,
  DateTime? scheduledAt,
  int max = 8,
  int count = 0,
}) => TournamentModel(
  tournamentId: id,
  name: 'T-$id',
  sportId: sportId,
  facilityId: 'f1',
  organizerId: 'org',
  maxParticipants: max,
  participantCount: count,
  status: status,
  bracket: const {},
  eloMultiplier: 1.5,
  registrationDeadline: DateTime(2026, 7, 5),
  scheduledAt: scheduledAt ?? DateTime(2026, 7, 6, 18),
  createdAt: DateTime(2026, 6, 30),
);

void main() {
  late MockTournamentRepository tournamentRepository;
  late MockFacilityRepository facilityRepository;

  setUp(() {
    tournamentRepository = MockTournamentRepository();
    facilityRepository = MockFacilityRepository();

    when(
      () => tournamentRepository.watchTournaments(
        sportId: any(named: 'sportId'),
        statuses: any(named: 'statuses'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => const Stream.empty());
    when(() => facilityRepository.getFacility(any())).thenAnswer(
      (_) async => const FacilityModel(
        facilityId: 'f1',
        name: 'Table 1',
        sportId: SportIds.pingPong,
        coordinates: Coordinates(latitude: 45.47, longitude: 9.22),
        qrCode: 'qr',
        fallbackCode: 'FB',
        isOutdoor: false,
        status: FacilityStatus.free,
        kingOfTableWins: 0,
        queueTailPosition: 0,
      ),
    );
  });

  TournamentBrowserCubit build() => TournamentBrowserCubit(
    tournamentRepository: tournamentRepository,
    facilityRepository: facilityRepository,
  );

  test('constructor emits the initial state synchronously', () {
    final cubit = build();
    addTearDown(cubit.close);
    expect(cubit.state.status, TournamentBrowserStatus.loading);
    expect(cubit.state.selectedSportId, SportIds.supported.first);
  });

  blocTest<TournamentBrowserCubit, TournamentBrowserState>(
    'groups the feed into upcoming/ongoing sorted by scheduledAt',
    setUp: () {
      when(
        () => tournamentRepository.watchTournaments(
          sportId: SportIds.pingPong,
          statuses: any(named: 'statuses'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) => Stream.value([
          _t(id: 'active1', status: TournamentStatus.active),
          _t(
            id: 'reg_late',
            status: TournamentStatus.registering,
            scheduledAt: DateTime(2026, 7, 7),
          ),
          _t(
            id: 'reg_early',
            status: TournamentStatus.registering,
            scheduledAt: DateTime(2026, 7, 6),
          ),
          _t(id: 'seeded1', status: TournamentStatus.seeded),
        ]),
      );
    },
    build: build,
    act: (cubit) => cubit.init(),
    wait: const Duration(milliseconds: 10),
    verify: (cubit) {
      final s = cubit.state;
      expect(s.status, TournamentBrowserStatus.ready);
      // Upcoming = registering + seeded, sorted by scheduledAt ascending.
      expect(s.upcoming.map((t) => t.tournamentId), [
        'reg_early',
        'seeded1',
        'reg_late',
      ]);
      expect(s.ongoing.map((t) => t.tournamentId), ['active1']);
    },
  );

  blocTest<TournamentBrowserCubit, TournamentBrowserState>(
    'selectSport re-subscribes with the new sport',
    build: build,
    act: (cubit) {
      cubit.init();
      cubit.selectSport(SportIds.foosball);
    },
    verify: (cubit) {
      expect(cubit.state.selectedSportId, SportIds.foosball);
      verify(
        () => tournamentRepository.watchTournaments(
          sportId: SportIds.foosball,
          statuses: any(named: 'statuses'),
          limit: any(named: 'limit'),
        ),
      ).called(1);
    },
  );

  blocTest<TournamentBrowserCubit, TournamentBrowserState>(
    'participant count rides the feed without a subcollection read',
    setUp: () {
      when(
        () => tournamentRepository.watchTournaments(
          sportId: SportIds.pingPong,
          statuses: any(named: 'statuses'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => Stream.value([_t(id: 't1', count: 3)]));
    },
    build: build,
    act: (cubit) => cubit.init(),
    wait: const Duration(milliseconds: 10),
    verify: (cubit) {
      // The count comes off the denormalized feed doc — no per-card
      // participants subcollection read.
      expect(cubit.state.upcoming.single.participantCount, 3);
    },
  );

  blocTest<TournamentBrowserCubit, TournamentBrowserState>(
    'enrichment resolves the facility outdoor flag onto the card',
    setUp: () {
      when(
        () => tournamentRepository.watchTournaments(
          sportId: SportIds.pingPong,
          statuses: any(named: 'statuses'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => Stream.value([_t(id: 't1')]));
      when(() => facilityRepository.getFacility('f1')).thenAnswer(
        (_) async => const FacilityModel(
          facilityId: 'f1',
          name: 'Court',
          sportId: SportIds.pingPong,
          coordinates: Coordinates(latitude: 45.47, longitude: 9.22),
          qrCode: 'qr',
          fallbackCode: 'FB',
          isOutdoor: true,
          status: FacilityStatus.free,
          kingOfTableWins: 0,
          queueTailPosition: 0,
        ),
      );
    },
    build: build,
    act: (cubit) => cubit.init(),
    wait: const Duration(milliseconds: 10),
    verify: (cubit) {
      expect(cubit.state.infoFor('t1').outdoor, isTrue);
    },
  );
}
