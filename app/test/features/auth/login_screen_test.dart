import 'package:campus_arena/features/auth/cubit/auth_cubit.dart';
import 'package:campus_arena/features/auth/login_screen.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
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
  testWidgets('empty submit shows required errors and does not sign in', (
    tester,
  ) async {
    final harness = unauthenticatedAuthCubit();
    addTearDown(harness.cubit.close);

    await tester.pumpWidget(_wrap(harness.cubit, const LoginScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('This field is required'), findsNWidgets(2));
    verifyNever(
      () => harness.authRepository.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('malformed email shows the invalid-email error', (tester) async {
    final harness = unauthenticatedAuthCubit();
    addTearDown(harness.cubit.close);

    await tester.pumpWidget(_wrap(harness.cubit, const LoginScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'notanemail');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret1');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
  });
}
