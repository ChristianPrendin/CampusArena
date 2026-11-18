import 'package:campus_arena/core/services/push_token_service.dart';
import 'package:campus_arena/features/auth/cubit/auth_cubit.dart';
import 'package:campus_arena/features/settings/cubit/locale_cubit.dart';
import 'package:campus_arena/features/settings/settings_screen.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/auth_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUserRepository extends Mock implements UserRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockRatingRepository extends Mock implements RatingRepository {}

class MockPushTokenService extends Mock implements PushTokenService {}

class MockUser extends Mock implements User {}

const _uid = 'me';

UserModel _user() => UserModel(
  uid: _uid,
  name: 'Me',
  username: 'me',
  email: 'me@polimi.it',
  degreeProgram: 'Computer Science',
  language: 'en',
  pushTokens: const [],
  friendUids: const [],
  badges: const {},
  onboardingComplete: true,
  createdAt: DateTime(2026),
);

void main() {
  late MockUserRepository userRepository;
  late MockAuthRepository settingsAuthRepository;
  late MockAuthRepository sessionAuthRepository;
  late MockPushTokenService pushTokenService;
  late AuthCubit authCubit;
  late LocaleCubit localeCubit;

  setUp(() {
    userRepository = MockUserRepository();
    settingsAuthRepository = MockAuthRepository();
    sessionAuthRepository = MockAuthRepository();
    pushTokenService = MockPushTokenService();

    when(
      () => userRepository.watchUser(_uid),
    ).thenAnswer((_) => Stream.value(_user()));
    // No FCM token → the toggle row is shown disabled, never touching Firebase.
    when(() => pushTokenService.getToken()).thenAnswer((_) async => null);

    final sessionUser = MockUser();
    when(() => sessionUser.uid).thenReturn(_uid);
    when(
      () => sessionAuthRepository.authStateChanges(),
    ).thenAnswer((_) => Stream<User?>.value(sessionUser));
    when(() => sessionAuthRepository.signOut()).thenAnswer((_) async {});

    authCubit = AuthCubit(
      authRepository: sessionAuthRepository,
      userRepository: userRepository,
      ratingRepository: MockRatingRepository(),
    );
    localeCubit = LocaleCubit(userRepository: userRepository);
    addTearDown(authCubit.close);
    addTearDown(localeCubit.close);
  });

  Widget wrap() {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: authCubit),
        BlocProvider.value(value: localeCubit),
      ],
      child: BlocBuilder<LocaleCubit, Locale?>(
        builder: (context, locale) => MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(
            userRepository: userRepository,
            authRepository: settingsAuthRepository,
            pushTokenService: pushTokenService,
          ),
        ),
      ),
    );
  }

  Future<AppLocalizations> en() =>
      AppLocalizations.delegate.load(const Locale('en'));
  Future<AppLocalizations> it() =>
      AppLocalizations.delegate.load(const Locale('it'));

  testWidgets('renders every settings row and the version footer', (
    tester,
  ) async {
    final l10n = await en();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.settingsAccountSection.toUpperCase()),
      findsOneWidget,
    );
    expect(
      find.text(l10n.settingsPreferencesSection.toUpperCase()),
      findsOneWidget,
    );
    expect(find.text(l10n.settingsChangePassword), findsOneWidget);
    expect(find.text(l10n.settingsPrivacy), findsOneWidget);
    expect(find.text(l10n.settingsNotifications), findsOneWidget);
    expect(find.text(l10n.settingsLanguage), findsOneWidget);
    expect(find.text(l10n.settingsLogout), findsOneWidget);
    expect(find.text(l10n.settingsVersion(kAppVersion)), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.byType(SegmentedButton<String>), findsOneWidget);
  });

  testWidgets('logout button signs out via AuthCubit', (tester) async {
    final l10n = await en();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.settingsLogout));
    await tester.pump();

    verify(() => sessionAuthRepository.signOut()).called(1);
  });

  testWidgets('change password sends a reset email and confirms', (
    tester,
  ) async {
    when(
      () => settingsAuthRepository.resetPassword(email: 'me@polimi.it'),
    ).thenAnswer((_) async {});
    final l10n = await en();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.settingsChangePassword));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    verify(
      () => settingsAuthRepository.resetPassword(email: 'me@polimi.it'),
    ).called(1);
    expect(
      find.text(l10n.settingsPasswordResetSent('me@polimi.it')),
      findsOneWidget,
    );
  });

  testWidgets('language toggle flips the rendered strings to Italian', (
    tester,
  ) async {
    when(
      () => userRepository.updateUser(_uid, {'language': 'it'}),
    ).thenAnswer((_) async {});
    final en_ = await en();
    final it_ = await it();

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Starts in English (system locale).
    expect(find.text(en_.settingsNotifications), findsOneWidget);
    expect(find.text(it_.settingsNotifications), findsNothing);

    await tester.tap(find.text('IT'));
    await tester.pumpAndSettle();

    expect(find.text(it_.settingsNotifications), findsOneWidget);
    verify(() => userRepository.updateUser(_uid, {'language': 'it'})).called(1);
  });
}
