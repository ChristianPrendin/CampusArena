import 'package:campus_arena/features/auth/cubit/auth_cubit.dart';
import 'package:campus_arena/features/friends/friends_screen.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/challenge_repository.dart';
import 'package:campus_arena/repositories/facility_repository.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:campus_arena/routing/app_router.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_test_helpers.dart';

UserModel _user(String uid, String username) => UserModel(
  uid: uid,
  name: username,
  username: username,
  email: '$uid@polimi.it',
  degreeProgram: 'Computer Science',
  language: 'en',
  pushTokens: const [],
  friendUids: const [],
  badges: const {},
  onboardingComplete: true,
  createdAt: DateTime(2026),
);

void main() {
  testWidgets('add a friend end-to-end through the real router', (
    tester,
  ) async {
    final authCubit = authenticatedAuthCubit(uid: 'me');
    addTearDown(authCubit.close);
    final firestore = FakeFirebaseFirestore();
    final userRepository = UserRepository(firestore: firestore);
    await userRepository.createUser(_user('me', 'me'));
    await userRepository.createUser(_user('alice-uid', 'alice'));

    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: authCubit,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: createRouter(
            authCubit,
            ratingRepository: RatingRepository(firestore: firestore),
            matchRepository: MatchRepository(firestore: firestore),
            userRepository: userRepository,
            facilityRepository: FacilityRepository(firestore: firestore),
            challengeRepository: ChallengeRepository(firestore: firestore),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Leaderboards tab → add-friends app-bar action → friends screen.
    await tester.tap(find.byIcon(Icons.leaderboard_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_add_alt_1_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(FriendsScreen), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Search by username, then tap Add on the matching result row.
    await tester.enterText(find.byType(TextField), 'alice');
    await tester.pump(const Duration(milliseconds: 400)); // clear the debounce
    await tester.pumpAndSettle();
    expect(find.text(l10n.friendsHandle('alice')), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, l10n.friendsAddButton));
    await tester.pumpAndSettle();

    // Persisted to the signed-in user's friendUids.
    final me = await userRepository.getUser('me');
    expect(me!.friendUids, contains('alice-uid'));
  });
}
