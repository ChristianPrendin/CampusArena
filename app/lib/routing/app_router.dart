import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/cubit/auth_state.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/landing_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/challenges/challenge_screen.dart';
import '../features/chatbot/chat_screen.dart';
import '../features/chatbot/cubit/chat_cubit.dart';
import '../features/chatbot/data/assistant_settings_repository.dart';
import '../features/chatbot/data/chatbot_repository.dart';
import '../features/chatbot/settings/assistant_settings_screen.dart';
import '../features/friends/friends_screen.dart';
import '../features/home/home_screen.dart';
import '../features/leaderboards/leaderboards_screen.dart';
import '../features/map/map_screen.dart';
import '../features/match/match_flow_page.dart';
import '../features/onboarding/onboarding_cubit.dart';
import '../features/map/user_location_service.dart';
import '../features/onboarding/mini_tutorial_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/team_profile/team_profile_screen.dart';
import '../features/result/result_flow_page.dart';
import '../features/settings/settings_screen.dart';
import '../features/tournaments/bracket_screen.dart';
import '../features/tournaments/create_tournament_screen.dart';
import '../features/tournaments/tournament_browser_screen.dart';
import '../features/tournaments/tournament_detail_screen.dart';
import '../repositories/achievement_repository.dart';
import '../repositories/challenge_repository.dart';
import '../repositories/facility_repository.dart';
import '../repositories/match_repository.dart';
import '../repositories/queue_repository.dart';
import '../repositories/rating_repository.dart';
import '../repositories/tournament_repository.dart';
import '../repositories/user_repository.dart';
import 'app_shell.dart';
import 'go_router_refresh_stream.dart';
import 'route_constants.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Unauthenticated routes; the redirect lets these through when the user is not
/// signed in and bounces away from them once authenticated.
const Set<String> _authLocations = {
  RouteConstants.splash,
  RouteConstants.landing,
  RouteConstants.login,
  RouteConstants.register,
  RouteConstants.forgotPassword,
};

/// Onboarding routes; reachable only while authenticated and not yet onboarded.
const Set<String> _onboardingLocations = {RouteConstants.onboardingTutorial};

/// Locations that arrive from OUTSIDE the app (QR sticker, push notification)
/// and must survive the auth bounce. The in-app blind scanner (`/play/scan`) is
/// deliberately excluded — it is only ever reached from a signed-in session.
bool _isDeepLinkTarget(String location) =>
    location.startsWith('/play/facility/') ||
    location.startsWith('/challenge/');

