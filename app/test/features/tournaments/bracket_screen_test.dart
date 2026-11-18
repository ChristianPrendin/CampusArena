import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/tournaments/bracket_screen.dart';
import 'package:campus_arena/features/tournaments/cubit/tournament_cubit.dart';
import 'package:campus_arena/features/weather/widgets/forecast_strip.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/models/tournament_model.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/facility_repository.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/tournament_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTournamentRepository extends Mock implements TournamentRepository {}

class MockMatchRepository extends Mock implements MatchRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockFacilityRepository extends Mock implements FacilityRepository {}

TournamentModel _tournament({
  String status = TournamentStatus.seeded,
  Map<String, List<String>> bracket = const {},
}) => TournamentModel(
  tournamentId: 't1',
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

FacilityModel _facility({required bool outdoor}) => FacilityModel(
  facilityId: 'f1',
  name: 'Court 1',
  sportId: SportIds.pingPong,
  coordinates: const Coordinates(latitude: 45, longitude: 9),
  qrCode: 'qr',
  fallbackCode: 'fb',
  isOutdoor: outdoor,
  status: FacilityStatus.free,
  kingOfTableWins: 0,
  queueTailPosition: 0,
);

UserModel _user(String uid, String name) => UserModel(
  uid: uid,
  name: name,
  username: name.toLowerCase(),
  email: '$uid@polimi.it',
  degreeProgram: 'CS',
  language: 'en',
  pushTokens: const [],
  friendUids: const [],
  badges: const {},
  onboardingComplete: true,
  createdAt: DateTime(2026),
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
      () => tournamentRepo.completeIfDecided(any(), any()),
    ).thenAnswer((_) async {});
  });

  TournamentCubit driveCubit({
    required TournamentModel tournament,
    required List<TournamentParticipantModel> participants,
    List<MatchModel> matches = const [],
    FacilityModel? facility,
    List<UserModel> users = const [],
  }) {
    when(
      () => tournamentRepo.watchTournament(any()),
    ).thenAnswer((_) => Stream.value(tournament));
    when(
      () => tournamentRepo.watchParticipants(any()),
    ).thenAnswer((_) => Stream.value(participants));
    when(
      () => matchRepo.watchTournamentMatches(any(), limit: any(named: 'limit')),
    ).thenAnswer((_) => Stream.value(matches));
    when(
      () => facilityRepo.getFacility(any()),
    ).thenAnswer((_) async => facility);
    when(() => userRepo.getUsersByIds(any())).thenAnswer((_) async => users);
    final cubit = TournamentCubit(
      tournamentId: 't1',
      uid: 'u1',
      tournamentRepository: tournamentRepo,
      matchRepository: matchRepo,
      userRepository: userRepo,
      facilityRepository: facilityRepo,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Widget wrap(TournamentCubit cubit) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider.value(value: cubit, child: const BracketView()),
  );

  Future<void> pumpBracket(WidgetTester tester, TournamentCubit cubit) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    cubit.load();
    await tester.pumpWidget(wrap(cubit));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('renders byes explicitly', (tester) async {
    // 3 participants → bracketSize 4 → one bye in the semifinal.
    final cubit = driveCubit(
      tournament: _tournament(),
      participants: [_p('u1', 1), _p('u2', 2), _p('u3', 3)],
      facility: _facility(outdoor: false),
      users: [_user('u1', 'Alice'), _user('u2', 'Bob'), _user('u3', 'Cara')],
    );

    await pumpBracket(tester, cubit);

    expect(find.text('BYE'), findsOneWidget);
  });

  testWidgets('highlights the winner name in bold', (tester) async {
    final cubit = driveCubit(
      tournament: _tournament(
        status: TournamentStatus.active,
        bracket: const {
          'final': ['m1'],
        },
      ),
      participants: [_p('u1', 1), _p('u2', 2)],
      matches: [
        _match('m1', ['u1', 'u2'], winner: 'u1'),
      ],
      facility: _facility(outdoor: false),
      users: [_user('u1', 'Alice'), _user('u2', 'Bob')],
    );

    await pumpBracket(tester, cubit);

    final winner = tester.widget<Text>(find.text('Alice'));
    final loser = tester.widget<Text>(find.text('Bob'));
    expect(winner.style?.fontWeight, FontWeight.w700);
    expect(loser.style?.fontWeight, isNot(FontWeight.w700));
  });

  testWidgets('shows the forecast strip only for an outdoor facility', (
    tester,
  ) async {
    final cubit = driveCubit(
      tournament: _tournament(),
      participants: [_p('u1', 1), _p('u2', 2)],
      facility: _facility(outdoor: true),
      users: [_user('u1', 'Alice'), _user('u2', 'Bob')],
    );

    await pumpBracket(tester, cubit);

    // The strip renders its FORECAST header only when outdoor.
    expect(find.byType(ForecastStrip), findsOneWidget);
    expect(find.text('FORECAST'), findsOneWidget);
  });

  testWidgets('hides the forecast for an indoor facility', (tester) async {
    final cubit = driveCubit(
      tournament: _tournament(),
      participants: [_p('u1', 1), _p('u2', 2)],
      facility: _facility(outdoor: false),
      users: [_user('u1', 'Alice'), _user('u2', 'Bob')],
    );

    await pumpBracket(tester, cubit);

    expect(find.text('FORECAST'), findsNothing);
  });

  testWidgets('shows the registration-open placeholder while registering', (
    tester,
  ) async {
    final cubit = driveCubit(
      tournament: _tournament(status: TournamentStatus.registering),
      participants: const [],
      facility: _facility(outdoor: false),
    );

    await pumpBracket(tester, cubit);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.tournamentRegistrationOpenTitle), findsOneWidget);
  });

  testWidgets('shows the cancelled placeholder for a cancelled tournament', (
    tester,
  ) async {
    final cubit = driveCubit(
      tournament: _tournament(status: TournamentStatus.cancelled),
      participants: const [],
    );

    await pumpBracket(tester, cubit);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.tournamentCancelledTitle), findsOneWidget);
  });

  testWidgets('shows the champion banner for a completed tournament', (
    tester,
  ) async {
    final cubit = driveCubit(
      tournament: _tournament(
        status: TournamentStatus.completed,
        bracket: const {
          'final': ['m1'],
        },
      ),
      participants: [_p('u1', 1), _p('u2', 2)],
      matches: [
        _match('m1', ['u1', 'u2'], winner: 'u1'),
      ],
      users: [_user('u1', 'Alice')],
    );

    await pumpBracket(tester, cubit);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.tournamentCompletedBanner('Alice')), findsOneWidget);
  });
}
