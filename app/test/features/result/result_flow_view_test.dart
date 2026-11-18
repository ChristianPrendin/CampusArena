import 'dart:async';

import 'package:campus_arena/core/constants.dart' as fs;
import 'package:campus_arena/core/theme/app_theme.dart';
import 'package:campus_arena/features/result/cubit/result_cubit.dart';
import 'package:campus_arena/features/result/result_flow_page.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/repositories/achievement_repository.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAchievementRepository extends Mock implements AchievementRepository {}

class MockMatchRepository extends Mock implements MatchRepository {}

class MockRatingRepository extends Mock implements RatingRepository {}

class MockUserRepository extends Mock implements UserRepository {}

const _me = 'me';
const _opp = 'opp';

MatchModel _match({
  required String state,
  String? submittedByUid,
  MatchResult? result,
  Map<String, int>? eloBefore,
  Map<String, int>? eloDeltas,
}) => MatchModel(
  matchId: 'm1',
  facilityId: 'f1',
  sportId: fs.SportIds.pingPong,
  mode: 'singles',
  playerUids: const [_me, _opp],
  state: state,
  submittedByUid: submittedByUid,
  result: result,
  eloBefore: eloBefore,
  eloDeltas: eloDeltas,
  startedAt: DateTime(2026, 7, 5, 10),
);

const _result = PingPongResult(winnerIds: [_me], sets: [11], opponentSets: [5]);

void main() {
  late MockMatchRepository matchRepo;
  late MockRatingRepository ratingRepo;
  late MockUserRepository userRepo;
  late MockAchievementRepository achievementRepo;
  late StreamController<MatchModel?> matchStream;

  setUpAll(() {
    registerFallbackValue(_match(state: fs.MatchStates.occupied));
    registerFallbackValue(_result);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    matchRepo = MockMatchRepository();
    ratingRepo = MockRatingRepository();
    userRepo = MockUserRepository();
    achievementRepo = MockAchievementRepository();
    matchStream = StreamController<MatchModel?>.broadcast();
    when(
      () => achievementRepo.getDefinitions(),
    ).thenAnswer((_) async => const []);

    when(
      () => matchRepo.watchMatch(any()),
    ).thenAnswer((_) => matchStream.stream);
    when(
      () => matchRepo.submitResult(
        matchId: any(named: 'matchId'),
        result: any(named: 'result'),
        submittedByUid: any(named: 'submittedByUid'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => matchRepo.resolveTimeout(any(), now: any(named: 'now')),
    ).thenAnswer((_) async {});
    when(() => userRepo.getUser(any())).thenAnswer((_) async => null);
    when(
      () => ratingRepo.getUserRank(
        sportId: any(named: 'sportId'),
        elo: any(named: 'elo'),
      ),
    ).thenAnswer((_) async => 12);
  });

  tearDown(() => matchStream.close());

  Future<ResultCubit> pump(
    WidgetTester tester,
    MatchModel match, {
    Locale locale = const Locale('en'),
  }) async {
    final cubit = ResultCubit(
      uid: _me,
      matchId: 'm1',
      matchRepository: matchRepo,
      ratingRepository: ratingRepo,
      userRepository: userRepo,
      achievementRepository: achievementRepo,
    );
    cubit.load();
    matchStream.add(match);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.lightTheme,
        home: BlocProvider.value(value: cubit, child: const ResultFlowView()),
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('score entry: a completed score enables + submits', (
    tester,
  ) async {
    final cubit = await pump(tester, _match(state: fs.MatchStates.occupied));
    addTearDown(cubit.close);

    final submit = find.widgetWithText(FilledButton, 'Submit result');
    // Disabled until a valid score is entered.
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    // Drive the current user's stepper to 11 (11-0 is a decisive set).
    for (var i = 0; i < 11; i++) {
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump();
    }
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await tester.tap(submit);
    await tester.pump();
    verify(
      () => matchRepo.submitResult(
        matchId: 'm1',
        result: any(named: 'result'),
        submittedByUid: _me,
      ),
    ).called(1);
  });

  testWidgets('review shows Confirm/Dispute only to the non-submitter', (
    tester,
  ) async {
    final cubit = await pump(
      tester,
      _match(
        state: fs.MatchStates.awaitingConfirmation,
        submittedByUid: _opp,
        result: _result,
      ),
    );
    addTearDown(cubit.close);

    expect(find.widgetWithText(FilledButton, 'Confirm'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Dispute'), findsOneWidget);
  });

  testWidgets('the submitter sees a waiting footer and no actions', (
    tester,
  ) async {
    final cubit = await pump(
      tester,
      _match(
        state: fs.MatchStates.awaitingConfirmation,
        submittedByUid: _me,
        result: _result,
      ),
    );
    addTearDown(cubit.close);

    expect(find.text('Waiting for opponent to confirm…'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Confirm'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Dispute'), findsNothing);
  });

  testWidgets('summary renders the victory header, delta and rank', (
    tester,
  ) async {
    final cubit = await pump(
      tester,
      _match(
        state: fs.MatchStates.confirmed,
        submittedByUid: _opp,
        result: _result,
        eloBefore: const {_me: 1200, _opp: 1200},
        eloDeltas: const {_me: 16, _opp: -16},
      ),
    );
    addTearDown(cubit.close);

    expect(find.text('Victory!'), findsOneWidget);
    expect(find.text('+16'), findsOneWidget);
    expect(find.text('1216'), findsOneWidget);
    expect(find.text('#12'), findsOneWidget);
  });

  testWidgets('review renders in Italian', (tester) async {
    final cubit = await pump(
      tester,
      _match(
        state: fs.MatchStates.awaitingConfirmation,
        submittedByUid: _opp,
        result: _result,
      ),
      locale: const Locale('it'),
    );
    addTearDown(cubit.close);

    expect(find.text('Conferma risultato'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Conferma'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Contesta'), findsOneWidget);
  });

  testWidgets('summary renders in Italian', (tester) async {
    final cubit = await pump(
      tester,
      _match(
        state: fs.MatchStates.confirmed,
        submittedByUid: _opp,
        result: _result,
        eloBefore: const {_me: 1200, _opp: 1200},
        eloDeltas: const {_me: 16, _opp: -16},
      ),
      locale: const Locale('it'),
    );
    addTearDown(cubit.close);

    expect(find.text('Vittoria!'), findsOneWidget);
    expect(find.text('Nuova posizione nel campus'), findsOneWidget);
  });
}
