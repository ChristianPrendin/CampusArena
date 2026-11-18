import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/core/theme/app_theme.dart';
import 'package:campus_arena/features/profile/team_profile/cubit/team_profile_cubit.dart';
import 'package:campus_arena/features/profile/team_profile/cubit/team_profile_state.dart';
import 'package:campus_arena/features/profile/team_profile/team_profile_screen.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/models/rating_model.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTeamProfileCubit extends MockCubit<TeamProfileState>
    implements TeamProfileCubit {}

UserModel _member(String uid, String name) => UserModel(
  uid: uid,
  name: name,
  username: name.toLowerCase(),
  email: '$uid@polimi.it',
  degreeProgram: 'Computer Science',
  language: 'en',
  pushTokens: const [],
  friendUids: const [],
  badges: const {},
  onboardingComplete: true,
  createdAt: DateTime(2026),
);

const _pairId = 'u1_u2';

TeamProfileState _ready({List<MatchModel> matches = const []}) =>
    TeamProfileState(
      pairId: _pairId,
      status: TeamProfileStatus.ready,
      members: [_member('u1', 'Mario Rossi'), _member('u2', 'Luigi Bianchi')],
      ratings: [
        RatingModel(
          ratingId: '${_pairId}_${SportIds.pingPong}',
          ownerType: 'pair',
          ownerId: _pairId,
          memberUids: const ['u1', 'u2'],
          sportId: SportIds.pingPong,
          elo: 1420,
          matchesPlayed: 6,
          lastMatchAt: DateTime(2026, 7, 9),
        ),
        // No foosball rating -> that chip renders the placeholder branch.
      ],
      matches: matches,
    );

MatchModel _doublesMatch() => MatchModel(
  matchId: 'm1',
  facilityId: 'f1',
  sportId: SportIds.pingPong,
  mode: 'doubles',
  playerUids: const ['u1', 'u2', 'o1', 'o2'],
  state: MatchStates.confirmed,
  result: PingPongResult(
    winnerIds: const ['u1', 'u2'],
    sets: const [11],
    opponentSets: const [7],
  ),
  eloDeltas: const {_pairId: 14},
  startedAt: DateTime(2026, 7, 9, 10),
);

Widget _wrap(MockTeamProfileCubit cubit) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<TeamProfileCubit>.value(
    value: cubit,
    child: const TeamProfileView(),
  ),
);

void main() {
  late MockTeamProfileCubit cubit;

  setUp(() => cubit = MockTeamProfileCubit());

  /// Renders on a tall surface so the whole history-bearing ListView builds
  /// (its children are lazily created and would otherwise stay off-screen).
  Future<void> pumpTall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump();
  }

  void seed(TeamProfileState state) {
    when(() => cubit.state).thenReturn(state);
    whenListen(
      cubit,
      const Stream<TeamProfileState>.empty(),
      initialState: state,
    );
  }

  testWidgets('loading shows a spinner', (tester) async {
    seed(TeamProfileState(pairId: _pairId));
    await tester.pumpWidget(_wrap(cubit));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error shows the message and retry re-triggers the cubit', (
    tester,
  ) async {
    seed(TeamProfileState(pairId: _pairId, status: TeamProfileStatus.error));
    await tester.pumpWidget(_wrap(cubit));

    expect(find.text('Couldn\'t load this team.'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pump();
    verify(() => cubit.retry()).called(1);
  });

  testWidgets('ready renders the two-member header and both ELO chips', (
    tester,
  ) async {
    seed(_ready());
    await pumpTall(tester);

    expect(find.text('Mario Rossi & Luigi Bianchi'), findsOneWidget);
    // Ping-pong chip shows the (undecayed) team ELO; foosball shows the
    // placeholder because no rating exists for it.
    expect(find.textContaining('1420'), findsOneWidget);
  });

  testWidgets('ready with no matches shows the empty-history notice', (
    tester,
  ) async {
    seed(_ready());
    await pumpTall(tester);

    expect(
      find.text('No matches yet — finished matches will appear here.'),
      findsOneWidget,
    );
  });

  testWidgets('ready with a match renders a history tile', (tester) async {
    seed(_ready(matches: [_doublesMatch()]));
    await pumpTall(tester);

    expect(
      find.text('No matches yet — finished matches will appear here.'),
      findsNothing,
    );
    expect(find.text('Match history'), findsOneWidget);
  });
}
