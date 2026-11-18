import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/core/constants.dart' as fs;
import 'package:campus_arena/features/match/active_match_screen.dart';
import 'package:campus_arena/features/match/cubit/match_cubit.dart';
import 'package:campus_arena/features/match/cubit/match_state.dart';
import 'package:campus_arena/features/match/match_flow_page.dart';
import 'package:campus_arena/features/match/match_setup_screen.dart';
import 'package:campus_arena/features/match/qr_scan_screen.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMatchCubit extends MockCubit<MatchState> implements MatchCubit {}

const _uid = 'me';

FacilityModel _facility() => const FacilityModel(
  facilityId: 'f1',
  name: 'Table 3 — BL27',
  sportId: fs.SportIds.pingPong,
  coordinates: Coordinates(latitude: 45.4784, longitude: 9.2272),
  qrCode: 'QR-F1',
  fallbackCode: 'BL27A',
  isOutdoor: false,
  status: fs.FacilityStatus.occupied,
  kingOfTableWins: 0,
  queueTailPosition: 0,
);

MatchModel _match(List<String> players) => MatchModel(
  matchId: 'm1',
  facilityId: 'f1',
  sportId: fs.SportIds.pingPong,
  mode: 'singles',
  playerUids: players,
  state: fs.MatchStates.occupied,
  startedAt: DateTime(2026, 7, 5, 10),
);

void main() {
  late MockMatchCubit cubit;

  setUp(() {
    cubit = MockMatchCubit();
    when(() => cubit.uid).thenReturn(_uid);
    when(() => cubit.expectedSportId).thenReturn(null);
    when(() => cubit.reset()).thenReturn(null);
    when(() => cubit.confirmCheckIn()).thenAnswer((_) async {});
  });

  Widget wrap({required bool isDeepLink}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<MatchCubit>.value(
      value: cubit,
      child: MatchFlowView(isDeepLink: isDeepLink, enableCamera: false),
    ),
  );

  /// Seeds a single state with no transition (isolates the builder).
  void seedStatic(MatchState state) {
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<MatchState>.empty(), initialState: state);
  }

  /// Seeds an idle -> [next] transition so the BlocConsumer listener fires.
  void seedTransition(MatchState next) {
    whenListen(
      cubit,
      Stream<MatchState>.value(next),
      initialState: const MatchState(),
    );
  }

  testWidgets('idle blind scan shows the QR viewfinder', (tester) async {
    seedStatic(const MatchState());
    await tester.pumpWidget(wrap(isDeepLink: false));
    await tester.pump();
    expect(find.byType(QrScanView), findsOneWidget);
  });

  testWidgets('an active match shows the active-match surface', (tester) async {
    seedStatic(
      MatchState(
        status: MatchStatus.active,
        facility: _facility(),
        match: _match(const [_uid, 'opp']),
      ),
    );
    await tester.pumpWidget(wrap(isDeepLink: false));
    await tester.pump();
    expect(find.byType(ActiveMatchView), findsOneWidget);
  });

  testWidgets('a deep-link readyToConfirm shows the setup screen', (
    tester,
  ) async {
    seedStatic(
      MatchState(status: MatchStatus.readyToConfirm, facility: _facility()),
    );
    await tester.pumpWidget(wrap(isDeepLink: true));
    await tester.pump();
    expect(find.byType(MatchSetupView), findsOneWidget);
  });

  testWidgets('a far blind readyToConfirm also routes to setup', (
    tester,
  ) async {
    seedStatic(
      MatchState(
        status: MatchStatus.readyToConfirm,
        facility: _facility(),
        gpsFar: true,
      ),
    );
    await tester.pumpWidget(wrap(isDeepLink: false));
    await tester.pump();
    expect(find.byType(MatchSetupView), findsOneWidget);
  });

  testWidgets('an error state shows a snackbar and re-arms the scanner', (
    tester,
  ) async {
    seedTransition(
      const MatchState(
        status: MatchStatus.error,
        errorKind: MatchErrorKind.tableBusy,
      ),
    );
    await tester.pumpWidget(wrap(isDeepLink: false));
    await tester.pump(); // process the stream emission + listener
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    verify(() => cubit.reset()).called(1);
  });

  testWidgets('a nearby blind readyToConfirm auto-confirms check-in', (
    tester,
  ) async {
    seedTransition(
      MatchState(status: MatchStatus.readyToConfirm, facility: _facility()),
    );
    await tester.pumpWidget(wrap(isDeepLink: false));
    await tester.pump();
    await tester.pump();

    verify(() => cubit.confirmCheckIn()).called(1);
  });
}