/// Builds the app router bound to [authCubit]. The repository parameters exist
/// so tests can inject fakes into the dashboard and map tabs; production
/// passes none and the screens default to the live Firestore-backed
/// repositories.
GoRouter createRouter(
  AuthCubit authCubit, {
  RatingRepository? ratingRepository,
  MatchRepository? matchRepository,
  UserRepository? userRepository,
  FacilityRepository? facilityRepository,
  AchievementRepository? achievementRepository,
  QueueRepository? queueRepository,
  TournamentRepository? tournamentRepository,
  ChallengeRepository? challengeRepository,
  UserLocationService? locationService,
  TileProvider? tileProvider,
}) {
  // A deep link the app was cold-launched into (QR scan / push target) while
  // auth was still resolving. Without it, the splash/landing bounce below
  // discards the destination and the user lands on the dashboard instead of the
  // scanned facility. Stashed on the way in, delivered once — and only once —
  // the user is authenticated and onboarded. Scoped to this router instance
  // (not a library global) so concurrent routers / tests never cross-talk.
  String? pendingDeepLink;

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RouteConstants.splash,
    refreshListenable: GoRouterRefreshStream(authCubit.stream),
    redirect: (context, state) {
      // Custom-scheme deep links (`campusarena://play/facility/<id>`) parse with
      // the first path segment as the URI host, so go_router would otherwise see
      // `/facility/<id>` and fail to match. Rebuild the intended path once; the
      // redirect re-runs on the scheme-less location and falls through to the
      // auth/onboarding logic below.
      if (state.uri.scheme == 'campusarena' && state.uri.host.isNotEmpty) {
        final query = state.uri.hasQuery ? '?${state.uri.query}' : '';
        return '/${state.uri.host}${state.uri.path}$query';
      }

      final authState = authCubit.state;
      final status = authState.status;
      final location = state.matchedLocation;
      final current = state.uri.toString();
      final onAuthScreen = _authLocations.contains(location);
      final onOnboarding = _onboardingLocations.contains(location);
      final ready =
          status == AuthStatus.authenticated &&
          authState.onboardingComplete == true;

      // Preserve a cold-launched deep link across the auth/onboarding bounce.
      if (!ready && _isDeepLinkTarget(location)) {
        pendingDeepLink = current;
      }

      // Still resolving the first auth event: hold on the splash.
      if (status == AuthStatus.initial) {
        return location == RouteConstants.splash ? null : RouteConstants.splash;
      }

      if (status == AuthStatus.authenticated) {
        final onboardingComplete = authState.onboardingComplete;

        // Registration is mid-flight (auth account created, user doc / ratings
        // still being written or rolled back). Hold on RegisterScreen so its
        // BlocListener can surface a UsernameTakenException / failure instead of
        // the app bouncing to splash and swallowing it. Cleared once ratings
        // seed and the handle is claimed (success) or the rollback emits an
        // error/unauthenticated state.
        if (authState.registrationInProgress) {
          return location == RouteConstants.register
              ? null
              : RouteConstants.register;
        }

        // Authenticated but the profile doc is confirmed absent (Auth account
        // with no users/{uid} doc — a wiped/re-seeded database, or an account
        // that never finished provisioning). The onboarding tutorial would
        // dead-end here (its completion write targets a non-existent doc), so
        // route to registration to recreate the profile for this uid.
        if (authState.profileMissing) {
          return location == RouteConstants.register
              ? null
              : RouteConstants.register;
        }

        // Authenticated but the user doc hasn't loaded yet: hold on the splash.
        if (onboardingComplete == null) {
          return location == RouteConstants.splash
              ? null
              : RouteConstants.splash;
        }

        // First launch: route new users into onboarding and keep them there.
        if (!onboardingComplete) {
          return onOnboarding ? null : RouteConstants.onboardingTutorial;
        }

        // Fully ready: deliver a stashed deep link before anything else, exactly
        // once (nulling it first so the redirect it triggers doesn't loop).
        final pending = pendingDeepLink;
        if (pending != null) {
          pendingDeepLink = null;
          if (pending != current) return pending;
        }

        // Onboarded: keep out of the auth and onboarding flows.
        return (onAuthScreen || onOnboarding) ? RouteConstants.home : null;
      }

      // Not signed in (unauthenticated / loading / error): protected routes
      // bounce to landing; the splash resolves to landing; auth screens stay.
      if (!onAuthScreen || location == RouteConstants.splash) {
        return RouteConstants.landing;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: RouteConstants.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteConstants.landing,
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: RouteConstants.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteConstants.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RouteConstants.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      // First launch shows only the mini-tutorial; the old avatar/permission
      // setup screen was removed (permissions are requested contextually by the
      // scanner and the map). Finishing the walkthrough flips onboardingComplete
      // via OnboardingCubit and the redirect above routes to home.
      GoRoute(
        path: RouteConstants.onboardingTutorial,
        builder: (context, state) => BlocProvider<OnboardingCubit>(
          create: (_) => OnboardingCubit(uid: authCubit.state.uid!),
          child: const MiniTutorialScreen(),
        ),
      ),
      // Friends & Settings live outside the shell too (full-screen with a back
      // arrow, no bottom nav — matches settings.png), auth-guarded by the same
      // top-level redirect. Reached by direct navigation / the profile gear.
      GoRoute(
        path: RouteConstants.friends,
        builder: (context, state) => FriendsScreen(
          userRepository: userRepository,
          challengeRepository: challengeRepository,
        ),
      ),
      GoRoute(
        path: RouteConstants.settings,
        builder: (context, state) =>
            SettingsScreen(userRepository: userRepository),
      ),
      // Blind QR scanner (opened from the Dashboard "Play" button). An accepted
      // challenge appends `?sport=…` so the scan is locked to that sport's
      // tables.
      GoRoute(
        path: RouteConstants.qrScan,
        builder: (context, state) => MatchFlowPage(
          expectedSportId: state.uri.queryParameters['sport'],
          matchRepository: matchRepository,
          facilityRepository: facilityRepository,
          queueRepository: queueRepository,
          ratingRepository: ratingRepository,
          userRepository: userRepository,
          locationService: locationService,
        ),
      ),
      // Deep link for a scanned table QR: resolves the facility and either
      // attaches to its live match or offers check-in. A tournament bracket
      // slot's check-in URL carries `?tournamentId=…&round=…`, threaded through
      // so the created match doc records under the bracket and earns the ×1.5.
      GoRoute(
        path: RouteConstants.facilityPath,
        builder: (context, state) => MatchFlowPage(
          facilityId: state.pathParameters['id'],
          tournamentId: state.uri.queryParameters['tournamentId'],
          tournamentRound: state.uri.queryParameters['round'],
          matchRepository: matchRepository,
          facilityRepository: facilityRepository,
          queueRepository: queueRepository,
          ratingRepository: ratingRepository,
          userRepository: userRepository,
          tournamentRepository: tournamentRepository,
          locationService: locationService,
        ),
      ),
      // Tournaments browser (feature/B), outside the shell on the root
      // navigator. The `/tournaments/:id` detail route is registered LAST among
      // the tournament routes (after create + bracket, below) so the literal
      // `create`/`bracket` segments are never swallowed by the `:id` param.
      GoRoute(
        path: RouteConstants.tournaments,
        builder: (context, state) => TournamentBrowserScreen(
          tournamentRepository: tournamentRepository,
          facilityRepository: facilityRepository,
        ),
      ),
      // Result-entry flow (feature/C-result-flow): score entry → confirmation →
      // summary, streamed off the match doc's state.
      GoRoute(
        path: RouteConstants.matchResultPath,
        builder: (context, state) => ResultFlowPage(
          matchId: state.pathParameters['id'] ?? '',
          matchRepository: matchRepository,
          ratingRepository: ratingRepository,
          userRepository: userRepository,
        ),
      ),
      // Direct-challenge deep link (root navigator, outside the shell). Kept
      // working so a future Blaze-tier push can target `/challenge/:id`.
      GoRoute(
        path: RouteConstants.challengePath,
        builder: (context, state) => ChallengeScreen(
          challengeId: state.pathParameters['id'] ?? '',
          challengeRepository: challengeRepository,
          userRepository: userRepository,
        ),
      ),
      // Public player profile (drill-in from a leaderboard row), outside the
      // shell so it pushes over the current tab. Reuses ProfileScreen with a
      // foreign uid (Phase 5/A reuse — see profile_screen.dart), which hides
      // the settings gear and streams the tapped player's own stats.
      GoRoute(
        path: RouteConstants.publicProfilePath,
        // Router-level self guard: the public drill-in reuses ProfileScreen with
        // the settings gear hidden, so opening it on yourself is a strictly
        // worse view of your own Profile tab. Bounce it here so every caller of
        // `publicProfile(uid)` inherits the guard, not just the leaderboard row.
        redirect: (context, state) =>
            state.pathParameters['uid'] == authCubit.state.uid
            ? RouteConstants.profile
            : null,
        builder: (context, state) => ProfileScreen(
          uid: state.pathParameters['uid'] ?? '',
          ratingRepository: ratingRepository,
          matchRepository: matchRepository,
          userRepository: userRepository,
          facilityRepository: facilityRepository,
          achievementRepository: achievementRepository,
        ),
      ),
      // Team (pair) profile — the doubles drill-in from a leaderboard row.
      // Outside the shell like the public profile; `sportId` (query) picks the
      // initial doubles board the row was tapped from.
      GoRoute(
        path: RouteConstants.teamProfilePath,
        builder: (context, state) => TeamProfileScreen(
          pairId: state.pathParameters['pairId'] ?? '',
          initialSportId: state.uri.queryParameters['sportId'],
          ratingRepository: ratingRepository,
          matchRepository: matchRepository,
          userRepository: userRepository,
          facilityRepository: facilityRepository,
        ),
      ),
      // Tournament create + live bracket (feature/A-tournament-bracket), outside
      // the shell on the root navigator like /chatbot. `/tournaments/create`
      // MUST stay registered before any `/tournaments/:id` route (6-B's browser
      // + detail) so the literal `create` segment isn't swallowed by the param.
      GoRoute(
        path: RouteConstants.tournamentCreate,
        builder: (context, state) => CreateTournamentScreen(
          tournamentRepository: tournamentRepository,
          facilityRepository: facilityRepository,
        ),
      ),
      GoRoute(
        path: RouteConstants.tournamentBracketPath,
        builder: (context, state) => BracketScreen(
          tournamentId: state.pathParameters['id'] ?? '',
          tournamentRepository: tournamentRepository,
          matchRepository: matchRepository,
          userRepository: userRepository,
          facilityRepository: facilityRepository,
        ),
      ),
      // Tournament detail (feature/B). Registered LAST so its `:id` param never
      // shadows the literal `/tournaments/create` or `/tournaments/:id/bracket`.
      GoRoute(
        path: RouteConstants.tournamentDetailPath,
        builder: (context, state) => TournamentDetailScreen(
          tournamentId: state.pathParameters['id'] ?? '',
          tournamentRepository: tournamentRepository,
          matchRepository: matchRepository,
          userRepository: userRepository,
          ratingRepository: ratingRepository,
        ),
      ),
      // Full-screen Arena Assistant, pushed on top of the shell (not a 5th
      // tab). Auth-guarded like courtPath/challengePath above: not listed in
      // _authLocations/_onboardingLocations, so the redirect's protected-route
      // branch bounces unauthenticated users to /landing.
      GoRoute(
        path: RouteConstants.chatbot,
        builder: (context, state) {
          return BlocProvider<ChatCubit>(
            create: (context) => ChatCubit(
              uid: authCubit.state.uid ?? '',
              chatbotRepository: context.read<ChatbotRepository>(),
              settingsRepository: context.read<AssistantSettingsRepository>(),
            ),
            child: const ChatScreen(),
          );
        },
      ),
      GoRoute(
        path: RouteConstants.chatbotSettings,
        builder: (context, state) => const AssistantSettingsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteConstants.home,
                builder: (context, state) => HomeScreen(
                  ratingRepository: ratingRepository,
                  matchRepository: matchRepository,
                  userRepository: userRepository,
                  challengeRepository: challengeRepository,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteConstants.map,
                builder: (context, state) => MapScreen(
                  facilityRepository: facilityRepository,
                  matchRepository: matchRepository,
                  userRepository: userRepository,
                  tileProvider: tileProvider,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteConstants.leaderboards,
                builder: (context, state) => LeaderboardsScreen(
                  ratingRepository: ratingRepository,
                  userRepository: userRepository,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteConstants.profile,
                builder: (context, state) => ProfileScreen(
                  ratingRepository: ratingRepository,
                  matchRepository: matchRepository,
                  userRepository: userRepository,
                  facilityRepository: facilityRepository,
                  achievementRepository: achievementRepository,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
