import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/core/constants.dart' as fs;
import 'package:campus_arena/features/match/cubit/match_cubit.dart';
import 'package:campus_arena/features/match/cubit/match_state.dart';
import 'package:campus_arena/features/match/match_setup_screen.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMatchCubit extends MockCubit<MatchState> implements MatchCubit {}

FacilityModel _facility() => const FacilityModel(
  facilityId: 'f1',
  name: 'Table 3 — BL27',
  sportId: fs.SportIds.pingPong,
  coordinates: Coordinates(latitude: 45.4784, longitude: 9.2272),
  qrCode: 'QR-F1',
  fallbackCode: 'BL27A',
  isOutdoor: false,
  status: fs.FacilityStatus.free,
  kingOfTableWins: 0,
  queueTailPosition: 0,
);

void main() {
  late MockMatchCubit cubit;

  setUp(() {
    cubit = MockMatchCubit();
    when(() => cubit.uid).thenReturn('me');
  });

  Widget wrap({bool isDeepLink = true, Locale locale = const Locale('en')}) =>
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<MatchCubit>.value(
          value: cubit,
          child: MatchSetupView(isDeepLink: isDeepLink),
        ),
      );

  testWidgets(
    'offers an explicit check-in button once a facility is resolved',
    (tester) async {
      when(() => cubit.state).thenReturn(
        MatchState(status: MatchStatus.readyToConfirm, facility: _facility()),
      );

      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.text('Check in to Table 3 — BL27'), findsOneWidget);
      // Singles is the default; no team picker until doubles is chosen.
      expect(find.text('Team 1'), findsNothing);
    },
  );

  testWidgets('shows the soft GPS warning banner when the fix is far', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      MatchState(
        status: MatchStatus.readyToConfirm,
        facility: _facility(),
        gpsDistanceMeters: 1500,
        gpsFar: true,
      ),
    );

    await tester.pumpWidget(wrap(isDeepLink: false));
    await tester.pump();

    expect(
      find.text('You seem far from this table — check-in still allowed'),
      findsOneWidget,
    );
  });

  testWidgets('picking Doubles reveals the team selector', (tester) async {
    when(() => cubit.state).thenReturn(
      MatchState(status: MatchStatus.readyToConfirm, facility: _facility()),
    );

    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(find.text('Doubles'));
    await tester.pumpAndSettle();

    expect(find.text('Team 1'), findsOneWidget);
    expect(find.text('Team 2'), findsOneWidget);
  });

  testWidgets('confirm forwards the chosen mode and side to the cubit', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      MatchState(status: MatchStatus.readyToConfirm, facility: _facility()),
    );
    when(
      () => cubit.confirmCheckIn(
        mode: any(named: 'mode'),
        creatorTeam: any(named: 'creatorTeam'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(find.text('Doubles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Team 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check in to Table 3 — BL27'));
    await tester.pump();

    verify(
      () => cubit.confirmCheckIn(mode: fs.MatchModes.doubles, creatorTeam: 2),
    ).called(1);
  });

  testWidgets('renders in Italian', (tester) async {
    when(() => cubit.state).thenReturn(
      MatchState(status: MatchStatus.readyToConfirm, facility: _facility()),
    );

    await tester.pumpWidget(wrap(locale: const Locale('it')));
    await tester.pump();

    expect(find.text('Imposta partita'), findsWidgets);
  });
}
