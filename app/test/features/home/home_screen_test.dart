import 'dart:async';

import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/home/cubit/dashboard_cubit.dart';
import 'package:campus_arena/features/home/home_screen.dart';
import 'package:campus_arena/features/home/widgets/assistant_entry_card.dart';
import 'package:campus_arena/features/home/widgets/sport_selector.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/features/challenges/cubit/challenge_cubit.dart';
import 'package:campus_arena/models/challenge_model.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/models/rating_model.dart';
import 'package:campus_arena/repositories/challenge_repository.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:campus_arena/routing/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockRatingRepository extends Mock implements RatingRepository {}

class MockMatchRepository extends Mock implements MatchRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockChallengeRepository extends Mock implements ChallengeRepository {}

const _uid = 'me';

RatingModel _rating(String sportId, {int elo = kInitialElo}) => RatingModel(
  ratingId: RatingRepository.ratingId(sportId, _uid),
  ownerType: OwnerType.user,
  ownerId: _uid,
  sportId: sportId,
  elo: elo,
  matchesPlayed: 3,
  lastMatchAt: DateTime(2026, 6, 30),
);

MatchModel _match({
  required String id,
  String sportId = SportIds.pingPong,
  String state = MatchStates.confirmed,
  Map<String, int>? eloDeltas,
  List<String> winnerIds = const [_uid],
}) => MatchModel(
  matchId: id,
  facilityId: 'f1',
  sportId: sportId,
  mode: 'singles',
  playerUids: const [_uid, 'opp'],
  state: state,
  result: state == MatchStates.confirmed
      ? PingPongResult(
          winnerIds: winnerIds,
          sets: const [11],
          opponentSets: const [5],
        )
      : null,
  eloDeltas: eloDeltas,
  startedAt: DateTime(2026, 6, 30, 10),
);

