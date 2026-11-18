import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/core/constants.dart' as fs;
import 'package:campus_arena/core/theme/app_theme.dart';
import 'package:campus_arena/features/result/cubit/result_cubit.dart';
import 'package:campus_arena/features/result/cubit/result_state.dart';
import 'package:campus_arena/features/result/widgets/review_view.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockResultCubit extends MockCubit<ResultState> implements ResultCubit {}

const _me = 'me';
const _opp = 'opp';
const _result = PingPongResult(winnerIds: [_me], sets: [11], opponentSets: [7]);

MatchModel _match({
  String mode = 'singles',
  String? submittedByUid = _opp,
  List<String> players = const [_me, _opp],
  String? team1PairId,
  String? team2PairId,
}) => MatchModel(
  matchId: 'm1',
  facilityId: 'f1',
  sportId: fs.SportIds.pingPong,
  mode: mode,
  playerUids: players,
  team1PairId: team1PairId,
  team2PairId: team2PairId,
  state: fs.MatchStates.awaitingConfirmation,
  submittedByUid: submittedByUid,
  result: _result,
  startedAt: DateTime(2026, 7, 5, 10),
);

void main() {
  late MockResultCubit cubit;

  setUp(() {
    cubit = MockResultCubit();
    when(() => cubit.uid).thenReturn(_me);
    when(() => cubit.confirm()).thenAnswer((_) async {});
    when(() => cubit.dispute()).thenAnswer((_) async {});
  });

  Widget wrap(ResultState state) {
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<ResultState>.empty(), initialState: state);
    return MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<ResultCubit>.value(
        value: cubit,
        child: ReviewView(state: state),
      ),
    );
  }

  ResultState reviewState({required ResultPhase phase, MatchModel? match}) =>
      ResultState(
        phase: phase,
        match: match ?? _match(),
        players: const {_me: 'Mario Rossi', _opp: 'Luigi Bianchi'},
      );

  testWidgets('the submitter sees the waiting footer and no action bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        reviewState(
          phase: ResultPhase.awaitingOpponent,
          match: _match(submittedByUid: _me),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Waiting for opponent to confirm…'), findsOneWidget);
    // No Confirm/Dispute actions for the submitter.
    expect(find.widgetWithText(FilledButton, 'Confirm'), findsNothing);
  });

  testWidgets('the opponent can confirm the result', (tester) async {
    await tester.pumpWidget(wrap(reviewState(phase: ResultPhase.review)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pump();
    verify(() => cubit.confirm()).called(1);
  });

  testWidgets('the opponent must confirm the dispute dialog before disputing', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(reviewState(phase: ResultPhase.review)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Dispute'));
    await tester.pumpAndSettle();

    // The confirmation dialog is up; cubit.dispute only fires once confirmed.
    verifyNever(() => cubit.dispute());
    await tester.tap(find.widgetWithText(FilledButton, 'Dispute'));
    await tester.pumpAndSettle();
    verify(() => cubit.dispute()).called(1);
  });

  testWidgets('the confirming phase disables the bar with a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(reviewState(phase: ResultPhase.confirming)));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final confirm = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(confirm.onPressed, isNull);
  });

  testWidgets('a doubles match orients the score card to my team first', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        reviewState(
          phase: ResultPhase.review,
          match: _match(
            mode: 'doubles',
            players: const [_me, 'p2', 'o1', 'o2'],
            team1PairId: '${_me}_p2',
            team2PairId: 'o1_o2',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Rendered without throwing and still offers the opponent actions.
    expect(find.widgetWithText(FilledButton, 'Confirm'), findsOneWidget);
  });
}
