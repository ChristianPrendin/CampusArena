import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:campus_arena/routing/app_router.dart';
import 'package:campus_arena/routing/route_constants.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/features/home/home_screen.dart';
import 'package:campus_arena/features/map/map_screen.dart';
import 'package:campus_arena/features/leaderboards/leaderboards_screen.dart';
import 'package:campus_arena/features/profile/profile_screen.dart';
import 'package:campus_arena/features/auth/cubit/auth_cubit.dart';
import 'package:campus_arena/repositories/challenge_repository.dart';
import 'package:campus_arena/repositories/achievement_repository.dart';
import 'package:campus_arena/repositories/facility_repository.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../helpers/auth_test_helpers.dart';

void main() {
  Widget buildTestApp() {
    final authCubit = authenticatedAuthCubit();
    addTearDown(authCubit.close);
    // The Home and Map tabs build cubits against their repositories; back
    // them with an empty fake Firestore so they resolve to empty states
    // instead of hitting the uninitialised live Firebase instance.
    final firestore = FakeFirebaseFirestore();
    // The dashboard reads AuthCubit for the uid, mirroring the production
    // provider set up in main.dart.
    return BlocProvider<AuthCubit>.value(
      value: authCubit,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: createRouter(
          authCubit,
          ratingRepository: RatingRepository(firestore: firestore),
          matchRepository: MatchRepository(firestore: firestore),
          userRepository: UserRepository(firestore: firestore),
          facilityRepository: FacilityRepository(firestore: firestore),
          achievementRepository: AchievementRepository(firestore: firestore),
          challengeRepository: ChallengeRepository(firestore: firestore),
        ),
      ),
    );
  }

  group('AppRouter and AppShell', () {
    testWidgets('renders HomeScreen on initial load (authenticated)', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('navigates to MapScreen when map tab is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Tap the Map tab in the NavigationBar (bottom nav)
      // We look for the label defined in AppLocalizations (or icon)
      // Since l10n is loaded asynchronously in tests if not careful, we can just find by icon
      await tester.tap(find.byIcon(Icons.map_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(MapScreen), findsOneWidget);
    });

    testWidgets(
      'navigates to LeaderboardsScreen when leaderboards tab is tapped',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.leaderboard_outlined));
        await tester.pumpAndSettle();

        expect(find.byType(LeaderboardsScreen), findsOneWidget);
      },
    );

    testWidgets('navigates to ProfileScreen when profile tab is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets(
      'a leaderboard drill-in reuses ProfileScreen for a foreign uid, gear hidden',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(HomeScreen));
        GoRouter.of(context).push(RouteConstants.publicProfile('other-uid'));
        await tester.pumpAndSettle();

        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(find.byIcon(Icons.settings_outlined), findsNothing);
      },
    );
  });
}
