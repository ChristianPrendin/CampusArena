import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/auth/cubit/auth_cubit.dart';
import 'package:campus_arena/features/challenges/challenge_screen.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/challenge_model.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/challenge_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/auth_test_helpers.dart';

class MockChallengeRepository extends Mock implements ChallengeRepository {}

const _me = 'me';
const _other = 'rival';

ChallengeModel _challenge({
  required String from,
  required String to,
  String status = ChallengeStatus.pending,
  String sportId = SportIds.pingPong,
}) => ChallengeModel(
  challengeId: 'c1',
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
  late AuthCubit authCubit;

  setUp(() {
    challengeRepository = MockChallengeRepository();
    userRepository = MockUserRepository();
    authCubit = authenticatedAuthCubit(uid: _me);
    addTearDown(authCubit.close);
    when(() => userRepository.getUsersByIds(any())).thenAnswer((inv) async {
      final ids = inv.positionalArguments[0] as List<String>;
      return ids.map((id) => _user(id, 'Rival')).toList();
    });
  });

  void stubChallenge(ChallengeModel? challenge) {
    when(
      () => challengeRepository.watchChallenge('c1'),
    ).thenAnswer((_) => Stream.value(challenge));
  }

  Widget wrap({Locale locale = const Locale('en')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
        value: authCubit,
        child: ChallengeScreen(
          challengeId: 'c1',
          challengeRepository: challengeRepository,
          userRepository: userRepository,
        ),
      ),
    );
  }

  Future<AppLocalizations> l10nFor(Locale locale) =>
      AppLocalizations.delegate.load(locale);

  testWidgets('recipient sees accept and decline actions', (tester) async {
    stubChallenge(_challenge(from: _other, to: _me));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    final l10n = await l10nFor(const Locale('en'));

    expect(find.text(l10n.challengeAccept), findsOneWidget);
    expect(find.text(l10n.challengeDecline), findsOneWidget);
  });

  testWidgets('sender does not get the action buttons, sees a waiting state', (
    tester,
  ) async {
    stubChallenge(_challenge(from: _me, to: _other));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    final l10n = await l10nFor(const Locale('en'));

    expect(find.text(l10n.challengeAccept), findsNothing);
    expect(find.text(l10n.challengeDecline), findsNothing);
    expect(find.text(l10n.challengeWaitingTitle('Rival')), findsOneWidget);
  });

  testWidgets('accepting calls respond(accept: true)', (tester) async {
    stubChallenge(_challenge(from: _other, to: _me));
    when(
      () => challengeRepository.respond(challengeId: 'c1', accept: true),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    final l10n = await l10nFor(const Locale('en'));

    await tester.tap(find.text(l10n.challengeAccept));
    await tester.pump();

    verify(
      () => challengeRepository.respond(challengeId: 'c1', accept: true),
    ).called(1);
  });

  testWidgets('an accepted challenge offers a scan-to-play CTA', (
    tester,
  ) async {
    stubChallenge(
      _challenge(from: _other, to: _me, status: ChallengeStatus.accepted),
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    final l10n = await l10nFor(const Locale('en'));

    expect(find.text(l10n.challengeScanToPlay), findsOneWidget);
  });

  testWidgets('a missing challenge shows the not-found copy', (tester) async {
    stubChallenge(null);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    final l10n = await l10nFor(const Locale('en'));

    expect(find.text(l10n.challengeNotFound), findsOneWidget);
  });

  testWidgets('renders the recipient prompt in Italian', (tester) async {
    stubChallenge(_challenge(from: _other, to: _me));
    await tester.pumpWidget(wrap(locale: const Locale('it')));
    await tester.pumpAndSettle();
    final l10n = await l10nFor(const Locale('it'));

    expect(find.text(l10n.challengeAccept), findsOneWidget); // "Accetta"
    expect(find.text('Accetta'), findsOneWidget);
  });
}
