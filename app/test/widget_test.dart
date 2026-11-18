import 'package:campus_arena/features/settings/cubit/locale_cubit.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/main.dart';
import 'package:campus_arena/repositories/challenge_repository.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:campus_arena/routing/app_router.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_helpers.dart';

void main() {
  testWidgets('CampusArena Smoke Test (authenticated → home)', (
    WidgetTester tester,
  ) async {
    final authCubit = authenticatedAuthCubit();
    addTearDown(authCubit.close);
    final firestore = FakeFirebaseFirestore();
    final userRepository = UserRepository(firestore: firestore);
    final localeCubit = LocaleCubit(userRepository: userRepository);
    addTearDown(localeCubit.close);

    await tester.pumpWidget(
      MyApp(
        authCubit: authCubit,
        localeCubit: localeCubit,
        userRepository: userRepository,
        router: createRouter(
          authCubit,
          ratingRepository: RatingRepository(firestore: firestore),
          matchRepository: MatchRepository(firestore: firestore),
          userRepository: userRepository,
          challengeRepository: ChallengeRepository(firestore: firestore),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Authenticated boot lands on the home tab: the dashboard's Play button.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.playButtonLabel), findsOneWidget);
  });
}
