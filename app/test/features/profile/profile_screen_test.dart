import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/profile/cubit/profile_cubit.dart';
import 'package:campus_arena/features/profile/cubit/profile_state.dart';
import 'package:campus_arena/features/profile/profile_screen.dart';
import 'package:campus_arena/features/profile/profile_stats.dart';
import 'package:campus_arena/features/profile/widgets/elo_trend_card.dart';
import 'package:campus_arena/features/profile/widgets/fun_stat_card.dart';
import 'package:campus_arena/features/profile/widgets/profile_history_tile.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/models/rating_model.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/routing/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileCubit extends MockCubit<ProfileState>
    implements ProfileCubit {}

const _uid = 'me';

UserModel _user() => UserModel(
  uid: _uid,
  name: 'Mario Rossi',
  username: 'mrossi',
  email: 'me@polimi.it',
  degreeProgram: 'Computer Science and Engineering',
  language: 'en',
  pushTokens: const [],
  friendUids: const [],
  badges: const {},
  onboardingComplete: true,
  createdAt: DateTime(2026),
);

RatingModel _rating(String sportId, int elo) => RatingModel(
  ratingId: RatingRepository.ratingId(sportId, _uid),
  ownerType: OwnerType.user,
  ownerId: _uid,
  sportId: sportId,
  elo: elo,
  matchesPlayed: 10,
  // Recent, so the read-time decay leaves the stored ELO untouched and the
  // chip assertions stay exact.
  lastMatchAt: DateTime.now(),
);

MatchModel _match({
  required String id,
  required int day,
  String state = MatchStates.confirmed,
  bool won = true,
  Map<String, int>? eloDeltas,
}) => MatchModel(
  matchId: id,
  facilityId: 'f1',
  sportId: SportIds.pingPong,
  mode: 'singles',
  playerUids: const [_uid, 'opp'],
  state: state,
  result: state == MatchStates.confirmed
      ? PingPongResult(
          winnerIds: won ? const [_uid] : const ['opp'],
          sets: const [11, 11],
          opponentSets: const [5, 7],
        )
      : null,
  eloBefore: eloDeltas != null ? const {_uid: 1200, 'opp': 1200} : null,
  eloDeltas: eloDeltas,
  startedAt: DateTime(2026, 7, day, 10),
  confirmedAt: state == MatchStates.confirmed
      ? DateTime(2026, 7, day, 11)
      : null,
);

/// Chronological W W W L vs 'opp' plus one disputed match: games 4, wins 3,
/// losses 1, win rate 75%, current streak 0, best streak 3; the 4 matchups
/// pass the fun-stat gate on both sides.
final List<MatchModel> _matches = [
  _match(id: 'm5', day: 5, state: MatchStates.disputed),
  _match(id: 'm4', day: 4, won: false, eloDeltas: const {_uid: -11, 'opp': 11}),
  _match(id: 'm3', day: 3, eloDeltas: const {_uid: 12, 'opp': -12}),
  _match(id: 'm2', day: 2, eloDeltas: const {_uid: 14, 'opp': -14}),
  _match(id: 'm1', day: 1, eloDeltas: const {_uid: 16, 'opp': -16}),
];

ProfileState _readyState({List<MatchModel>? matches}) {
  final window = matches ?? _matches;
  return ProfileState(
    user: _user(),
    ratings: [
      _rating(SportIds.pingPong, 1482),
      _rating(SportIds.foosball, 1305),
    ],
    matches: window,
    derivation: deriveProfileStats(
      ProfileDerivationInput(uid: _uid, matches: window),
    ),
    opponentNames: const {'opp': 'luigi'},
    facilityNames: const {'f1': 'Table 1 — BL27'},
    status: ProfileStatus.ready,
  );
}

