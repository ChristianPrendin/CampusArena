import 'dart:async';

import 'package:campus_arena/features/auth/cubit/auth_cubit.dart';
import 'package:campus_arena/features/auth/landing_screen.dart';
import 'package:campus_arena/features/auth/register_screen.dart';
import 'package:campus_arena/features/onboarding/mini_tutorial_screen.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/routing/app_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/auth_test_helpers.dart';

/// Reproduces bug #1: after a successful registration the app must go
/// RegisterScreen (filled) -> onboarding, never flashing a SECOND, empty
/// RegisterScreen in between. Mimics production: landing PUSHES register, and
/// watchUser emits null (doc absent) before the created doc arrives.
void main() {
  setUpAll(() {
    registerFallbackValue(
      UserModel(
        uid: 'fallback',
        name: '',
        username: '',
        email: '',
        degreeProgram: '',
        language: 'en',
        pushTokens: const [],
        friendUids: const [],
        badges: const {},
        onboardingComplete: false,
        createdAt: DateTime(2026),
      ),
    );
  });

  testWidgets('registration never flashes an empty RegisterScreen', (
    tester,
  ) async {
    final authStream = StreamController<User?>.broadcast();
    addTearDown(authStream.close);
    final docStream = StreamController<UserModel?>.broadcast();
    addTearDown(docStream.close);

    final authRepository = MockAuthRepository();
    final userRepository = MockUserRepository();
    final ratingRepository = MockRatingRepository();
    final signedUpUser = MockUser();
    final credential = MockUserCredential();

    when(
      () => authRepository.authStateChanges(),
    ).thenAnswer((_) => authStream.stream);
    when(() => signedUpUser.uid).thenReturn('new-uid');
    when(() => credential.user).thenReturn(signedUpUser);
    when(
      () => authRepository.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {
      authStream.add(signedUpUser);
      return credential;
    });
    when(
      () => userRepository.watchUser('new-uid'),
    ).thenAnswer((_) => docStream.stream);
    when(
      () => ratingRepository.seedUserRatings(
        uid: any(named: 'uid'),
        degreeProgram: any(named: 'degreeProgram'),
      ),
    ).thenAnswer((_) async {});
    final createUserCalled = Completer<void>();
    when(() => userRepository.createUser(any())).thenAnswer((_) async {
      createUserCalled.complete();
    });

    final cubit = AuthCubit(
      authRepository: authRepository,
      userRepository: userRepository,
      ratingRepository: ratingRepository,
    );
    addTearDown(cubit.close);

    final router = createRouter(cubit, userRepository: userRepository);
    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: cubit,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );

    // Resolve to unauthenticated -> landing.
    authStream.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(LandingScreen), findsOneWidget);

    // Land on register exactly as the landing button does: context.push.
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);

    // Fill the form.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full Name'),
      'Ada',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'ada',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'a@b.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret1',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Architecture').last);
    await tester.pumpAndSettle();

    void assertNoEmptyRegister(String when) {
      final registers = find.byType(RegisterScreen).evaluate();
      // A duplicate RegisterScreen (the imperative push + the redirect holding
      // on /register) is the flash: the topmost one is freshly built and empty.
      expect(
        registers.length,
        lessThanOrEqualTo(1),
        reason: '$when: a duplicate RegisterScreen was mounted',
      );
      if (registers.isEmpty) return;
      final nameText = tester
          .widget<EditableText>(
            find
                .descendant(
                  of: find.byType(RegisterScreen),
                  matching: find.byType(EditableText),
                )
                .first,
          )
          .controller
          .text;
      expect(
        nameText,
        'Ada',
        reason: '$when: a second, empty RegisterScreen flashed',
      );
    }

    // Submit. signUp fires the auth-state change; the cubit subscribes to the
    // (still doc-less) profile stream.
    await tester.tap(find.text('Create Account'));
    await tester.pump();

    // The real Firestore stream emits null first: the users/{uid} doc does not
    // exist yet in the window between signUp and createUser landing. Let it sit
    // for several frames — this is the gap where the recovery form could flash.
    docStream.add(null);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      assertNoEmptyRegister('gap frame $i');
    }

    // createUser now lands the doc.
    await createUserCalled.future;
    docStream.add(
      UserModel(
        uid: 'new-uid',
        name: 'Ada',
        username: 'ada',
        email: 'a@b.com',
        degreeProgram: 'Architecture',
        language: 'en',
        pushTokens: const [],
        friendUids: const [],
        badges: const {},
        onboardingComplete: false,
        createdAt: DateTime(2026),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      assertNoEmptyRegister('post-doc frame $i');
      if (find.byType(MiniTutorialView).evaluate().isNotEmpty) break;
    }

    await tester.pumpAndSettle();
    expect(find.byType(MiniTutorialView), findsOneWidget);
    expect(find.byType(RegisterScreen), findsNothing);
  });
}
