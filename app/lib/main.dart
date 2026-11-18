import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:campus_arena/firebase_options.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/features/auth/cubit/auth_cubit.dart';
import 'package:campus_arena/features/auth/cubit/auth_state.dart';
import 'package:campus_arena/features/chatbot/data/assistant_settings_repository.dart';
import 'package:campus_arena/features/chatbot/data/chatbot_repository.dart';
import 'package:campus_arena/features/chatbot/data/chatbot_tools_service.dart';
import 'package:campus_arena/features/settings/cubit/locale_cubit.dart';
import 'package:campus_arena/features/map/tile_cache.dart';
import 'package:campus_arena/repositories/auth_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:campus_arena/routing/app_router.dart';
import 'package:campus_arena/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase must finish before the first authenticated read; the disk-cached
  // OSM tile provider (Tile Usage Policy compliance) is best-effort and
  // independent, so build them concurrently rather than serially on startup.
  final (_, tileProvider) = await (
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    buildOsmTileProvider(),
  ).wait;

  final userRepository = UserRepository();
  final authCubit = AuthCubit(
    authRepository: AuthRepository(),
    userRepository: userRepository,
    ratingRepository: RatingRepository(),
  );
  final localeCubit = LocaleCubit(userRepository: userRepository);

  runApp(
    MyApp(
      authCubit: authCubit,
      localeCubit: localeCubit,
      userRepository: userRepository,
      router: createRouter(
        authCubit,
        userRepository: userRepository,
        tileProvider: tileProvider,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.authCubit,
    required this.localeCubit,
    required this.userRepository,
    required this.router,
  });

  final AuthCubit authCubit;
  final LocaleCubit localeCubit;
  final UserRepository userRepository;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        // Arena Assistant: read-only tool layer, settings, and orchestrator,
        // provided once at the app root so any screen can reach them via
        // context.read<T>() without re-constructing their own Firestore/http
        // dependencies. ChatCubit/AssistantSettingsCubit still fall back to
        // constructing their own defaults when used outside this tree (e.g.
        // in widget tests).
        RepositoryProvider<ChatbotToolsService>(
          create: (_) => ChatbotToolsService(),
        ),
        RepositoryProvider<AssistantSettingsRepository>(
          create: (_) => const AssistantSettingsRepository(),
        ),
        // Reuse the single tool-service and settings instances above rather
        // than letting ChatbotRepository construct its own — that is the whole
        // point of providing them at the root.
        RepositoryProvider<ChatbotRepository>(
          create: (context) => ChatbotRepository(
            toolsService: context.read<ChatbotToolsService>(),
            settingsRepository: context.read<AssistantSettingsRepository>(),
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: authCubit),
          BlocProvider.value(value: localeCubit),
        ],
        child: _LocaleSeeder(
          userRepository: userRepository,
          child: BlocBuilder<LocaleCubit, Locale?>(
            builder: (context, locale) {
              return MaterialApp.router(
                title: 'CampusArena',
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: ThemeMode.system,
                locale: locale,
                routerConfig: router,
                // At/above the 600dp shell breakpoint the layout uses a
                // NavigationRail with no bottomNavigationBar, so nothing consumes
                // the bottom home-indicator inset and every page's SafeArea paints
                // the near-black scaffold background as a strip. Drop that inset
                // once, above the router, so shell branches and root-pushed routes
                // alike run edge-to-edge like the map. The phone layout (< 600dp)
                // keeps the inset for its bottom nav bar.
                builder: (context, child) {
                  if (child == null || MediaQuery.sizeOf(context).width < 600) {
                    return child ?? const SizedBox.shrink();
                  }
                  return MediaQuery.removePadding(
                    context: context,
                    removeBottom: true,
                    child: child,
                  );
                },
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One-shot seeds [LocaleCubit] from `users/{uid}.language` the first time each
/// signed-in user resolves, so a persisted language choice survives restarts.
/// Seeds once per uid — a later user-doc change never clobbers an in-session
/// language toggle.
class _LocaleSeeder extends StatefulWidget {
  const _LocaleSeeder({required this.userRepository, required this.child});

  final UserRepository userRepository;
  final Widget child;

  @override
  State<_LocaleSeeder> createState() => _LocaleSeederState();
}

class _LocaleSeederState extends State<_LocaleSeeder> {
  String? _seededUid;

  Future<void> _seed(BuildContext context, String uid) async {
    if (_seededUid == uid) return;
    _seededUid = uid;
    final localeCubit = context.read<LocaleCubit>();
    try {
      final user = await widget.userRepository.getUser(uid);
      if (user != null) localeCubit.seed(user.language);
    } catch (_) {
      // A failed one-shot read just leaves the app on the system locale.
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) =>
          current.status == AuthStatus.authenticated &&
          current.uid != null &&
          previous.uid != current.uid,
      listener: (context, state) => _seed(context, state.uid!),
      child: widget.child,
    );
  }
}
