import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/core/constants.dart' as fs;
import 'package:campus_arena/features/map/user_location_service.dart';
import 'package:campus_arena/features/match/cubit/match_cubit.dart';
import 'package:campus_arena/features/match/cubit/match_state.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/repositories/facility_repository.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/queue_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/tournament_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';

class MockMatchRepository extends Mock implements MatchRepository {}

class MockFacilityRepository extends Mock implements FacilityRepository {}

class MockQueueRepository extends Mock implements QueueRepository {}

class MockRatingRepository extends Mock implements RatingRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockUserLocationService extends Mock implements UserLocationService {}

class MockTournamentRepository extends Mock implements TournamentRepository {}

const _uid = 'me';
const _facilityId = 'f1';

FacilityModel _facility({String status = fs.FacilityStatus.free}) =>
    FacilityModel(
      facilityId: _facilityId,
      name: 'Table 3 — BL27',
      sportId: fs.SportIds.pingPong,
      coordinates: const Coordinates(latitude: 45.4784, longitude: 9.2272),
      qrCode: 'QR-F1',
      fallbackCode: 'BL27A',
      isOutdoor: false,
      status: status,
      kingOfTableWins: 0,
      queueTailPosition: 0,
    );

MatchModel _match({
  String id = 'm1',
  String state = fs.MatchStates.occupied,
  List<String> players = const [_uid],
  String mode = fs.MatchModes.singles,
}) => MatchModel(
  matchId: id,
  facilityId: _facilityId,
  sportId: fs.SportIds.pingPong,
  mode: mode,
  playerUids: players,
  state: state,
  startedAt: DateTime(2026, 7, 5, 10),
);

QueueEntryModel _queueEntry(String uid, int position) => QueueEntryModel(
  uid: uid,
  facilityId: _facilityId,
  position: position,
  joinedAt: DateTime(2026, 7, 5, 9),
);

