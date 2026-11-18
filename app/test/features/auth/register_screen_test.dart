import 'dart:async';

import 'package:campus_arena/core/degree_programs.dart';
import 'package:campus_arena/features/auth/cubit/auth_cubit.dart';
import 'package:campus_arena/features/auth/register_screen.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/auth_test_helpers.dart';

Widget _wrap(AuthCubit cubit, Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<AuthCubit>.value(value: cubit, child: child),
  );
}

void main() {
  testWidgets('empty submit blocks registration and shows required errors', (
    tester,
  ) async {
    final harness = unauthenticatedAuthCubit();
    addTearDown(harness.cubit.close);

    await tester.pumpWidget(_wrap(harness.cubit, const RegisterScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
    await tester.pumpAndSettle();

    // name, username, email, password, degree program all required.
    expect(find.text('This field is required'), findsNWidgets(5));
    verifyNever(
      () => harness.authRepository.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('an invalid username format blocks submit', (tester) async {
    final harness = unauthenticatedAuthCubit();
    addTearDown(harness.cubit.close);

    await tester.pumpWidget(_wrap(harness.cubit, const RegisterScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'me me',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
    await tester.pumpAndSettle();

    expect(
      find.text('3–20 lowercase letters, numbers or underscores'),
      findsOneWidget,
    );
    verifyNever(
      () => harness.authRepository.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('the username field auto-lowercases typed input', (tester) async {
    final harness = unauthenticatedAuthCubit();
    addTearDown(harness.cubit.close);

    await tester.pumpWidget(_wrap(harness.cubit, const RegisterScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'MixedCase_1',
    );
    await tester.pumpAndSettle();

    expect(find.text('mixedcase_1'), findsOneWidget);
    expect(find.text('MixedCase_1'), findsNothing);
  });

  testWidgets('degree-program dropdown lists the fixed programs', (
    tester,
  ) async {
    final harness = unauthenticatedAuthCubit();
    addTearDown(harness.cubit.close);

    await tester.pumpWidget(_wrap(harness.cubit, const RegisterScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text(kDegreePrograms.first), findsWidgets);
  });

  testWidgets('the submit button keeps its spinner through the post-signup gap '
      '(status flips to authenticated before the user doc write finishes)', (
    tester,
  ) async {
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
    when(() => credential.user).thenReturn(signedUpUser);
    // signUp resolves and immediately reports the new user on the auth
    // stream — flipping AuthState.status to `authenticated` well before
    // rating-seeding (stubbed to hang below) ever completes.
    when(
      () => authRepository.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {
      authStream.add(signedUpUser);
      return credential;
    });
    // Never resolves: keeps registration mid-flight past the auth-state
    // bounce, reproducing the gap the button must stay disabled through.
    when(
      () => ratingRepository.seedUserRatings(
        uid: any(named: 'uid'),
        degreeProgram: any(named: 'degreeProgram'),
      ),
    ).thenAnswer((_) => Completer<void>().future);
    when(
      () => userRepository.watchUser(any()),
    ).thenAnswer((_) => const Stream.empty());

    final cubit = AuthCubit(
      authRepository: authRepository,
      userRepository: userRepository,
      ratingRepository: ratingRepository,
    );
    addTearDown(cubit.close);
    authStream.add(null);

    await tester.pumpWidget(_wrap(cubit, const RegisterScreen()));
    await tester.pumpAndSettle();

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
    await tester.tap(find.text(kDegreePrograms.first).last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
    // One pump for AuthState.loading(), one more for the authStateChanges
    // bounce to authenticated(registrationInProgress: true).
    await tester.pump();
    await tester.pump();

    expect(find.text('Create Account'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'stays on the normal signup form during the transient profileMissing '
    'window mid-registration, instead of flashing profile recovery',
    (tester) async {
      final authStream = StreamController<User?>.broadcast();
      addTearDown(authStream.close);
      final userDocStream = StreamController<UserModel?>.broadcast();
      addTearDown(userDocStream.close);
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
      // Never resolves: keeps registration mid-flight so the transient
      // watchUser(null) emission below is the only thing driving the UI.
      when(
        () => ratingRepository.seedUserRatings(
          uid: any(named: 'uid'),
          degreeProgram: any(named: 'degreeProgram'),
        ),
      ).thenAnswer((_) => Completer<void>().future);
      // The users/{uid} doc hasn't been written yet: watchUser emits null,
      // exactly the transient state that used to leak into recovery mode.
      when(
        () => userRepository.watchUser(any()),
      ).thenAnswer((_) => userDocStream.stream.cast());

      final cubit = AuthCubit(
        authRepository: authRepository,
        userRepository: userRepository,
        ratingRepository: ratingRepository,
      );
      addTearDown(cubit.close);
      authStream.add(null);

      await tester.pumpWidget(_wrap(cubit, const RegisterScreen()));
      await tester.pumpAndSettle();

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
      await tester.tap(find.text(kDegreePrograms.first).last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pump();
      userDocStream.add(null);
      await tester.pump();

      expect(find.text('Complete your profile'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    },
  );
}
