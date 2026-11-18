import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/core/constants.dart' as fs;
import 'package:campus_arena/features/match/active_match_screen.dart';
import 'package:campus_arena/features/match/cubit/match_cubit.dart';
import 'package:campus_arena/features/match/cubit/match_state.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/routing/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

MatchModel _match(
  List<String> players, {
  String state = fs.MatchStates.occupied,
  String? submittedByUid,
}) => MatchModel(
  matchId: 'm1',
  facilityId: 'f1',
  sportId: fs.SportIds.pingPong,
  mode: 'singles',
  playerUids: players,
  state: state,
  submittedByUid: submittedByUid,
  startedAt: DateTime(2026, 7, 5, 10),
);

MatchModel _doubles({
  required List<String> players,
  String? team1PairId,
  String? team2PairId,
  String state = fs.MatchStates.occupied,
}) => MatchModel(
  matchId: 'm1',
  facilityId: 'f1',
  sportId: fs.SportIds.pingPong,
  mode: fs.MatchModes.doubles,
  playerUids: players,
  team1PairId: team1PairId,
  team2PairId: team2PairId,
  state: state,
  startedAt: DateTime(2026, 7, 5, 10),
);

void main() {
  late MockMatchCubit cubit;

  setUp(() {
    cubit = MockMatchCubit();
    when(() => cubit.uid).thenReturn(_uid);
  });

  Widget wrap({Locale locale = const Locale('en')}) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<MatchCubit>.value(
      value: cubit,
      child: const ActiveMatchView(),
    ),
  );

  testWidgets('renders both players, ELOs and the Record result CTA when '
      'active', (tester) async {
    when(() => cubit.state).thenReturn(
      MatchState(
        status: MatchStatus.active,
        facility: _facility(),
        match: _match(const [_uid, 'opp']),
        players: const {
          _uid: PlayerDisplay(uid: _uid, name: 'Mario Rossi', elo: 1482),
          'opp': PlayerDisplay(uid: 'opp', name: 'L. Bianchi', elo: 1468),
        },
      ),
    );

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.text('Table 3 — BL27'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Mario Rossi'), findsOneWidget);
    expect(find.text('L. Bianchi'), findsOneWidget);
    expect(find.text('1482 ELO'), findsOneWidget);
    expect(find.text('1468 ELO'), findsOneWidget);
    expect(find.text('Record result'), findsOneWidget);
  });

  testWidgets('shows the waiting-for-opponent placeholder before a second '
      'player checks in', (tester) async {
    when(() => cubit.state).thenReturn(
      MatchState(
        status: MatchStatus.waitingOpponent,
        facility: _facility(),
        match: _match(const [_uid]),
        players: const {
          _uid: PlayerDisplay(uid: _uid, name: 'Mario Rossi', elo: 1482),
        },
      ),
    );

    await tester.pumpWidget(wrap());
    // Pump a couple of seconds: a running clock would repaint, but in
    // waitingOpponent there is no ticker — the guidance caption shows instead.
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Waiting for opponent'), findsOneWidget);
    expect(
      find.text("Ask your opponent to scan this table's QR to join."),
      findsOneWidget,
    );
    // Record result is present but disabled until the roster is full.
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('renders the confirmed state with a View summary action', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      MatchState(
        status: MatchStatus.confirmed,
        facility: _facility(),
        match: _match(const [_uid, 'opp']),
        players: const {
          _uid: PlayerDisplay(uid: _uid, name: 'Mario Rossi', elo: 1482),
        },
      ),
    );

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.text('Result confirmed'), findsOneWidget);
    // Confirmed now offers the summary CTA (opens the result-flow route).
    expect(find.text('View summary'), findsOneWidget);
    expect(find.text('Record result'), findsNothing);
  });

  testWidgets('renders the active state in Italian', (tester) async {
    when(() => cubit.state).thenReturn(
      MatchState(
        status: MatchStatus.active,
        facility: _facility(),
        match: _match(const [_uid, 'opp']),
        players: const {
          _uid: PlayerDisplay(uid: _uid, name: 'Mario Rossi', elo: 1482),
          'opp': PlayerDisplay(uid: 'opp', name: 'L. Bianchi', elo: 1468),
        },
      ),
    );

    await tester.pumpWidget(wrap(locale: const Locale('it')));
    await tester.pump();

    expect(find.text('Registra risultato'), findsOneWidget);
    expect(find.text('VS'), findsOneWidget);
  });

  testWidgets('Close asks the cubit to leave (free the table) before popping', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      MatchState(
        status: MatchStatus.ended,
        facility: _facility(),
        // A terminal (ended) match: Close just detaches, no abandon-confirm.
        match: _match(const [_uid, 'opp'], state: fs.MatchStates.abandoned),
      ),
    );
    when(() => cubit.leave()).thenAnswer((_) async {});

    final router = GoRouter(
      initialLocation: '/match',
      routes: [
        GoRoute(
          path: '/match',
          builder: (_, _) => BlocProvider<MatchCubit>.value(
            value: cubit,
            child: const ActiveMatchView(),
          ),
        ),
        GoRoute(
          path: RouteConstants.home,
          builder: (_, _) => const Scaffold(body: Text('HOME')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    verify(() => cubit.leave()).called(1);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets(
    'leaving a solo check-in (no opponent yet) skips the abandon-for-both '
    'dialog and leaves immediately',
    (tester) async {
      when(() => cubit.state).thenReturn(
        MatchState(
          status: MatchStatus.waitingOpponent,
          facility: _facility(),
          // Roster of one: leave() silently cancels, so there is no
          // abandon-for-both prompt to show.
          match: _match(const [_uid]),
        ),
      );
      when(() => cubit.leave()).thenAnswer((_) async {});

      final router = GoRouter(
        initialLocation: '/match',
        routes: [
          GoRoute(
            path: '/match',
            builder: (_, _) => BlocProvider<MatchCubit>.value(
              value: cubit,
              child: const ActiveMatchView(),
            ),
          ),
          GoRoute(
            path: RouteConstants.home,
            builder: (_, _) => const Scaffold(body: Text('HOME')),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      // The waiting badge pulses forever, so pump explicitly instead of
      // pumpAndSettle.
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Leave match?'), findsNothing);
      verify(() => cubit.leave()).called(1);
      expect(find.text('HOME'), findsOneWidget);
    },
  );

  testWidgets('backing out of a live match confirms before abandoning', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      MatchState(
        status: MatchStatus.active,
        facility: _facility(),
        match: _match(const [_uid, 'opp']),
      ),
    );
    when(() => cubit.leave()).thenAnswer((_) async {});

    final router = GoRouter(
      initialLocation: '/match',
      routes: [
        GoRoute(
          path: '/match',
          builder: (_, _) => BlocProvider<MatchCubit>.value(
            value: cubit,
            child: const ActiveMatchView(),
          ),
        ),
        GoRoute(
          path: RouteConstants.home,
          builder: (_, _) => const Scaffold(body: Text('HOME')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    // The live match runs a periodic timer, so pump explicitly rather than
    // pumpAndSettle (which would never settle).
    await tester.pump();

    // Tapping the AppBar close on a live match surfaces the confirm dialog and
    // does NOT abandon until confirmed.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Leave match?'), findsOneWidget);
    verifyNever(() => cubit.leave());

    // "Stay" dismisses without leaving.
    await tester.tap(find.text('Stay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    verifyNever(() => cubit.leave());

    // "Leave" confirms and frees the table.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Leave'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    verify(() => cubit.leave()).called(1);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('a doubles roster offers Join slots when I am not yet on a team', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      MatchState(
        status: MatchStatus.waitingOpponent,
        facility: _facility(),
        // I ('me') am not in the roster; team1 is empty, team2 has one player.
        match: _doubles(
          players: const ['o1'],
          team1PairId: null,
          team2PairId: 'o1',
        ),
      ),
    );
    when(() => cubit.joinSide(any())).thenAnswer((_) async {});

    await tester.pumpWidget(wrap());
    await tester.pump();

    // Empty, joinable slots render as Join buttons (the add-icon affordance).
    expect(find.byIcon(Icons.add), findsWidgets);
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    verify(() => cubit.joinSide(any())).called(1);
  });

  testWidgets(
    'a doubles roster highlights my tile and shows waiting slots for the '
    'empty opposing team',
    (tester) async {
      when(() => cubit.state).thenReturn(
        MatchState(
          status: MatchStatus.active,
          facility: _facility(),
          match: _doubles(
            players: const [_uid, 'p2'],
            team1PairId: '${_uid}_p2',
            team2PairId: null,
          ),
          players: const {
            _uid: PlayerDisplay(uid: _uid, name: 'Mario Rossi', elo: 1400),
            'p2': PlayerDisplay(uid: 'p2', name: 'Gino Verdi', elo: 1300),
          },
        ),
      );

      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.text('Mario Rossi'), findsOneWidget);
      expect(find.text('Gino Verdi'), findsOneWidget);
      // The empty opposing team, which I cannot join (already rostered), shows
      // waiting placeholders rather than Join buttons.
      expect(find.byIcon(Icons.hourglass_empty), findsWidgets);
      expect(find.byIcon(Icons.add), findsNothing);
    },
  );

  testWidgets(
    'resultSubmitted by me shows the submitted badge and status CTA',
    (tester) async {
      when(() => cubit.state).thenReturn(
        MatchState(
          status: MatchStatus.resultSubmitted,
          facility: _facility(),
          match: _match(const [_uid, 'opp'], submittedByUid: _uid),
        ),
      );

      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(
        find.text('Result submitted — waiting for confirmation'),
        findsOneWidget,
      );
      // The submitter sees a "view status" CTA, not a review one.
      expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
      expect(find.text('View status'), findsOneWidget);
    },
  );

  testWidgets('resultSubmitted by the opponent shows a review CTA', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      MatchState(
        status: MatchStatus.resultSubmitted,
        facility: _facility(),
        match: _match(const [_uid, 'opp'], submittedByUid: 'opp'),
      ),
    );

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
    expect(find.text('Review result'), findsOneWidget);
  });

  testWidgets('a disputed match shows the disputed badge and a Close action', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      MatchState(
        status: MatchStatus.disputed,
        facility: _facility(),
        match: _match(const [_uid, 'opp']),
      ),
    );

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.text('Result disputed'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}
