import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/auth/cubit/auth_cubit.dart';
import 'package:campus_arena/features/friends/friends_screen.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/challenge_model.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/auth_repository.dart';
import 'package:campus_arena/repositories/challenge_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:campus_arena/routing/route_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockUserRepository extends Mock implements UserRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockRatingRepository extends Mock implements RatingRepository {}

class MockChallengeRepository extends Mock implements ChallengeRepository {}

class MockUser extends Mock implements User {}

const _uid = 'me';

UserModel _user(
  String uid,
  String username, {
  List<String> friendUids = const [],
}) => UserModel(
  uid: uid,
  name: username,
  username: username,
  email: '$uid@polimi.it',
  degreeProgram: 'Computer Science',
  language: 'en',
  pushTokens: const [],
  friendUids: friendUids,
  badges: const {},
  onboardingComplete: true,
  createdAt: DateTime(2026),
);

void main() {
  late MockUserRepository userRepository;
  late MockChallengeRepository challengeRepository;
  late AuthCubit authCubit;

  setUp(() {
    userRepository = MockUserRepository();
    challengeRepository = MockChallengeRepository();
    when(
      () => userRepository.watchUser(_uid),
    ).thenAnswer((_) => Stream.value(_user(_uid, 'me')));
    // The friends screen hosts a ChallengeCubit for the send action; keep its
    // streams empty so the friends assertions are unaffected.
    when(
      () => challengeRepository.watchIncomingPending(_uid),
    ).thenAnswer((_) => Stream.value(const <ChallengeModel>[]));
    when(
      () => challengeRepository.watchOutgoingRecent(_uid),
    ).thenAnswer((_) => Stream.value(const <ChallengeModel>[]));

    final authRepository = MockAuthRepository();
    final sessionUser = MockUser();
    when(() => sessionUser.uid).thenReturn(_uid);
    when(
      () => authRepository.authStateChanges(),
    ).thenAnswer((_) => Stream<User?>.value(sessionUser));

    authCubit = AuthCubit(
      authRepository: authRepository,
      userRepository: userRepository,
      ratingRepository: MockRatingRepository(),
    );
    addTearDown(authCubit.close);
  });

  Widget wrap() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
        value: authCubit,
        child: FriendsScreen(
          userRepository: userRepository,
          challengeRepository: challengeRepository,
        ),
      ),
    );
  }

  /// Router-backed harness: the friends screen plus a stub public-profile route
  /// so `context.push` has somewhere to land.
  Widget wrapRouter() {
    final router = GoRouter(
      initialLocation: RouteConstants.friends,
      routes: [
        GoRoute(
          path: RouteConstants.friends,
          builder: (_, _) => BlocProvider.value(
            value: authCubit,
            child: FriendsScreen(
              userRepository: userRepository,
              challengeRepository: challengeRepository,
            ),
          ),
        ),
        GoRoute(
          path: RouteConstants.publicProfilePath,
          builder: (_, state) =>
              Scaffold(body: Text('profile:${state.pathParameters['uid']}')),
        ),
      ],
    );
    return MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }

  Future<AppLocalizations> en() =>
      AppLocalizations.delegate.load(const Locale('en'));

  testWidgets('empty friends list shows the empty state', (tester) async {
    final l10n = await en();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text(l10n.friendsEmptyTitle), findsOneWidget);
    expect(find.text(l10n.friendsEmptyBody), findsOneWidget);
  });

  testWidgets('a search matching nobody shows the empty-results state', (
    tester,
  ) async {
    when(
      () => userRepository.searchUsers('ghost'),
    ).thenAnswer((_) async => const []);
    final l10n = await en();

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ghost');
    await tester.pump(const Duration(milliseconds: 400)); // clear the debounce
    await tester.pumpAndSettle();

    expect(find.text(l10n.friendsSearchEmpty('ghost')), findsOneWidget);
  });

  testWidgets('tapping Add on a search result writes the friend and confirms', (
    tester,
  ) async {
    when(
      () => userRepository.searchUsers('alice'),
    ).thenAnswer((_) async => [_user('u_alice', 'alice')]);
    when(
      () => userRepository.addFriend(_uid, 'u_alice'),
    ).thenAnswer((_) async {});
    final l10n = await en();

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'alice');
    await tester.pump(const Duration(milliseconds: 400)); // clear the debounce
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, l10n.friendsAddButton));
    await tester.pump();
    await tester.pump();

    verify(() => userRepository.addFriend(_uid, 'u_alice')).called(1);
    expect(find.text(l10n.friendsAddedSnack('alice')), findsOneWidget);
  });

  testWidgets('tapping a friend row opens their public profile', (
    tester,
  ) async {
    when(() => userRepository.watchUser(_uid)).thenAnswer(
      (_) => Stream.value(_user(_uid, 'me', friendUids: const ['alice-uid'])),
    );
    when(
      () => userRepository.getUsersByIds(const ['alice-uid']),
    ).thenAnswer((_) async => [_user('alice-uid', 'alice')]);

    await tester.pumpWidget(wrapRouter());
    await tester.pumpAndSettle();

    // Tap the row body (the name), not the trailing challenge/remove buttons.
    await tester.tap(find.text('alice'));
    await tester.pumpAndSettle();

    expect(find.text('profile:alice-uid'), findsOneWidget);
  });

  testWidgets('challenge sheet sends with the picked sport and confirms', (
    tester,
  ) async {
    when(() => userRepository.watchUser(_uid)).thenAnswer(
      (_) => Stream.value(_user(_uid, 'me', friendUids: const ['alice-uid'])),
    );
    when(
      () => userRepository.getUsersByIds(const ['alice-uid']),
    ).thenAnswer((_) async => [_user('alice-uid', 'alice')]);
    when(
      () => challengeRepository.sendChallenge(
        fromUserId: _uid,
        toUserId: 'alice-uid',
        sportId: SportIds.pingPong,
      ),
    ).thenAnswer((_) async {});
    final l10n = await en();

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Open the send-challenge sheet from the friend row.
    await tester.tap(find.byIcon(Icons.sports));
    await tester.pumpAndSettle();

    // Ping pong is selected by default; send.
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.challengeSheetSend),
    );
    await tester.pumpAndSettle();

    verify(
      () => challengeRepository.sendChallenge(
        fromUserId: _uid,
        toUserId: 'alice-uid',
        sportId: SportIds.pingPong,
      ),
    ).called(1);
    expect(find.text(l10n.challengeSentSnack('alice')), findsOneWidget);
  });

  testWidgets('a duplicate-pending send surfaces the distinct error', (
    tester,
  ) async {
    when(() => userRepository.watchUser(_uid)).thenAnswer(
      (_) => Stream.value(_user(_uid, 'me', friendUids: const ['alice-uid'])),
    );
    when(
      () => userRepository.getUsersByIds(const ['alice-uid']),
    ).thenAnswer((_) async => [_user('alice-uid', 'alice')]);
    when(
      () => challengeRepository.sendChallenge(
        fromUserId: _uid,
        toUserId: 'alice-uid',
        sportId: SportIds.pingPong,
      ),
    ).thenThrow(const ChallengeException(ChallengeError.duplicatePending));
    final l10n = await en();

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.sports));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.challengeSheetSend),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.challengeErrorDuplicate), findsOneWidget);
  });
}
