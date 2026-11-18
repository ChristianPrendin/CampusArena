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

import '../helpers/auth_test_helpers.dart';

/// Regression guard for the localization pass: boot the real app tree in each
/// supported locale and assert it renders without throwing. Italian copy runs
/// ~15-20% longer than English, so a tight row that fits in English can trip a
/// `RenderFlex overflow` under `it` — that surfaces here as a captured
/// exception. ARB-parity checks cannot catch layout overflow; this can.
///
/// Scope is the authenticated home shell (what boot settles on). A full
/// per-screen walkthrough stays manual visual QA — this only pins the shell so
/// a regression there fails CI rather than only a human's eyes.
void main() {
  for (final languageCode in AppLocalizations.supportedLocales.map(
    (locale) => locale.languageCode,
  )) {
    testWidgets('home shell renders without overflow in "$languageCode"', (
      WidgetTester tester,
    ) async {
      final authCubit = authenticatedAuthCubit();
      addTearDown(authCubit.close);
      final firestore = FakeFirebaseFirestore();
      final userRepository = UserRepository(firestore: firestore);
      final localeCubit = LocaleCubit(userRepository: userRepository);
      addTearDown(localeCubit.close);

      // Pin the app to this locale before the first frame. With an empty
      // FakeFirebaseFirestore the app's `_LocaleSeeder` reads no user doc, so it
      // never seeds over this choice.
      localeCubit.seed(languageCode);

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

      // No overflow / FlutterError / missing-localization throw was captured
      // while laying out the shell in this locale.
      expect(tester.takeException(), isNull);

      // Boot landed on the home tab, localized in that language...
      final l10n = await AppLocalizations.delegate.load(Locale(languageCode));
      final playButton = find.text(l10n.playButtonLabel);
      expect(playButton, findsOneWidget);

      // ...and the tree below MaterialApp actually resolved to the pinned
      // locale (the MaterialApp element itself sits above Localizations).
      final context = tester.element(playButton);
      expect(Localizations.localeOf(context).languageCode, languageCode);
    });
  }
}
