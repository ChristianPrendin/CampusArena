import 'package:campus_arena/features/auth/cubit/auth_cubit.dart';
import 'package:campus_arena/features/auth/forgot_password_screen.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
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
  testWidgets('empty submit shows the required error and does not send', (
    tester,
  ) async {
    final harness = unauthenticatedAuthCubit();
    addTearDown(harness.cubit.close);

    await tester.pumpWidget(_wrap(harness.cubit, const ForgotPasswordScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Send Reset Link'));
    await tester.pumpAndSettle();

    expect(find.text('This field is required'), findsOneWidget);
    verifyNever(
      () => harness.authRepository.resetPassword(email: any(named: 'email')),
    );
  });

  testWidgets('malformed email shows the invalid-email error', (tester) async {
    final harness = unauthenticatedAuthCubit();
    addTearDown(harness.cubit.close);

    await tester.pumpWidget(_wrap(harness.cubit, const ForgotPasswordScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'notanemail');
    await tester.tap(find.widgetWithText(FilledButton, 'Send Reset Link'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('a valid email calls the repository and shows the sent notice', (
    tester,
  ) async {
    final harness = unauthenticatedAuthCubit();
    addTearDown(harness.cubit.close);
    when(
      () => harness.authRepository.resetPassword(email: any(named: 'email')),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(harness.cubit, const ForgotPasswordScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'mario@polimi.it');
    await tester.tap(find.widgetWithText(FilledButton, 'Send Reset Link'));
    await tester.pumpAndSettle();

    verify(
      () => harness.authRepository.resetPassword(email: 'mario@polimi.it'),
    ).called(1);
    expect(
      find.text('If that email is registered, a reset link has been sent.'),
      findsOneWidget,
    );
  });

  testWidgets('a repository failure surfaces the localized auth error', (
    tester,
  ) async {
    final harness = unauthenticatedAuthCubit();
    addTearDown(harness.cubit.close);
    when(
      () => harness.authRepository.resetPassword(email: any(named: 'email')),
    ).thenThrow(FirebaseAuthException(code: 'invalid-email'));

    await tester.pumpWidget(_wrap(harness.cubit, const ForgotPasswordScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'mario@polimi.it');
    await tester.tap(find.widgetWithText(FilledButton, 'Send Reset Link'));
    await tester.pumpAndSettle();

    // The success notice must NOT appear on an error.
    expect(
      find.text('If that email is registered, a reset link has been sent.'),
      findsNothing,
    );
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