void main() {
  late MockProfileCubit cubit;

  setUp(() {
    cubit = MockProfileCubit();
    when(() => cubit.uid).thenReturn(_uid);
  });

  void stubState(ProfileState state) {
    whenListen(cubit, const Stream<ProfileState>.empty(), initialState: state);
  }

  Widget wrap({bool isOwnProfile = true}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<ProfileCubit>.value(
      value: cubit,
      child: ProfileView(isOwnProfile: isOwnProfile),
    ),
  );

  Future<AppLocalizations> en() =>
      AppLocalizations.delegate.load(const Locale('en'));

  /// Pumps [wrap] on a tall surface so the whole profile column builds —
  /// the ListView would otherwise cull the fun-stat cards and history rows
  /// below the default 600px fold.
  Future<void> pumpTall(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  testWidgets('renders header, ELO chips, trend card, stats and history', (
    tester,
  ) async {
    stubState(_readyState());
    await pumpTall(tester, wrap());
    final l10n = await en();

    // Header.
    expect(find.text('Mario Rossi'), findsOneWidget);
    expect(
      find.text(l10n.profileIdentityLine('mrossi', l10n.degComputer)),
      findsOneWidget,
    );

    // Per-sport ELO chips (undecayed: lastMatchAt is now).
    expect(find.text('1482'), findsOneWidget);
    expect(find.text('1305'), findsOneWidget);

    // Trend card with the in-card toggle.
    expect(find.text(l10n.profileEloTrendTitle), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(EloTrendCard),
        matching: find.text(l10n.sportFoosball),
      ),
      findsOneWidget,
    );

    // Stat tiles: 4 games, 3 wins (and best streak 3), 1 loss, 75%, streak 0.
    expect(find.text(l10n.profileStatGames), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('3'), findsNWidgets(2));
    expect(find.text(l10n.profileWinRateValue(75)), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    // Fun-stat cards: 3W–1L against luigi passes the gate on both sides.
    expect(find.text(l10n.profileBlackBeastTitle), findsOneWidget);
    expect(find.text(l10n.profileFavoriteVictimTitle), findsOneWidget);
    expect(find.text(l10n.profileHeadToHeadTally(3, 1)), findsNWidgets(2));
  });

  testWidgets('history rows show opponent, score·date·facility and delta', (
    tester,
  ) async {
    stubState(_readyState());
    await pumpTall(tester, wrap());
    final l10n = await en();

    // Opponent name on every history row (5 terminal matches; the fun-stat
    // cards repeat the name, so scope to the tiles).
    expect(
      find.descendant(
        of: find.byType(ProfileHistoryTile),
        matching: find.text('luigi'),
      ),
      findsNWidgets(5),
    );
    // Newest confirmed match lost 0–2 in sets, with its signed delta.
    expect(find.textContaining('0–2'), findsOneWidget);
    expect(find.text('-11'), findsOneWidget);
    expect(find.text('+16'), findsOneWidget);
    // The disputed row carries a status label instead of a delta.
    expect(find.text(l10n.matchStateDisputed), findsOneWidget);
    // Facility name resolved into the subtitle.
    expect(find.textContaining('Table 1 — BL27'), findsWidgets);
  });

  testWidgets('empty history renders trend + history empty states', (
    tester,
  ) async {
    stubState(_readyState(matches: const []));
    await pumpTall(tester, wrap());
    final l10n = await en();

    expect(find.text(l10n.profileTrendEmpty), findsOneWidget);
    expect(find.text(l10n.profileHistoryEmpty), findsOneWidget);
    expect(find.byType(FunStatCard), findsNothing);
    // Zeroed tiles still render.
    expect(find.text(l10n.profileStatGames), findsOneWidget);
    expect(find.text(l10n.profileWinRateValue(0)), findsOneWidget);
  });

  testWidgets('tapping the in-card toggle selects the sport', (tester) async {
    stubState(_readyState());
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    final l10n = await en();

    await tester.tap(
      find.descendant(
        of: find.byType(EloTrendCard),
        matching: find.text(l10n.sportFoosball),
      ),
    );
    verify(() => cubit.selectSport(SportIds.foosball)).called(1);
  });

  testWidgets('loading shows a spinner', (tester) async {
    stubState(ProfileState());
    await tester.pumpWidget(wrap());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error state offers retry', (tester) async {
    stubState(ProfileState(status: ProfileStatus.error));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    final l10n = await en();

    expect(find.text(l10n.profileLoadError), findsOneWidget);
    await tester.tap(find.text(l10n.retryButtonLabel));
    verify(() => cubit.retry()).called(1);
  });

  testWidgets('settings gear shows on the own profile and navigates', (
    tester,
  ) async {
    stubState(_readyState());
    final router = GoRouter(
      initialLocation: RouteConstants.profile,
      routes: [
        GoRoute(
          path: RouteConstants.profile,
          builder: (context, state) => BlocProvider<ProfileCubit>.value(
            value: cubit,
            child: const ProfileView(isOwnProfile: true),
          ),
        ),
        GoRoute(
          path: RouteConstants.settings,
          builder: (context, state) =>
              const Scaffold(body: Text('SETTINGS ROUTE')),
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

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS ROUTE'), findsOneWidget);
  });

  testWidgets('a foreign profile hides the settings gear', (tester) async {
    stubState(_readyState());
    await tester.pumpWidget(wrap(isOwnProfile: false));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
  });
}
