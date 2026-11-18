import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/core/theme/app_theme.dart';
import 'package:campus_arena/features/map/widgets/facility_detail_card.dart';
import 'package:campus_arena/features/weather/cubit/weather_cubit.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:campus_arena/repositories/weather_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMatchRepository extends Mock implements MatchRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockWeatherRepository extends Mock implements WeatherRepository {}

FacilityModel _facility({
  bool isOutdoor = false,
  String status = FacilityStatus.free,
  String? currentMatchId,
  String? kingOfTableUid,
  int kingOfTableWins = 0,
}) => FacilityModel(
  facilityId: 'f1',
  name: 'Table 2 — Bovisa Yard',
  sportId: SportIds.pingPong,
  coordinates: const Coordinates(latitude: 45.503, longitude: 9.158),
  qrCode: 'qr-f1',
  fallbackCode: 'fb-f1',
  isOutdoor: isOutdoor,
  status: status,
  currentMatchId: currentMatchId,
  kingOfTableUid: kingOfTableUid,
  kingOfTableWins: kingOfTableWins,
  queueTailPosition: 0,
);

MatchModel _match({int minutesAgo = 12}) => MatchModel(
  matchId: 'm1',
  facilityId: 'f1',
  sportId: SportIds.pingPong,
  mode: 'singles',
  playerUids: const ['p1', 'p2'],
  state: MatchStates.occupied,
  startedAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
);

UserModel _king() => UserModel(
  uid: 'king1',
  name: 'Gianni Ferrari',
  username: 'G. Ferrari',
  email: 'king@polimi.it',
  degreeProgram: 'Computer Science',
  language: 'en',
  pushTokens: const [],
  friendUids: const [],
  badges: const {},
  onboardingComplete: true,
  createdAt: DateTime(2026),
);

const _weather = WeatherSnapshot(
  temperatureC: 19.2,
  precipitationMm: 0.0,
  windSpeedKmh: 8.4,
  weatherCode: 2,
);

void main() {
  late MockMatchRepository matchRepository;
  late MockUserRepository userRepository;
  late MockWeatherRepository weatherRepository;
  late WeatherCubit weatherCubit;

  setUp(() {
    matchRepository = MockMatchRepository();
    userRepository = MockUserRepository();
    weatherRepository = MockWeatherRepository();
    weatherCubit = WeatherCubit(repository: weatherRepository);
    when(
      () => weatherRepository.getCurrentWeather(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    ).thenAnswer((_) async => _weather);
  });

  tearDown(() => weatherCubit.close());

  Widget wrap(FacilityModel facility, {Widget? queueSection, Locale? locale}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: FacilityDetailCard(
            facility: facility,
            matchRepository: matchRepository,
            userRepository: userRepository,
            weatherCubit: weatherCubit,
            queueSection: queueSection,
          ),
        ),
      ),
    );
  }

  testWidgets('shows name, status row and the disclaimer footer', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(_facility(status: FacilityStatus.occupied)));
    await tester.pumpAndSettle();

    expect(find.text('Table 2 — Bovisa Yard'), findsOneWidget);
    expect(find.text('Occupied'), findsOneWidget);
    expect(
      find.text(
        'Based on app activity only — the table may be in use by non-app '
        'players. Not a reservation.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows current players and match duration from the match doc', (
    tester,
  ) async {
    when(
      () => matchRepository.watchMatch('m1'),
    ).thenAnswer((_) => Stream.value(_match(minutesAgo: 12)));

    await tester.pumpWidget(
      wrap(_facility(status: FacilityStatus.occupied, currentMatchId: 'm1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Players'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Match duration'), findsOneWidget);
    expect(find.text('12 min'), findsOneWidget);
  });

  testWidgets('shows placeholders when there is no active match', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(_facility()));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsNWidgets(2));
    verifyNever(() => matchRepository.watchMatch(any()));
  });

  testWidgets('shows the King of the Table with resolved name and wins', (
    tester,
  ) async {
    when(
      () => userRepository.getUser('king1'),
    ).thenAnswer((_) async => _king());

    await tester.pumpWidget(
      wrap(_facility(kingOfTableUid: 'king1', kingOfTableWins: 24)),
    );
    await tester.pumpAndSettle();

    expect(find.text('King of the Table'), findsOneWidget);
    expect(find.text('G. Ferrari'), findsOneWidget);
    expect(find.text('24 wins'), findsOneWidget);
  });

  testWidgets('shows the empty king state when nobody holds the title', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(_facility()));
    await tester.pumpAndSettle();

    expect(find.text('No King of the Table yet'), findsOneWidget);
    verifyNever(() => userRepository.getUser(any()));
  });

  testWidgets('embeds the weather snippet for an outdoor facility', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(_facility(isOutdoor: true)));
    await tester.pumpAndSettle();

    expect(find.text('Outdoor'), findsOneWidget);
    expect(find.text('Weather'), findsOneWidget);
    expect(find.text('19°'), findsOneWidget);
  });

  testWidgets('shows no weather for an indoor facility', (tester) async {
    await tester.pumpWidget(wrap(_facility()));
    await tester.pumpAndSettle();

    expect(find.text('Outdoor'), findsNothing);
    expect(find.text('Weather'), findsNothing);
    verifyNever(
      () => weatherRepository.getCurrentWeather(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    );
  });

  testWidgets('renders the queueSection slot when provided', (tester) async {
    const probe = Key('queue_section_probe');

    await tester.pumpWidget(
      wrap(_facility(), queueSection: const SizedBox(key: probe, height: 40)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(probe), findsOneWidget);
  });

  testWidgets('renders localized status and disclaimer in Italian', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        _facility(status: FacilityStatus.occupied),
        locale: const Locale('it'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Occupato'), findsOneWidget);
    expect(
      find.text(
        "Basato solo sull'attività dell'app — il tavolo potrebbe essere "
        'occupato da giocatori esterni. Nessuna prenotazione.',
      ),
      findsOneWidget,
    );
  });
}