void main() {
  late MockMatchRepository matchRepo;
  late MockFacilityRepository facilityRepo;
  late MockQueueRepository queueRepo;
  late MockRatingRepository ratingRepo;
  late MockUserRepository userRepo;
  late MockUserLocationService location;
  late MockTournamentRepository tournamentRepo;

  setUpAll(() {
    registerFallbackValue(_match());
  });

  setUp(() {
    matchRepo = MockMatchRepository();
    facilityRepo = MockFacilityRepository();
    queueRepo = MockQueueRepository();
    ratingRepo = MockRatingRepository();
    userRepo = MockUserRepository();
    location = MockUserLocationService();
    tournamentRepo = MockTournamentRepository();
    when(
      () => tournamentRepo.recordBracketMatch(any(), any(), any()),
    ).thenAnswer((_) async {});

    // Sensible defaults: empty queue, no location, no enrichment.
    when(
      () => queueRepo.watchQueue(any()),
    ).thenAnswer((_) => Stream.value(const <QueueEntryModel>[]));
    when(() => location.getCurrentPosition()).thenAnswer((_) async => null);
    when(() => userRepo.getUser(any())).thenAnswer((_) async => null);
    when(
      () => ratingRepo.getUserRating(any(), any()),
    ).thenAnswer((_) async => null);
  });

  // Deep-link entry drives openFacility from the call site (as MatchFlowPage
  // does), not the constructor — the cubit stays side-effect-free at build.
  MatchCubit build({
    String? facilityId,
    String? tournamentId,
    String? tournamentRound,
    String? expectedSportId,
  }) {
    final cubit = MatchCubit(
      uid: _uid,
      tournamentId: tournamentId,
      tournamentRound: tournamentRound,
      expectedSportId: expectedSportId,
      matchRepository: matchRepo,
      facilityRepository: facilityRepo,
      queueRepository: queueRepo,
      ratingRepository: ratingRepo,
      userRepository: userRepo,
      tournamentRepository: tournamentRepo,
      locationService: location,
    );
    if (facilityId != null) cubit.openFacility(facilityId);
    return cubit;
  }

  test('emits the idle initial state synchronously', () {
    final cubit = build();
    expect(cubit.state.status, MatchStatus.idle);
    cubit.close();
  });

  group('submitCode (blind scan)', () {
    blocTest<MatchCubit, MatchState>(
      'resolves a facility by id and becomes readyToConfirm',
      setUp: () {
        when(
          () => facilityRepo.getFacility(_facilityId),
        ).thenAnswer((_) async => _facility());
      },
      build: build,
      act: (cubit) => cubit.submitCode(_facilityId),
      expect: () => [
        isA<MatchState>().having(
          (s) => s.status,
          'status',
          MatchStatus.resolving,
        ),
        isA<MatchState>()
            .having((s) => s.status, 'status', MatchStatus.readyToConfirm)
            .having((s) => s.facility?.facilityId, 'facility', _facilityId)
            .having((s) => s.gpsFar, 'gpsFar', false),
      ],
    );

    blocTest<MatchCubit, MatchState>(
      'falls back to the printed fallbackCode when the id lookup misses',
      setUp: () {
        when(
          () => facilityRepo.getFacility(any()),
        ).thenAnswer((_) async => null);
        when(
          () => facilityRepo.watchFacilities(),
        ).thenAnswer((_) => Stream.value([_facility()]));
      },
      build: build,
      act: (cubit) => cubit.submitCode('bl27a'),
      expect: () => [
        isA<MatchState>().having(
          (s) => s.status,
          'status',
          MatchStatus.resolving,
        ),
        isA<MatchState>()
            .having((s) => s.status, 'status', MatchStatus.readyToConfirm)
            .having((s) => s.facility?.facilityId, 'facility', _facilityId),
      ],
    );

    blocTest<MatchCubit, MatchState>(
      'emits an invalidCode error when nothing resolves',
      setUp: () {
        when(
          () => facilityRepo.getFacility(any()),
        ).thenAnswer((_) async => null);
        when(
          () => facilityRepo.watchFacilities(),
        ).thenAnswer((_) => Stream.value(const <FacilityModel>[]));
      },
      build: build,
      act: (cubit) => cubit.submitCode('nope'),
      expect: () => [
        isA<MatchState>().having(
          (s) => s.status,
          'status',
          MatchStatus.resolving,
        ),
        isA<MatchState>()
            .having((s) => s.status, 'status', MatchStatus.error)
            .having(
              (s) => s.errorKind,
              'errorKind',
              MatchErrorKind.invalidCode,
            ),
      ],
    );

    blocTest<MatchCubit, MatchState>(
      'rejects a table whose sport differs from an accepted challenge',
      setUp: () {
        when(
          () => facilityRepo.getFacility(_facilityId),
        ).thenAnswer((_) async => _facility()); // ping_pong table
      },
      build: () => build(expectedSportId: fs.SportIds.foosball),
      act: (cubit) => cubit.submitCode(_facilityId),
      expect: () => [
        isA<MatchState>().having(
          (s) => s.status,
          'status',
          MatchStatus.resolving,
        ),
        isA<MatchState>()
            .having((s) => s.status, 'status', MatchStatus.error)
            .having(
              (s) => s.errorKind,
              'errorKind',
              MatchErrorKind.sportMismatch,
            ),
      ],
    );

    blocTest<MatchCubit, MatchState>(
      'accepts a table matching the accepted challenge sport',
      setUp: () {
        when(
          () => facilityRepo.getFacility(_facilityId),
        ).thenAnswer((_) async => _facility()); // ping_pong table
      },
      build: () => build(expectedSportId: fs.SportIds.pingPong),
      act: (cubit) => cubit.submitCode(_facilityId),
      expect: () => [
        isA<MatchState>().having(
          (s) => s.status,
          'status',
          MatchStatus.resolving,
        ),
        isA<MatchState>().having(
          (s) => s.status,
          'status',
          MatchStatus.readyToConfirm,
        ),
      ],
    );

    blocTest<MatchCubit, MatchState>(
      'flags gpsFar when the fix is beyond the soft threshold',
      setUp: () {
        when(
          () => facilityRepo.getFacility(_facilityId),
        ).thenAnswer((_) async => _facility());
        // ~1.5 km north of the facility → well past 100 m.
        when(
          () => location.getCurrentPosition(),
        ).thenAnswer((_) async => const LatLng(45.4920, 9.2272));
      },
      build: build,
      act: (cubit) => cubit.submitCode(_facilityId),
      skip: 1,
      expect: () => [
        isA<MatchState>()
            .having((s) => s.status, 'status', MatchStatus.readyToConfirm)
            .having((s) => s.gpsFar, 'gpsFar', true),
      ],
    );

    blocTest<MatchCubit, MatchState>(
      'reads queue standing so a non-front scanner trips the priority warning',
      setUp: () {
        when(
          () => facilityRepo.getFacility(_facilityId),
        ).thenAnswer((_) async => _facility());
        when(() => queueRepo.watchQueue(_facilityId)).thenAnswer(
          (_) => Stream.value([_queueEntry('front', 1), _queueEntry(_uid, 2)]),
        );
      },
      build: build,
      act: (cubit) => cubit.submitCode(_facilityId),
      skip: 1,
      verify: (cubit) {
        expect(cubit.state.queuePosition, 2);
        expect(cubit.state.queueFrontPosition, 1);
        expect(cubit.state.queuePriorityWarning, isTrue);
      },
    );
  });

  group('confirmCheckIn tournament context', () {
    blocTest<MatchCubit, MatchState>(
      'persists tournamentId/round on the match and records the bracket slot',
      setUp: () {
        when(
          () => facilityRepo.getFacility(_facilityId),
        ).thenAnswer((_) async => _facility());
        when(() => matchRepo.createMatch(any())).thenAnswer((_) async => 'm1');
        when(
          () => matchRepo.watchMatch('m1'),
        ).thenAnswer((_) => Stream.value(_match(players: const [_uid])));
      },
      build: () => build(tournamentId: 't1', tournamentRound: 'final'),
      act: (cubit) async {
        await cubit.submitCode(_facilityId);
        await cubit.confirmCheckIn();
      },
      verify: (cubit) {
        final created =
            verify(() => matchRepo.createMatch(captureAny())).captured.single
                as MatchModel;
        expect(created.tournamentId, 't1');
        expect(created.tournamentRound, 'final');
        verify(
          () => tournamentRepo.recordBracketMatch('t1', 'final', 'm1'),
        ).called(1);
      },
    );

    blocTest<MatchCubit, MatchState>(
      'a walk-up (no context) never records a bracket slot',
      setUp: () {
        when(
          () => facilityRepo.getFacility(_facilityId),
        ).thenAnswer((_) async => _facility());
        when(() => matchRepo.createMatch(any())).thenAnswer((_) async => 'm1');
        when(
          () => matchRepo.watchMatch('m1'),
        ).thenAnswer((_) => Stream.value(_match(players: const [_uid])));
      },
      build: build,
      act: (cubit) async {
        await cubit.submitCode(_facilityId);
        await cubit.confirmCheckIn();
      },
      verify: (cubit) {
        final created =
            verify(() => matchRepo.createMatch(captureAny())).captured.single
                as MatchModel;
        expect(created.tournamentId, isNull);
        verifyNever(
          () => tournamentRepo.recordBracketMatch(any(), any(), any()),
        );
      },
    );
  });

  group('confirmCheckIn doubles', () {
    blocTest<MatchCubit, MatchState>(
      'creates a doubles match seeding the creator on their chosen side',
      setUp: () {
        when(
          () => facilityRepo.getFacility(_facilityId),
        ).thenAnswer((_) async => _facility());
        when(() => matchRepo.createMatch(any())).thenAnswer((_) async => 'm1');
        when(
          () => matchRepo.watchMatch('m1'),
        ).thenAnswer((_) => Stream.value(_match(players: const [_uid])));
      },
      build: build,
      act: (cubit) async {
        await cubit.submitCode(_facilityId);
        await cubit.confirmCheckIn(mode: fs.MatchModes.doubles, creatorTeam: 2);
      },
      verify: (cubit) {
        final created =
            verify(() => matchRepo.createMatch(captureAny())).captured.single
                as MatchModel;
        expect(created.mode, fs.MatchModes.doubles);
        expect(created.playerUids, [_uid]);
        // Creator seeded on Team 2 as a single-member pairId (their own uid).
        expect(created.team1PairId, isNull);
        expect(created.team2PairId, _uid);
      },
    );
  });

  group('confirmCheckIn (writer contract)', () {
    blocTest<MatchCubit, MatchState>(
      'creates the match and reflects the streamed occupied/waiting state',
      setUp: () {
        when(
          () => facilityRepo.getFacility(_facilityId),
        ).thenAnswer((_) async => _facility());
        when(() => matchRepo.createMatch(any())).thenAnswer((_) async => 'm1');
        when(
          () => matchRepo.watchMatch('m1'),
        ).thenAnswer((_) => Stream.value(_match(players: const [_uid])));
      },
      build: build,
      act: (cubit) async {
        await cubit.submitCode(_facilityId);
        await cubit.confirmCheckIn();
      },
      verify: (cubit) {
        verify(() => matchRepo.createMatch(any())).called(1);
        expect(cubit.state.status, MatchStatus.waitingOpponent);
        expect(cubit.state.match?.matchId, 'm1');
      },
    );

    blocTest<MatchCubit, MatchState>(
      'reaches active once the streamed match has a full roster',
      setUp: () {
        when(
          () => facilityRepo.getFacility(_facilityId),
        ).thenAnswer((_) async => _facility());
        when(() => matchRepo.createMatch(any())).thenAnswer((_) async => 'm1');
        when(
          () => matchRepo.watchMatch('m1'),
        ).thenAnswer((_) => Stream.value(_match(players: const [_uid, 'opp'])));
      },
      build: build,
      act: (cubit) async {
        await cubit.submitCode(_facilityId);
        await cubit.confirmCheckIn();
      },
      verify: (cubit) => expect(cubit.state.status, MatchStatus.active),
    );

    blocTest<MatchCubit, MatchState>(
      'surfaces a checkIn error when the create fails (offline)',
      setUp: () {
        when(
          () => facilityRepo.getFacility(_facilityId),
        ).thenAnswer((_) async => _facility());
        when(
          () => matchRepo.createMatch(any()),
        ).thenThrow(Exception('offline'));
      },
      build: build,
      act: (cubit) async {
        await cubit.submitCode(_facilityId);
        await cubit.confirmCheckIn();
      },
      verify: (cubit) {
        expect(cubit.state.status, MatchStatus.error);
        expect(cubit.state.errorKind, MatchErrorKind.checkIn);
      },
    );

    blocTest<MatchCubit, MatchState>(
      'attaches to the live match if the table was taken between prepare and '
      'confirm (joining its open slot, same path as a deep link)',
      setUp: () {
        when(
          () => facilityRepo.getFacility(_facilityId),
        ).thenAnswer((_) async => _facility());
        when(
          () => matchRepo.createMatch(any()),
        ).thenThrow(StateError('Facility is currently occupied.'));
        // The create-race fallback now probes the live match the same way the
        // deep-link path does, then joins its open slot.
        when(
          () => matchRepo.getActiveMatchForFacility(_facilityId),
        ).thenAnswer((_) async => _match(id: 'live', players: const ['opp']));
        when(
          () => matchRepo.joinMatch(
            facilityId: any(named: 'facilityId'),
            uid: any(named: 'uid'),
          ),
        ).thenAnswer((_) async => 'live');
        when(() => matchRepo.watchMatch('live')).thenAnswer(
          (_) => Stream.value(_match(id: 'live', players: const ['opp', _uid])),
        );
      },
      build: build,
      act: (cubit) async {
        await cubit.submitCode(_facilityId);
        await cubit.confirmCheckIn();
      },
      verify: (cubit) {
        verify(
          () => matchRepo.joinMatch(
            facilityId: any(named: 'facilityId'),
            uid: any(named: 'uid'),
          ),
        ).called(1);
        expect(cubit.state.status, MatchStatus.active);
        expect(cubit.state.match?.matchId, 'live');
      },
    );

    blocTest<MatchCubit, MatchState>(
      'blind-scanning a non-joinable table (awaiting confirmation, not in it) '
      'is rejected as busy instead of spectating',
      setUp: () {
        when(
          () => facilityRepo.getFacility(_facilityId),
        ).thenAnswer((_) async => _facility());
        when(
          () => matchRepo.createMatch(any()),
        ).thenThrow(StateError('Facility is currently occupied.'));
        // The live match belongs to two other players and is already awaiting
        // confirmation: there is no slot for this scanner, so the fallback must
        // fail with tableBusy rather than drop them into a spectator view of a
        // match they cannot act on.
        when(() => matchRepo.getActiveMatchForFacility(_facilityId)).thenAnswer(
          (_) async => _match(
            id: 'live',
            players: const ['a', 'b'],
            state: fs.MatchStates.awaitingConfirmation,
          ),
        );
      },
      build: build,
      act: (cubit) async {
        await cubit.submitCode(_facilityId);
        await cubit.confirmCheckIn();
      },
      verify: (cubit) {
        expect(cubit.state.status, MatchStatus.error);
        expect(cubit.state.errorKind, MatchErrorKind.tableBusy);
        // Never attaches to the other players' match.
        verifyNever(() => matchRepo.watchMatch('live'));
      },
    );
  });

  group('streamed lifecycle', () {
    blocTest<MatchCubit, MatchState>(
      'maps awaitingConfirmation → resultSubmitted → confirmed from the doc',
      setUp: () {
        when(
          () => facilityRepo.getFacility(_facilityId),
        ).thenAnswer((_) async => _facility());
        when(() => matchRepo.createMatch(any())).thenAnswer((_) async => 'm1');
        final controller = StreamController<MatchModel?>();
        when(
          () => matchRepo.watchMatch('m1'),
        ).thenAnswer((_) => controller.stream);
        addTearDown(controller.close);
        _lifecycle = controller;
      },
      build: build,
      act: (cubit) async {
        await cubit.submitCode(_facilityId);
        await cubit.confirmCheckIn();
        _lifecycle.add(
          _match(players: const [_uid, 'opp'], state: fs.MatchStates.occupied),
        );
        await Future<void>.delayed(Duration.zero);
        _lifecycle.add(
          _match(
            players: const [_uid, 'opp'],
            state: fs.MatchStates.awaitingConfirmation,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        _lifecycle.add(
          _match(players: const [_uid, 'opp'], state: fs.MatchStates.confirmed),
        );
        await Future<void>.delayed(Duration.zero);
      },
      verify: (cubit) => expect(cubit.state.status, MatchStatus.confirmed),
    );
  });

  group('openFacility (deep link)', () {
    blocTest<MatchCubit, MatchState>(
      'attaches to an already-live match at the facility',
      setUp: () {
        when(() => facilityRepo.getFacility(_facilityId)).thenAnswer(
          (_) async => _facility(status: fs.FacilityStatus.occupied),
        );
        when(() => matchRepo.getActiveMatchForFacility(_facilityId)).thenAnswer(
          (_) async => _match(id: 'live', players: const [_uid, 'opp']),
        );
        when(() => matchRepo.watchMatch('live')).thenAnswer(
          (_) => Stream.value(_match(id: 'live', players: const [_uid, 'opp'])),
        );
      },
      build: () => build(facilityId: _facilityId),
      verify: (cubit) {
        expect(cubit.state.status, MatchStatus.active);
        expect(cubit.state.match?.matchId, 'live');
      },
    );

    blocTest<MatchCubit, MatchState>(
      'auto-joins a live match with an open slot when deep-linked',
      setUp: () {
        when(() => facilityRepo.getFacility(_facilityId)).thenAnswer(
          (_) async => _facility(status: fs.FacilityStatus.occupied),
        );
        when(
          () => matchRepo.getActiveMatchForFacility(_facilityId),
        ).thenAnswer((_) async => _match(id: 'live', players: const ['opp']));
        when(
          () => matchRepo.joinMatch(
            facilityId: any(named: 'facilityId'),
            uid: any(named: 'uid'),
          ),
        ).thenAnswer((_) async => 'live');
        when(() => matchRepo.watchMatch('live')).thenAnswer(
          (_) => Stream.value(_match(id: 'live', players: const ['opp', _uid])),
        );
      },
      build: () => build(facilityId: _facilityId),
      verify: (cubit) {
        verify(
          () => matchRepo.joinMatch(facilityId: _facilityId, uid: _uid),
        ).called(1);
        expect(cubit.state.status, MatchStatus.active);
      },
    );

    blocTest<MatchCubit, MatchState>(
      'prepares a check-in when the deep-linked facility is free',
      setUp: () {
        when(
          () => facilityRepo.getFacility(_facilityId),
        ).thenAnswer((_) async => _facility());
        when(
          () => matchRepo.getActiveMatchForFacility(_facilityId),
        ).thenAnswer((_) async => null);
      },
      build: () => build(facilityId: _facilityId),
      verify: (cubit) => expect(cubit.state.status, MatchStatus.readyToConfirm),
    );

    blocTest<MatchCubit, MatchState>(
      'surfaces a checkIn error when the active-match probe itself fails, '
      'never silently treats it as no live match',
      setUp: () {
        when(() => facilityRepo.getFacility(_facilityId)).thenAnswer(
          (_) async => _facility(status: fs.FacilityStatus.occupied),
        );
        when(
          () => matchRepo.getActiveMatchForFacility(_facilityId),
        ).thenThrow(Exception('offline'));
      },
      build: () => build(facilityId: _facilityId),
      verify: (cubit) {
        expect(cubit.state.status, MatchStatus.error);
        expect(cubit.state.errorKind, MatchErrorKind.checkIn);
        verifyNever(() => matchRepo.createMatch(any()));
      },
    );

    blocTest<MatchCubit, MatchState>(
      'auto-joins a 1v1 opponent already checked in at the table',
      setUp: () {
        when(() => facilityRepo.getFacility(_facilityId)).thenAnswer(
          (_) async => _facility(status: fs.FacilityStatus.occupied),
        );
        when(
          () => matchRepo.getActiveMatchForFacility(_facilityId),
        ).thenAnswer((_) async => _match(id: 'live', players: const ['opp']));
        when(
          () => matchRepo.joinMatch(
            facilityId: any(named: 'facilityId'),
            uid: any(named: 'uid'),
          ),
        ).thenAnswer((_) async => 'live');
        when(() => matchRepo.watchMatch('live')).thenAnswer(
          (_) => Stream.value(_match(id: 'live', players: const ['opp', _uid])),
        );
      },
      build: () => build(facilityId: _facilityId),
      verify: (cubit) {
        verify(
          () => matchRepo.joinMatch(facilityId: _facilityId, uid: _uid),
        ).called(1);
        expect(cubit.state.status, MatchStatus.active);
      },
    );

    blocTest<MatchCubit, MatchState>(
      'attaches (without auto-joining) a 2v2 table with an open slot so the '
      'side picker can surface',
      setUp: () {
        when(() => facilityRepo.getFacility(_facilityId)).thenAnswer(
          (_) async => _facility(status: fs.FacilityStatus.occupied),
        );
        when(() => matchRepo.getActiveMatchForFacility(_facilityId)).thenAnswer(
          (_) async => _match(
            id: 'live',
            mode: fs.MatchModes.doubles,
            players: const ['p1', 'p2', 'p3'],
          ),
        );
        when(() => matchRepo.watchMatch('live')).thenAnswer(
          (_) => Stream.value(
            _match(
              id: 'live',
              mode: fs.MatchModes.doubles,
              players: const ['p1', 'p2', 'p3'],
            ),
          ),
        );
      },
      build: () => build(facilityId: _facilityId),
      verify: (cubit) {
        // Doubles never auto-joins: the side picker calls joinMatch via joinSide.
        verifyNever(
          () => matchRepo.joinMatch(
            facilityId: any(named: 'facilityId'),
            uid: any(named: 'uid'),
          ),
        );
        expect(cubit.state.match?.matchId, 'live');
      },
    );

    blocTest<MatchCubit, MatchState>(
      'rejects a full 2v2 table (4 players, not a participant) as busy',
      setUp: () {
        when(() => facilityRepo.getFacility(_facilityId)).thenAnswer(
          (_) async => _facility(status: fs.FacilityStatus.occupied),
        );
        when(() => matchRepo.getActiveMatchForFacility(_facilityId)).thenAnswer(
          (_) async => _match(
            id: 'live',
            mode: fs.MatchModes.doubles,
            players: const ['p1', 'p2', 'p3', 'p4'],
          ),
        );
      },
      build: () => build(facilityId: _facilityId),
      verify: (cubit) {
        expect(cubit.state.status, MatchStatus.error);
        expect(cubit.state.errorKind, MatchErrorKind.tableBusy);
        verifyNever(() => matchRepo.watchMatch(any()));
      },
    );
  });

  group('leave (abandon-on-back)', () {
    blocTest<MatchCubit, MatchState>(
      'cancels (not abandons) a solo check-in the opponent never joined',
      setUp: () {
        when(
          () => facilityRepo.getFacility(_facilityId),
        ).thenAnswer((_) async => _facility());
        when(() => matchRepo.createMatch(any())).thenAnswer((_) async => 'm1');
        when(
          () => matchRepo.watchMatch('m1'),
        ).thenAnswer((_) => Stream.value(_match(players: const [_uid])));
        when(
          () => matchRepo.cancelMatch(
            matchId: any(named: 'matchId'),
            facilityId: any(named: 'facilityId'),
          ),
        ).thenAnswer((_) async {});
      },
      build: build,
      act: (cubit) async {
        await cubit.submitCode(_facilityId);
        await cubit.confirmCheckIn();
        // Let the watchMatch stream emit so state.match is populated.
        await Future<void>.delayed(Duration.zero);
        await cubit.leave();
      },
      verify: (_) {
        verify(
          () => matchRepo.cancelMatch(matchId: 'm1', facilityId: _facilityId),
        ).called(1);
        verifyNever(
          () => matchRepo.abandonMatch(
            matchId: any(named: 'matchId'),
            facilityId: any(named: 'facilityId'),
          ),
        );
      },
    );

    blocTest<MatchCubit, MatchState>(
      'abandons a match the opponent had already joined',
      setUp: () {
        when(
          () => facilityRepo.getFacility(_facilityId),
        ).thenAnswer((_) async => _facility());
        when(() => matchRepo.createMatch(any())).thenAnswer((_) async => 'm1');
        when(
          () => matchRepo.watchMatch('m1'),
        ).thenAnswer((_) => Stream.value(_match(players: const [_uid, 'opp'])));
        when(
          () => matchRepo.abandonMatch(
            matchId: any(named: 'matchId'),
            facilityId: any(named: 'facilityId'),
          ),
        ).thenAnswer((_) async {});
      },
      build: build,
      act: (cubit) async {
        await cubit.submitCode(_facilityId);
        await cubit.confirmCheckIn();
        await Future<void>.delayed(Duration.zero);
        await cubit.leave();
      },
      verify: (_) {
        verify(
          () => matchRepo.abandonMatch(matchId: 'm1', facilityId: _facilityId),
        ).called(1);
        verifyNever(
          () => matchRepo.cancelMatch(
            matchId: any(named: 'matchId'),
            facilityId: any(named: 'facilityId'),
          ),
        );
      },
    );

    blocTest<MatchCubit, MatchState>(
      'a non-participant scanning a full table is rejected as busy and frees '
      'nothing on leave',
      setUp: () {
        when(() => facilityRepo.getFacility(_facilityId)).thenAnswer(
          (_) async => _facility(status: fs.FacilityStatus.occupied),
        );
        // The live match's roster is full and belongs to two other players, so
        // this scanner cannot join: they are rejected with tableBusy and never
        // attach. A subsequent leave must not free someone else's table.
        when(() => matchRepo.getActiveMatchForFacility(_facilityId)).thenAnswer(
          (_) async => _match(id: 'live', players: const ['p1', 'p2']),
        );
      },
      build: () => build(facilityId: _facilityId),
      act: (cubit) async {
        // Let the deep-link openFacility resolve first.
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await cubit.leave();
      },
      verify: (cubit) {
        expect(cubit.state.status, MatchStatus.error);
        expect(cubit.state.errorKind, MatchErrorKind.tableBusy);
        verifyNever(() => matchRepo.watchMatch(any()));
        verifyNever(
          () => matchRepo.abandonMatch(
            matchId: any(named: 'matchId'),
            facilityId: any(named: 'facilityId'),
          ),
        );
        verifyNever(
          () => matchRepo.cancelMatch(
            matchId: any(named: 'matchId'),
            facilityId: any(named: 'facilityId'),
          ),
        );
      },
    );

    blocTest<MatchCubit, MatchState>(
      'frees the table when re-entering your own solo table as a viewer',
      setUp: () {
        when(() => facilityRepo.getFacility(_facilityId)).thenAnswer(
          (_) async => _facility(status: fs.FacilityStatus.occupied),
        );
        // Deep-linking back into my own occupied table attaches me as a viewer
        // (createdByMe would be false), but I am still in the roster.
        when(
          () => matchRepo.getActiveMatchForFacility(_facilityId),
        ).thenAnswer((_) async => _match(id: 'mine', players: const [_uid]));
        when(() => matchRepo.watchMatch('mine')).thenAnswer(
          (_) => Stream.value(_match(id: 'mine', players: const [_uid])),
        );
        when(
          () => matchRepo.cancelMatch(
            matchId: any(named: 'matchId'),
            facilityId: any(named: 'facilityId'),
          ),
        ).thenAnswer((_) async {});
      },
      build: () => build(facilityId: _facilityId),
      act: (cubit) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await cubit.leave();
      },
      verify: (_) {
        verify(
          () => matchRepo.cancelMatch(matchId: 'mine', facilityId: _facilityId),
        ).called(1);
      },
    );
  });
}

late StreamController<MatchModel?> _lifecycle;
