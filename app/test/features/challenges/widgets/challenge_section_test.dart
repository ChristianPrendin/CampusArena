import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/challenges/cubit/challenge_cubit.dart';
import 'package:campus_arena/features/challenges/widgets/challenge_section.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/challenge_model.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/challenge_repository.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:campus_arena/routing/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockChallengeRepository extends Mock implements ChallengeRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockMatchRepository extends Mock implements MatchRepository {}

const _me = 'me';

ChallengeModel _challenge(
  String id, {
  String from = 'alice',
  String to = _me,
  String sportId = SportIds.pingPong,
  String status = ChallengeStatus.pending,
}) => ChallengeModel(
  challengeId: id,
  fromUserId: from,
  toUserId: to,
  sportId: sportId,
  status: status,
  createdAt: DateTime(2026, 7, 6, 10),
);

UserModel _user(String uid, String name) => UserModel(
  uid: uid,
  name: name,
  username: uid,
  email: '$uid@polimi.it',
  degreeProgram: 'CS',
  language: 'en',
  pushTokens: const [],
  friendUids: const [],
  badges: const {},
  onboardingComplete: true,
  createdAt: DateTime(2026),
);

void main() {
  late MockChallengeRepository challengeRepository;
  late MockUserRepository userRepository;
  late MockMatchRepository matchRepository;

  setUp(() {
    challengeRepository = MockChallengeRepository();
    userRepository = MockUserRepository();
    matchRepository = MockMatchRepository();
    when(
      () => matchRepository.watchUserMatches(_me, limit: any(named: 'limit')),
    ).thenAnswer((_) => const Stream<List<MatchModel>>.empty());
    when(() => userRepository.getUsersByIds(any())).thenAnswer((inv) async {
      final ids = inv.positionalArguments[0] as List<String>;
      return ids.map((id) => _user(id, id == 'alice' ? 'Alice' : id)).toList();
    });
    when(
      () => challengeRepository.expireIfDue(any(), now: any(named: 'now')),
    ).thenAnswer((_) async {});
  });

  setUpAll(() {
    registerFallbackValue(_challenge('fallback'));
  });

  void stub({
    List<ChallengeModel> incoming = const [],
    List<ChallengeModel> outgoing = const [],
  }) {
    when(
      () => challengeRepository.watchIncomingPending(_me),
    ).thenAnswer((_) => Stream.value(incoming));
    when(
      () => challengeRepository.watchOutgoingRecent(_me),
    ).thenAnswer((_) => Stream.value(outgoing));
  }

  Widget wrap({Locale locale = const Locale('en')}) {
    final cubit = ChallengeCubit(
      uid: _me,
      challengeRepository: challengeRepository,
      userRepository: userRepository,
      matchRepository: matchRepository,
    );
    addTearDown(cubit.close);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const ChallengeSection(),
            ),
          ),
        ),
        // Stand-in for the /challenge/:id screen so accept navigation is
        // observable without pulling in the real screen's dependencies.
        GoRoute(
          path: RouteConstants.challengePath,
          builder: (context, state) => Scaffold(
            body: Text('challenge-detail-${state.pathParameters['id']}'),
          ),
        ),
      ],
    );
    return MaterialApp.router(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }

  Future<AppLocalizations> l10nFor(Locale locale) =>
      AppLocalizations.delegate.load(locale);

  testWidgets('renders challenger name and the localized sport line', (
    tester,
  ) async {
    stub(incoming: [_challenge('c1')]);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    final l10n = await l10nFor(const Locale('en'));

    expect(find.text('Alice'), findsOneWidget);
    expect(
      find.text(l10n.challengeChallengedYou(l10n.sportPingPong)),
      findsOneWidget,
    );
  });

  testWidgets('accepting responds and opens the challenge screen', (
    tester,
  ) async {
    stub(incoming: [_challenge('c1')]);
    when(
      () => challengeRepository.respond(
        challengeId: 'c1',
        accept: any(named: 'accept'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    final l10n = await l10nFor(const Locale('en'));

    await tester.tap(find.byTooltip(l10n.challengeAcceptTooltip));
    await tester.pumpAndSettle();
    verify(
      () => challengeRepository.respond(challengeId: 'c1', accept: true),
    ).called(1);
    // A successful accept routes the recipient to the challenge's scan-to-play
    // screen instead of leaving them on an empty dashboard.
    expect(find.text('challenge-detail-c1'), findsOneWidget);
  });

  testWidgets('declining responds and stays on the dashboard', (tester) async {
    stub(incoming: [_challenge('c1')]);
    when(
      () => challengeRepository.respond(
        challengeId: 'c1',
        accept: any(named: 'accept'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    final l10n = await l10nFor(const Locale('en'));

    await tester.tap(find.byTooltip(l10n.challengeDeclineTooltip));
    await tester.pumpAndSettle();
    verify(
      () => challengeRepository.respond(challengeId: 'c1', accept: false),
    ).called(1);
    expect(find.text('challenge-detail-c1'), findsNothing);
  });

  testWidgets('collapses to nothing when both lists are empty', (tester) async {
    stub();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    final l10n = await l10nFor(const Locale('en'));

    expect(find.byTooltip(l10n.challengeAcceptTooltip), findsNothing);
    expect(find.byType(SizedBox), findsWidgets); // rendered SizedBox.shrink
  });

  testWidgets('outgoing row shows a status chip', (tester) async {
    stub(
      outgoing: [
        _challenge(
          'o1',
          from: _me,
          to: 'alice',
          status: ChallengeStatus.accepted,
        ),
      ],
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    final l10n = await l10nFor(const Locale('en'));

    expect(find.text(l10n.challengeOutgoingLabel('Alice')), findsOneWidget);
    expect(find.text(l10n.challengeStatusAccepted), findsOneWidget);
  });

  testWidgets('renders in Italian', (tester) async {
    stub(incoming: [_challenge('c1')]);
    await tester.pumpWidget(wrap(locale: const Locale('it')));
    await tester.pumpAndSettle();
    final l10n = await l10nFor(const Locale('it'));

    expect(
      find.text(l10n.challengeChallengedYou(l10n.sportPingPong)),
      findsOneWidget,
    );
    expect(
      l10n.challengeChallengedYou(l10n.sportPingPong),
      'ti ha sfidato a Ping Pong',
    );
  });
}
