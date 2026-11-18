import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/tournaments/cubit/tournament_browser_cubit.dart';
import 'package:campus_arena/features/tournaments/cubit/tournament_browser_state.dart';
import 'package:campus_arena/features/tournaments/tournament_browser_screen.dart';
import 'package:campus_arena/features/tournaments/widgets/tournament_card.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/models/tournament_model.dart';
import 'package:campus_arena/repositories/facility_repository.dart';
import 'package:campus_arena/repositories/tournament_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTournamentRepository extends Mock implements TournamentRepository {}

class MockFacilityRepository extends Mock implements FacilityRepository {}

TournamentModel _t({
  String id = 't1',
  String status = TournamentStatus.registering,
  int max = 16,
  int count = 0,
}) => TournamentModel(
  tournamentId: id,
  name: 'Friday Night Smash',
  sportId: SportIds.pingPong,
  facilityId: 'f1',
  organizerId: 'org',
  maxParticipants: max,
  participantCount: count,
  status: status,
  bracket: const {},
  eloMultiplier: 1.5,
  registrationDeadline: DateTime(2026, 7, 5),
  scheduledAt: DateTime(2026, 7, 6, 18),
  createdAt: DateTime(2026, 6, 30),
);

Widget _cardHost(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  group('upcoming card', () {
    testWidgets('shows the participant progress and no inline action', (
      tester,
    ) async {
      await tester.pumpWidget(
        _cardHost(
          UpcomingTournamentCard(
            tournament: _t(max: 8, count: 6),
            info: const TournamentCardInfo(),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('6/8'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // Registration moved to the detail screen — no button on the card.
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });
  });

  group('ongoing card', () {
    testWidgets('taps through to detail with no inline action', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _cardHost(
          OngoingTournamentCard(
            tournament: _t(status: TournamentStatus.active, count: 8),
            onTap: () => tapped = true,
          ),
        ),
      );
      expect(find.byType(OutlinedButton), findsNothing);
      await tester.tap(find.byType(OngoingTournamentCard));
      expect(tapped, isTrue);
    });
  });

  group('browser screen', () {
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
      ).thenAnswer((_) => Stream.value([_t()]));
      when(() => facilityRepository.getFacility(any())).thenAnswer(
        (_) async => const FacilityModel(
          facilityId: 'f1',
          name: 'T',
          sportId: SportIds.pingPong,
          coordinates: Coordinates(latitude: 45.4, longitude: 9.2),
          qrCode: 'q',
          fallbackCode: 'F',
          isOutdoor: false,
          status: FacilityStatus.free,
          kingOfTableWins: 0,
          queueTailPosition: 0,
        ),
      );
    });

    TournamentBrowserCubit cubit() => TournamentBrowserCubit(
      tournamentRepository: tournamentRepository,
      facilityRepository: facilityRepository,
    )..init();

    Widget wrap(
      TournamentBrowserCubit c, {
      Locale locale = const Locale('en'),
    }) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: c,
          child: const TournamentBrowserView(),
        ),
      );
    }

    testWidgets('tapping a sport chip re-subscribes for that sport', (
      tester,
    ) async {
      final c = cubit();
      addTearDown(c.close);
      await tester.pumpWidget(wrap(c));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Foosball'));
      await tester.pumpAndSettle();

      verify(
        () => tournamentRepository.watchTournaments(
          sportId: SportIds.foosball,
          statuses: any(named: 'statuses'),
          limit: any(named: 'limit'),
        ),
      ).called(1);
    });

    testWidgets('renders Italian copy under the it locale', (tester) async {
      final c = cubit();
      addTearDown(c.close);
      await tester.pumpWidget(wrap(c, locale: const Locale('it')));
      await tester.pumpAndSettle();

      // UPCOMING header, uppercased.
      expect(find.text('PROSSIMI'), findsOneWidget);
    });

    testWidgets('shows the empty state when there are no tournaments', (
      tester,
    ) async {
      when(
        () => tournamentRepository.watchTournaments(
          sportId: any(named: 'sportId'),
          statuses: any(named: 'statuses'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => Stream.value(const []));

      final c = cubit();
      addTearDown(c.close);
      await tester.pumpWidget(wrap(c));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
      expect(find.byType(UpcomingTournamentCard), findsNothing);
    });

    testWidgets('renders the ongoing section for an active tournament', (
      tester,
    ) async {
      when(
        () => tournamentRepository.watchTournaments(
          sportId: any(named: 'sportId'),
          statuses: any(named: 'statuses'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) => Stream.value([
          _t(id: 'ongoing', status: TournamentStatus.active, count: 8),
        ]),
      );

      final c = cubit();
      addTearDown(c.close);
      await tester.pumpWidget(wrap(c));
      await tester.pumpAndSettle();

      expect(find.byType(OngoingTournamentCard), findsOneWidget);
    });

    testWidgets('a stream error surfaces the retry view', (tester) async {
      when(
        () => tournamentRepository.watchTournaments(
          sportId: any(named: 'sportId'),
          statuses: any(named: 'statuses'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => Stream.error(Exception('boom')));

      final c = cubit();
      addTearDown(c.close);
      await tester.pumpWidget(wrap(c));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
      // Tapping retry re-subscribes without throwing.
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      verify(
        () => tournamentRepository.watchTournaments(
          sportId: any(named: 'sportId'),
          statuses: any(named: 'statuses'),
          limit: any(named: 'limit'),
        ),
      ).called(greaterThanOrEqualTo(2));
    });
  });
}
