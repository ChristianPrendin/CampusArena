import 'dart:async';

import 'package:campus_arena/features/auth/cubit/auth_cubit.dart';
import 'package:campus_arena/features/auth/register_screen.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:campus_arena/routing/app_router.dart';
import 'package:campus_arena/routing/route_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/auth_test_helpers.dart';

/// Regression for the review blocker on PR #24: when `createUser` rejects a
/// taken handle, the app must NOT bounce off RegisterScreen (to splash) and
/// swallow the error. This drives the REAL router redirect — the layer the
/// cubit/widget unit tests skip — and asserts the error surfaces on a
/// still-mounted, retry-able form.
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

  testWidgets(
    'a taken handle keeps RegisterScreen mounted and shows the error',
    (tester) async {
      final authStream = StreamController<User?>.broadcast();
      addTearDown(authStream.close);
      final authRepository = MockAuthRepository();
      final userRepository = MockUserRepository();
      final ratingRepository = MockRatingRepository();
      final signedUpUser = MockUser();
      final credential = MockUserCredential();

      when(
        () => authRepository.authStateChanges(),
      ).thenAnswer((_) => authStream.stream);
      when(() => signedUpUser.uid).thenReturn('new-uid');
      // Deleting the orphaned account reports the user as signed out.
      when(
        () => signedUpUser.delete(),
      ).thenAnswer((_) async => authStream.add(null));
      when(() => credential.user).thenReturn(signedUpUser);
      // signUp succeeds and immediately reports the new user (this is what would
      // otherwise unmount RegisterScreen before createUser runs).
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
        () => ratingRepository.seedUserRatings(
          uid: any(named: 'uid'),
          degreeProgram: any(named: 'degreeProgram'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => userRepository.watchUser(any()),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => userRepository.createUser(any()),
      ).thenThrow(const UsernameTakenException('ada'));

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

      // Resolve to unauthenticated, then land on the register form.
      authStream.add(null);
      await tester.pumpAndSettle();
      router.go(RouteConstants.register);
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);

      // Drive the real registration through the same entry point the button
      // calls; the router must hold on RegisterScreen for its duration.
      unawaited(
        cubit.register(
          name: 'Ada',
          username: 'ada',
          email: 'a@b.com',
          password: 'secret1',
          degreeProgram: 'Computer Science',
        ),
      );
      await tester.pumpAndSettle();

      // The taken-handle error is visible AND we're still on a retry-able form.
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('That username is already taken.'), findsOneWidget);
    },
  );

  testWidgets(
    'an authenticated session with no profile doc lands on profile recreation, '
    'and provisioning it moves onward',
    (tester) async {
      final authStream = StreamController<User?>.broadcast();
      addTearDown(authStream.close);
      final docStream = StreamController<UserModel?>.broadcast();
      addTearDown(docStream.close);
      final authRepository = MockAuthRepository();
      final userRepository = MockUserRepository();
      final ratingRepository = MockRatingRepository();
      final user = MockUser();
      when(() => user.uid).thenReturn('u1');
      when(() => user.email).thenReturn('a@b.com');

      when(
        () => authRepository.authStateChanges(),
      ).thenAnswer((_) => authStream.stream);
      when(() => authRepository.currentUser).thenReturn(user);
      when(
        () => userRepository.watchUser('u1'),
      ).thenAnswer((_) => docStream.stream);
      when(
        () => ratingRepository.seedUserRatings(
          uid: any(named: 'uid'),
          degreeProgram: any(named: 'degreeProgram'),
        ),
      ).thenAnswer((_) async {});
      when(() => userRepository.createUser(any())).thenAnswer((_) async {
        // The freshly-created doc now streams in.
        docStream.add(
          UserModel(
            uid: 'u1',
            name: 'Ada',
            username: 'ada',
            email: 'a@b.com',
            degreeProgram: 'Computer Science',
            language: 'en',
            pushTokens: const [],
            friendUids: const [],
            badges: const {},
            onboardingComplete: false,
            createdAt: DateTime(2026),
          ),
        );
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

      // Signed in, but the profile doc is absent: land on RegisterScreen in
      // recovery mode — no email/password field, a "complete your profile" title.
      // Pump between the two emissions so the cubit has subscribed to the
      // (broadcast) doc stream before the null is delivered.
      authStream.add(user);
      await tester.pump();
      docStream.add(null);
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Complete your profile'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Password'), findsNothing);

      // Recreate the profile through the same entry point the button calls; the
      // new doc streams in and the router moves off RegisterScreen.
      unawaited(
        cubit.provisionProfile(
          name: 'Ada',
          username: 'ada',
          degreeProgram: 'Computer Science',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsNothing);
      verify(() => userRepository.createUser(any())).called(1);
      verifyNever(
        () => authRepository.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    },
  );
}