void main() {
  late MockRatingRepository ratingRepository;
  late MockMatchRepository matchRepository;
  late MockUserRepository userRepository;
  late MockChallengeRepository challengeRepository;

  // Stubs watchUserMatches with a single broadcast view of [source], so both the
  // dashboard and challenge cubits (which each open the same query) can listen —
  // production returns an independently-listenable Firestore stream per call.
  void stubMatches(Stream<List<MatchModel>> source) {
    final broadcast = source.asBroadcastStream();
    when(
      () => matchRepository.watchUserMatches(_uid, limit: any(named: 'limit')),
    ).thenAnswer((_) => broadcast);
  }

  setUp(() {
    ratingRepository = MockRatingRepository();
    matchRepository = MockMatchRepository();
    userRepository = MockUserRepository();
    challengeRepository = MockChallengeRepository();
    when(() => userRepository.getUser(any())).thenAnswer((_) async => null);
    // No challenges: the section collapses and doesn't affect these assertions.
    when(
      () => challengeRepository.watchIncomingPending(_uid),
    ).thenAnswer((_) => Stream.value(const <ChallengeModel>[]));
    when(
      () => challengeRepository.watchOutgoingRecent(_uid),
    ).thenAnswer((_) => Stream.value(const <ChallengeModel>[]));
    // Default: no recent matches. Individual tests override via stubStreams.
    stubMatches(const Stream<List<MatchModel>>.empty());
  });

  ChallengeCubit challengeCubit() => ChallengeCubit(
    uid: _uid,
    challengeRepository: challengeRepository,
    userRepository: userRepository,
    matchRepository: matchRepository,
  );

  void stubStreams({
    Stream<List<RatingModel>>? ratings,
    Stream<List<MatchModel>>? matches,
  }) {
    when(
      () => ratingRepository.watchUserRatings(_uid),
    ).thenAnswer((_) => ratings ?? const Stream.empty());
    stubMatches(matches ?? const Stream<List<MatchModel>>.empty());
  }

  Widget wrap() {
    final cubit = DashboardCubit(
      uid: _uid,
      ratingRepository: ratingRepository,
      matchRepository: matchRepository,
      userRepository: userRepository,
    );
    addTearDown(cubit.close);
    final challenges = challengeCubit();
    addTearDown(challenges.close);
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          BlocProvider.value(value: challenges),
        ],
        child: const HomeView(),
      ),
    );
  }

  /// Pumps [wrap] at a fixed viewport width so the phone/tablet branch is
  /// deterministic (default test surface is 800px, i.e. the tablet split).
  Future<void> pumpAt(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
  }

  Future<AppLocalizations> en() =>
      AppLocalizations.delegate.load(const Locale('en'));

  testWidgets('shows a spinner while streams have not emitted', (tester) async {
    when(
      () => ratingRepository.watchUserRatings(_uid),
    ).thenAnswer((_) => StreamController<List<RatingModel>>().stream);
    when(
      () => matchRepository.watchUserMatches(_uid, limit: any(named: 'limit')),
    ).thenAnswer((_) => Stream.value(const <MatchModel>[]));

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the selected sport hero, selector, play and assistant', (
    tester,
  ) async {
    stubStreams(
      ratings: Stream.value([
        _rating(SportIds.pingPong, elo: 1482),
        _rating(SportIds.foosball, elo: 1300),
      ]),
      matches: Stream.value(const <MatchModel>[]),
    );

    await pumpAt(tester, 400);
    final l10n = await en();

    // Both selector chips render; only the selected sport's ELO shows.
    expect(find.byType(SportSelector), findsOneWidget);
    expect(find.text(l10n.sportPingPong), findsOneWidget);
    expect(find.text(l10n.sportFoosball), findsOneWidget);
    expect(find.text('1482'), findsOneWidget);
    expect(find.text('1300'), findsNothing);
    expect(find.text(l10n.playButtonLabel), findsOneWidget);
    expect(find.byType(AssistantEntryCard), findsOneWidget);
  });

  testWidgets('tapping a sport chip switches the hero ELO', (tester) async {
    stubStreams(
      ratings: Stream.value([
        _rating(SportIds.pingPong, elo: 1482),
        _rating(SportIds.foosball, elo: 1300),
      ]),
      matches: Stream.value(const <MatchModel>[]),
    );

    await pumpAt(tester, 400);
    final l10n = await en();

    expect(find.text('1482'), findsOneWidget);
    await tester.tap(find.text(l10n.sportFoosball));
    await tester.pumpAndSettle();

    expect(find.text('1300'), findsOneWidget);
    expect(find.text('1482'), findsNothing);
  });

  testWidgets('tapping Play navigates to the QR scan route', (tester) async {
    stubStreams(
      ratings: Stream.value([_rating(SportIds.pingPong)]),
      matches: Stream.value(const <MatchModel>[]),
    );
    final cubit = DashboardCubit(
      uid: _uid,
      ratingRepository: ratingRepository,
      matchRepository: matchRepository,
      userRepository: userRepository,
    );
    addTearDown(cubit.close);
    final challenges = challengeCubit();
    addTearDown(challenges.close);
    final router = GoRouter(
      initialLocation: RouteConstants.home,
      routes: [
        GoRoute(
          path: RouteConstants.home,
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider.value(value: challenges),
            ],
            child: const HomeView(),
          ),
        ),
        GoRoute(
          path: RouteConstants.qrScan,
          builder: (context, state) => const Scaffold(body: Text('SCAN ROUTE')),
        ),
      ],
    );

    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await en();

    await tester.tap(find.text(l10n.playButtonLabel));
    await tester.pumpAndSettle();

    expect(find.text('SCAN ROUTE'), findsOneWidget);
  });

  testWidgets('shows the empty state when the sport has no history', (
    tester,
  ) async {
    stubStreams(
      ratings: Stream.value([_rating(SportIds.pingPong)]),
      matches: Stream.value(const <MatchModel>[]),
    );

    await pumpAt(tester, 400);
    final l10n = await en();

    expect(find.text(l10n.noRecentMatches), findsOneWidget);
  });

  testWidgets('recent row shows score and signed delta; other states label', (
    tester,
  ) async {
    stubStreams(
      ratings: Stream.value([_rating(SportIds.pingPong)]),
      matches: Stream.value([
        _match(id: 'm1', eloDeltas: const {_uid: 12}),
        _match(id: 'm2', state: MatchStates.disputed),
      ]),
    );

    await pumpAt(tester, 400);
    final l10n = await en();

    // The delta shows on the row and, being the newest confirmed match, is
    // echoed by the hero card's trend pill — two widgets by design.
    expect(find.text('+12'), findsNWidgets(2));
    expect(find.text('1–0'), findsOneWidget); // won 1 set to 0 (row only)
    expect(find.text(l10n.matchStateDisputed), findsOneWidget);
  });

  testWidgets('recent history is filtered to the selected sport', (
    tester,
  ) async {
    stubStreams(
      ratings: Stream.value([
        _rating(SportIds.pingPong),
        _rating(SportIds.foosball),
      ]),
      matches: Stream.value([
        _match(id: 'pp', eloDeltas: const {_uid: 7}),
        _match(
          id: 'fb',
          sportId: SportIds.foosball,
          eloDeltas: const {_uid: -3},
        ),
      ]),
    );

    await pumpAt(tester, 400);
    final l10n = await en();

    // Ping pong selected by default: only its match delta is visible (row +
    // hero pill = 2); the foosball match is filtered out entirely.
    expect(find.text('+7'), findsNWidgets(2));
    expect(find.text('-3'), findsNothing);

    await tester.tap(find.text(l10n.sportFoosball));
    await tester.pumpAndSettle();

    expect(find.text('-3'), findsNWidgets(2));
    expect(find.text('+7'), findsNothing);
  });

  testWidgets('tablet width lays the dashboard out without overflow', (
    tester,
  ) async {
    stubStreams(
      ratings: Stream.value([
        _rating(SportIds.pingPong, elo: 1482),
        _rating(SportIds.foosball),
      ]),
      matches: Stream.value([
        _match(id: 'm1', eloDeltas: const {_uid: 9}),
      ]),
    );

    await pumpAt(tester, 900);
    final l10n = await en();

    // Both panes render side by side: hero + activity.
    expect(find.text('1482'), findsOneWidget);
    expect(find.byType(AssistantEntryCard), findsOneWidget);
    expect(find.text(l10n.playButtonLabel), findsOneWidget);
    expect(find.text('+9'), findsNWidgets(2)); // hero pill + row
    expect(tester.takeException(), isNull);
  });

  testWidgets('error state shows a retry action', (tester) async {
    when(
      () => ratingRepository.watchUserRatings(_uid),
    ).thenAnswer((_) => Stream.error(Exception('boom')));
    when(
      () => matchRepository.watchUserMatches(_uid, limit: any(named: 'limit')),
    ).thenAnswer((_) => Stream.value(const <MatchModel>[]));

    await pumpAt(tester, 400);
    final l10n = await en();

    expect(find.text(l10n.dashboardLoadError), findsOneWidget);
    expect(find.text(l10n.retryButtonLabel), findsOneWidget);
  });
}
