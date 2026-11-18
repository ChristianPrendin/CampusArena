import 'dart:async';

import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/leaderboards/cubit/leaderboard_cubit.dart';
import 'package:campus_arena/features/leaderboards/cubit/leaderboard_state.dart';
import 'package:campus_arena/features/leaderboards/leaderboards_screen.dart';
import 'package:campus_arena/features/leaderboards/widgets/current_user_rank_bar.dart';
import 'package:campus_arena/features/leaderboards/widgets/leaderboard_podium.dart';
import 'package:campus_arena/features/leaderboards/widgets/leaderboard_row.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/rating_model.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockRatingRepository extends Mock implements RatingRepository {}

class MockUserRepository extends Mock implements UserRepository {}

const _uid = 'me';

RatingModel _rating(String ownerId, int elo) => RatingModel(
  ratingId: RatingRepository.ratingId(SportIds.pingPong, ownerId),
  ownerType: OwnerType.user,
  ownerId: ownerId,
  sportId: SportIds.pingPong,
  elo: elo,
  matchesPlayed: 5,
  lastMatchAt: DateTime(2026, 6, 30),
);

void main() {
  late MockRatingRepository ratingRepository;
  late MockUserRepository userRepository;

  setUp(() {
    ratingRepository = MockRatingRepository();
    userRepository = MockUserRepository();

    when(
      () => ratingRepository.watchLeaderboard(
        sportId: any(named: 'sportId'),
        ownerType: any(named: 'ownerType'),
        degreeProgram: any(named: 'degreeProgram'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => ratingRepository.getFriendsLeaderboard(
        sportId: any(named: 'sportId'),
        userAndFriendUids: any(named: 'userAndFriendUids'),
      ),
    ).thenAnswer((_) async => const <RatingModel>[]);
    when(
      () => ratingRepository.getUserRating(any(), any()),
    ).thenAnswer((_) async => null);
    when(
      () => ratingRepository.getUserRank(
        sportId: any(named: 'sportId'),
        elo: any(named: 'elo'),
      ),
    ).thenAnswer((_) async => 1);
    when(() => userRepository.getUser(any())).thenAnswer((_) async => null);
    when(
      () => userRepository.getUsersByIds(any()),
    ).thenAnswer((_) async => const <UserModel>[]);
  });

  void stubBoard(List<RatingModel> entries) {
    when(
      () => ratingRepository.watchLeaderboard(
        sportId: any(named: 'sportId'),
        ownerType: any(named: 'ownerType'),
        degreeProgram: any(named: 'degreeProgram'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => Stream.value(entries));
  }

  LeaderboardCubit buildCubit() {
    final cubit = LeaderboardCubit(
      uid: _uid,
      ratingRepository: ratingRepository,
      userRepository: userRepository,
    )..init();
    addTearDown(cubit.close);
    return cubit;
  }

  Widget wrap(LeaderboardCubit cubit, {Locale locale = const Locale('en')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(value: cubit, child: const LeaderboardView()),
    );
  }

  Future<void> pumpAt(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  Future<AppLocalizations> l10nFor(Locale locale) =>
      AppLocalizations.delegate.load(locale);

  testWidgets('spinner while the board has not emitted', (tester) async {
    when(
      () => ratingRepository.watchLeaderboard(
        sportId: any(named: 'sportId'),
        ownerType: any(named: 'ownerType'),
        degreeProgram: any(named: 'degreeProgram'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => StreamController<List<RatingModel>>().stream);

    await tester.pumpWidget(wrap(buildCubit()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders podium, list rows and the your-rank bar', (
    tester,
  ) async {
    stubBoard([
      _rating('p1', 1600),
      _rating('p2', 1550),
      _rating('p3', 1500),
      _rating('p4', 1450),
      _rating('p5', 1400),
    ]);
    when(
      () => ratingRepository.getUserRating(_uid, SportIds.pingPong),
    ).thenAnswer((_) async => _rating(_uid, 1350));
    when(
      () => ratingRepository.getUserRank(sportId: SportIds.pingPong, elo: 1350),
    ).thenAnswer((_) async => 12);

    await pumpAt(tester, wrap(buildCubit()));
    final l10n = await l10nFor(const Locale('en'));

    expect(find.byType(LeaderboardPodium), findsOneWidget);
    expect(find.byType(LeaderboardRow), findsNWidgets(2)); // ranks 4 & 5
    expect(find.text('1600'), findsOneWidget); // podium leader
    expect(find.text(l10n.leaderboardYourRank), findsOneWidget);
    expect(find.byType(CurrentUserRankBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty board shows the empty state', (tester) async {
    stubBoard(const []);

    await pumpAt(tester, wrap(buildCubit()));
    final l10n = await l10nFor(const Locale('en'));

    expect(find.text(l10n.leaderboardEmpty), findsOneWidget);
  });

  testWidgets('error state offers retry', (tester) async {
    when(
      () => ratingRepository.watchLeaderboard(
        sportId: any(named: 'sportId'),
        ownerType: any(named: 'ownerType'),
        degreeProgram: any(named: 'degreeProgram'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => Stream.error(Exception('boom')));

    await pumpAt(tester, wrap(buildCubit()));
    final l10n = await l10nFor(const Locale('en'));

    expect(find.text(l10n.leaderboardLoadError), findsOneWidget);
    expect(find.text(l10n.retryButtonLabel), findsOneWidget);
  });

  testWidgets('the scope selector defaults to Global and the Friends segment '
      'switches scope', (tester) async {
    stubBoard([_rating('p1', 1600)]);
    when(
      () => ratingRepository.getFriendsLeaderboard(
        sportId: SportIds.pingPong,
        userAndFriendUids: any(named: 'userAndFriendUids'),
      ),
    ).thenAnswer((_) async => [_rating('f1', 1700)]);

    final cubit = buildCubit();
    await pumpAt(tester, wrap(cubit));
    final l10n = await l10nFor(const Locale('en'));

    // Global is an explicit, visibly selected segment — never an implied state.
    final segmented = tester.widget<SegmentedButton<LeaderboardScope>>(
      find.byType(SegmentedButton<LeaderboardScope>),
    );
    expect(segmented.selected, {LeaderboardScope.global});

    await tester.tap(find.text(l10n.leaderboardScopeFriends));
    await tester.pumpAndSettle();

    expect(cubit.state.scope, LeaderboardScope.friends);
    verify(
      () => ratingRepository.getFriendsLeaderboard(
        sportId: SportIds.pingPong,
        userAndFriendUids: any(named: 'userAndFriendUids'),
      ),
    ).called(1);
  });

  testWidgets('renders in Italian', (tester) async {
    stubBoard(const []);

    await pumpAt(tester, wrap(buildCubit(), locale: const Locale('it')));
    final it = await l10nFor(const Locale('it'));

    expect(find.text(it.leaderboardScopeGlobal), findsOneWidget);
    expect(find.text(it.leaderboardScopeFriends), findsOneWidget);
    expect(find.text(it.leaderboardScopeMyCourse), findsOneWidget);
  });

  testWidgets('tapping a row pushes the public profile route', (tester) async {
    stubBoard([
      _rating('p1', 1600),
      _rating('p2', 1550),
      _rating('p3', 1500),
      _rating('p4', 1450),
    ]);
    final cubit = buildCubit();

    final router = GoRouter(
      initialLocation: '/leaderboards',
      routes: [
        GoRoute(
          path: '/leaderboards',
          builder: (context, state) =>
              BlocProvider.value(value: cubit, child: const LeaderboardView()),
        ),
        GoRoute(
          path: '/profile/:uid',
          builder: (context, state) =>
              Scaffold(body: Text('profile ${state.pathParameters['uid']}')),
        ),
      ],
    );

    tester.view.physicalSize = const Size(420, 1600);
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

    // 'p4' is the rank-4 row (fallback name = ownerId since getUser → null).
    await tester.tap(find.text('p4'));
    await tester.pumpAndSettle();

    expect(find.text('profile p4'), findsOneWidget);
  });

  testWidgets('tapping your own row does not open a profile drill-in', (
    tester,
  ) async {
    // 'me' sits at rank 4 (a tappable row, not the podium).
    stubBoard([
      _rating('p1', 1600),
      _rating('p2', 1550),
      _rating('p3', 1500),
      _rating(_uid, 1450),
    ]);
    final cubit = buildCubit();

    final router = GoRouter(
      initialLocation: '/leaderboards',
      routes: [
        GoRoute(
          path: '/leaderboards',
          builder: (context, state) =>
              BlocProvider.value(value: cubit, child: const LeaderboardView()),
        ),
        GoRoute(
          path: '/profile/:uid',
          builder: (context, state) =>
              Scaffold(body: Text('profile ${state.pathParameters['uid']}')),
        ),
      ],
    );

    tester.view.physicalSize = const Size(420, 1600);
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

    await tester.tap(find.text(_uid));
    await tester.pump();

    // Stayed on the leaderboard with the "this is you" snackbar; no profile
    // route was pushed.
    final l10n = await l10nFor(const Locale('en'));
    expect(find.byType(LeaderboardView), findsOneWidget);
    expect(find.text(l10n.leaderboardThisIsYou), findsOneWidget);
    expect(find.textContaining('profile'), findsNothing);
  });

  testWidgets('app-bar add-friends action routes to the friends screen', (
    tester,
  ) async {
    stubBoard([_rating('p1', 1600)]);
    final cubit = buildCubit();

    final router = GoRouter(
      initialLocation: '/leaderboards',
      routes: [
        GoRoute(
          path: '/leaderboards',
          builder: (context, state) =>
              BlocProvider.value(value: cubit, child: const LeaderboardView()),
        ),
        GoRoute(
          path: '/friends',
          builder: (context, state) =>
              const Scaffold(body: Text('friends screen')),
        ),
      ],
    );

    tester.view.physicalSize = const Size(420, 1600);
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

    await tester.tap(find.byIcon(Icons.person_add_alt_1_outlined));
    await tester.pumpAndSettle();

    expect(find.text('friends screen'), findsOneWidget);
  });

  testWidgets(
    'toggling Doubles shows pair rows with both names and hides scope',
    (tester) async {
      final l10n = await l10nFor(const Locale('en'));
      // Singles board resolves to an empty ready state (so the initial pump
      // settles); the pair board carries one team.
      stubBoard(const []);
      when(
        () => ratingRepository.watchLeaderboard(
          sportId: any(named: 'sportId'),
          ownerType: OwnerType.pair,
          degreeProgram: any(named: 'degreeProgram'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) => Stream.value([
          RatingModel(
            ratingId: RatingRepository.ratingId(SportIds.pingPong, 'a_b'),
            ownerType: OwnerType.pair,
            ownerId: 'a_b',
            memberUids: const ['a', 'b'],
            sportId: SportIds.pingPong,
            elo: 1500,
            matchesPlayed: 4,
            lastMatchAt: DateTime(2026, 6, 30),
          ),
        ]),
      );
      when(() => userRepository.getUsersByIds(any())).thenAnswer(
        (_) async => [
          UserModel(
            uid: 'a',
            name: 'Anna',
            username: 'anna',
            email: 'a@polimi.it',
            degreeProgram: 'Design',
            language: 'en',
            pushTokens: const [],
            friendUids: const [],
            badges: const {},
            onboardingComplete: true,
            createdAt: DateTime(2026),
          ),
          UserModel(
            uid: 'b',
            name: 'Bruno',
            username: 'bruno',
            email: 'b@polimi.it',
            degreeProgram: 'Design',
            language: 'en',
            pushTokens: const [],
            friendUids: const [],
            badges: const {},
            onboardingComplete: true,
            createdAt: DateTime(2026),
          ),
        ],
      );

      await pumpAt(tester, wrap(buildCubit()));

      // The scope selector is present in singles mode.
      expect(find.text(l10n.leaderboardScopeGlobal), findsOneWidget);

      await tester.tap(find.text(l10n.matchModeDoubles));
      await tester.pumpAndSettle();

      // The pair's joined name shows (here in the sole podium spot); the scope
      // selector is gone.
      expect(find.text('Anna & Bruno'), findsOneWidget);
      expect(find.text(l10n.leaderboardScopeGlobal), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('doubles board shows a podium plus pair rows below the top three', (
    tester,
  ) async {
    final l10n = await l10nFor(const Locale('en'));
    stubBoard(const []);

    RatingModel pair(String id, List<String> members, int elo) => RatingModel(
      ratingId: RatingRepository.ratingId(SportIds.pingPong, id),
      ownerType: OwnerType.pair,
      ownerId: id,
      memberUids: members,
      sportId: SportIds.pingPong,
      elo: elo,
      matchesPlayed: 4,
      lastMatchAt: DateTime(2026, 6, 30),
    );

    when(
      () => ratingRepository.watchLeaderboard(
        sportId: any(named: 'sportId'),
        ownerType: OwnerType.pair,
        degreeProgram: any(named: 'degreeProgram'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) => Stream.value([
        pair('a_b', const ['a', 'b'], 1700),
        pair('c_d', const ['c', 'd'], 1600),
        pair('e_f', const ['e', 'f'], 1500),
        pair('g_h', const ['g', 'h'], 1400),
      ]),
    );

    UserModel u(String uid, String name) => UserModel(
      uid: uid,
      name: name,
      username: uid,
      email: '$uid@polimi.it',
      degreeProgram: 'Design',
      language: 'en',
      pushTokens: const [],
      friendUids: const [],
      badges: const {},
      onboardingComplete: true,
      createdAt: DateTime(2026),
    );
    when(() => userRepository.getUsersByIds(any())).thenAnswer(
      (_) async => [
        u('a', 'Anna'),
        u('b', 'Bruno'),
        u('c', 'Carla'),
        u('d', 'Dario'),
        u('e', 'Elsa'),
        u('f', 'Fabio'),
        u('g', 'Gina'),
        u('h', 'Hugo'),
      ],
    );

    await pumpAt(tester, wrap(buildCubit()));
    await tester.tap(find.text(l10n.matchModeDoubles));
    await tester.pumpAndSettle();

    // Top three pairs render in the podium; the fourth is a pair row beneath it.
    expect(find.byType(LeaderboardPodium), findsOneWidget);
    expect(find.text('Anna & Bruno'), findsOneWidget); // podium leader
    expect(find.text('Gina & Hugo'), findsOneWidget); // rank-4 pair row
    expect(find.byType(LeaderboardRow), findsOneWidget); // only the rank-4 row
    expect(tester.takeException(), isNull);
  });
}
